<?php

namespace Tests\Feature;

use App\Models\Queue;
use App\Models\Role;
use App\Models\Service;
use App\Models\PatientRecord;
use App\Models\User;
use App\Services\AppointmentService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Str;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class QueueAssignmentTest extends TestCase
{
    use RefreshDatabase;

    public function test_queue_numbers_are_assigned_sequentially_for_the_same_date(): void
    {
        $staff = $this->createUserWithRole('Staff');
        $service = $this->createService();
        $appointmentDate = now()->next('Monday')->format('Y-m-d');
        Sanctum::actingAs($staff);

        for ($expectedQueueNumber = 1; $expectedQueueNumber <= 3; $expectedQueueNumber++) {
            $patient = $this->createUserWithRole('Patient');

            $response = $this->postJson('/api/v1/admin/appointments', [
                'patient_id' => $patient->id,
                'service_type' => $service->name,
                'appointment_date' => $appointmentDate,
                'appointment_time' => $this->resolveTimeSlotByIndex($expectedQueueNumber),
            ]);

            $response->assertCreated()
                ->assertJsonPath('appointment.queue_number', str_pad((string) $expectedQueueNumber, 2, '0', STR_PAD_LEFT));
        }

        $this->assertSame(
            [1, 2, 3],
            Queue::query()
                ->where('queue_date', $appointmentDate)
                ->orderBy('queue_number')
                ->pluck('queue_number')
                ->all()
        );
    }

    public function test_queue_number_resets_for_a_new_day(): void
    {
        $staff = $this->createUserWithRole('Staff');
        $service = $this->createService();
        $monday = now()->next('Monday')->format('Y-m-d');
        $tuesday = now()->next('Tuesday')->format('Y-m-d');
        Sanctum::actingAs($staff);

        $firstMondayPatient = $this->createUserWithRole('Patient');
        $secondMondayPatient = $this->createUserWithRole('Patient');
        $tuesdayPatient = $this->createUserWithRole('Patient');

        $this->postJson('/api/v1/admin/appointments', [
            'patient_id' => $firstMondayPatient->id,
            'service_type' => $service->name,
            'appointment_date' => $monday,
            'appointment_time' => '09:00',
        ])->assertCreated()->assertJsonPath('appointment.queue_number', '01');

        $this->postJson('/api/v1/admin/appointments', [
            'patient_id' => $secondMondayPatient->id,
            'service_type' => $service->name,
            'appointment_date' => $monday,
            'appointment_time' => '10:00',
        ])->assertCreated()->assertJsonPath('appointment.queue_number', '02');

        $this->postJson('/api/v1/admin/appointments', [
            'patient_id' => $tuesdayPatient->id,
            'service_type' => $service->name,
            'appointment_date' => $tuesday,
            'appointment_time' => '09:00',
        ])->assertCreated()->assertJsonPath('appointment.queue_number', '01');
    }

    public function test_staff_bookings_share_the_same_daily_queue_sequence_as_other_booking_flows(): void
    {
        $staff = $this->createUserWithRole('Staff');
        $service = $this->createService();
        $appointmentDate = now()->next('Thursday')->format('Y-m-d');

        $onlinePatient = $this->createUserWithRole('Patient');
        Sanctum::actingAs($onlinePatient);

        $this->postJson('/api/v1/patient/appointments', [
            'service_id' => $service->id,
            'appointment_date' => $appointmentDate,
            'time_slot' => '09:00',
        ])->assertCreated()->assertJsonPath('appointment.queue_number', '01');

        Sanctum::actingAs($staff);

        $this->postJson('/api/v1/admin/appointments/walk-in', [
            'first_name' => 'Queue',
            'surname' => 'Walker',
            'address' => '123 Queue Street',
            'gender' => 'Male',
            'contact_number' => '09170000001',
            'service_type' => $service->name,
            'appointment_date' => $appointmentDate,
            'appointment_time' => '10:00',
        ])->assertCreated()->assertJsonPath('appointment.queue_number', '02');

        $staffBookedPatient = $this->createUserWithRole('Patient');
        $staffBookedPatientRecord = PatientRecord::syncFromUser($staffBookedPatient);

        $this->postJson('/api/v1/admin/appointments', [
            'patient_id' => $staffBookedPatientRecord->id,
            'service_type' => $service->name,
            'appointment_date' => $appointmentDate,
            'appointment_time' => '11:00',
        ])->assertCreated()->assertJsonPath('appointment.queue_number', '03');

        $this->assertSame(
            [1, 2, 3],
            Queue::query()
                ->where('queue_date', $appointmentDate)
                ->orderBy('queue_number')
                ->pluck('queue_number')
                ->all()
        );
    }

    public function test_queue_numbers_are_resequenced_by_appointment_time_for_the_same_date(): void
    {
        $staff = $this->createUserWithRole('Staff');
        $service = $this->createService();
        $appointmentDate = now()->next('Friday')->format('Y-m-d');
        Sanctum::actingAs($staff);

        $laterTimePatient = PatientRecord::syncFromUser($this->createUserWithRole('Patient'));
        $earlierTimePatient = PatientRecord::syncFromUser($this->createUserWithRole('Patient'));

        $laterResponse = $this->postJson('/api/v1/admin/appointments', [
            'patient_id' => $laterTimePatient->id,
            'service_type' => $service->name,
            'appointment_date' => $appointmentDate,
            'appointment_time' => '08:05',
        ]);

        $laterResponse->assertCreated()
            ->assertJsonPath('appointment.queue_number', '01');

        $earlierResponse = $this->postJson('/api/v1/admin/appointments', [
            'patient_id' => $earlierTimePatient->id,
            'service_type' => $service->name,
            'appointment_date' => $appointmentDate,
            'appointment_time' => '08:00',
        ]);

        $earlierResponse->assertCreated()
            ->assertJsonPath('appointment.queue_number', '01');

        $this->assertDatabaseHas('queues', [
            'appointment_id' => (int) $laterResponse->json('appointment.id'),
            'queue_date' => $appointmentDate,
            'queue_number' => 2,
        ]);

        $this->assertDatabaseHas('queues', [
            'appointment_id' => (int) $earlierResponse->json('appointment.id'),
            'queue_date' => $appointmentDate,
            'queue_number' => 1,
        ]);
    }

    public function test_same_time_bookings_are_rejected_for_the_same_date(): void
    {
        $staff = $this->createUserWithRole('Staff');
        $service = $this->createService();
        $appointmentDate = now()->next('Saturday')->format('Y-m-d');
        Sanctum::actingAs($staff);

        $firstPatient = PatientRecord::syncFromUser($this->createUserWithRole('Patient'));
        $secondPatient = PatientRecord::syncFromUser($this->createUserWithRole('Patient'));

        $firstResponse = $this->postJson('/api/v1/admin/appointments', [
            'patient_id' => $firstPatient->id,
            'service_type' => $service->name,
            'appointment_date' => $appointmentDate,
            'appointment_time' => '09:00',
        ]);

        $secondResponse = $this->postJson('/api/v1/admin/appointments', [
            'patient_id' => $secondPatient->id,
            'service_type' => $service->name,
            'appointment_date' => $appointmentDate,
            'appointment_time' => '09:00',
        ]);

        $firstResponse->assertCreated()
            ->assertJsonPath('appointment.queue_number', '01');
        $secondResponse->assertStatus(422)
            ->assertJsonValidationErrors(['time_slot'])
            ->assertJsonPath('errors.time_slot.0', 'This time slot is already booked. Please choose another time.');

        $this->assertDatabaseHas('queues', [
            'appointment_id' => (int) $firstResponse->json('appointment.id'),
            'queue_date' => $appointmentDate,
            'queue_number' => 1,
        ]);

        $this->assertDatabaseCount('queues', 1);
    }

    public function test_cancelling_and_restoring_resequences_daily_queue_numbers(): void
    {
        $staff = $this->createUserWithRole('Staff');
        $service = $this->createService();
        $appointmentDate = now()->next('Monday')->format('Y-m-d');
        Sanctum::actingAs($staff);

        $firstPatient = PatientRecord::syncFromUser($this->createUserWithRole('Patient'));
        $secondPatient = PatientRecord::syncFromUser($this->createUserWithRole('Patient'));
        $thirdPatient = PatientRecord::syncFromUser($this->createUserWithRole('Patient'));

        $firstId = (int) $this->postJson('/api/v1/admin/appointments', [
            'patient_id' => $firstPatient->id,
            'service_type' => $service->name,
            'appointment_date' => $appointmentDate,
            'appointment_time' => '09:00',
        ])->assertCreated()->json('appointment.id');

        $secondId = (int) $this->postJson('/api/v1/admin/appointments', [
            'patient_id' => $secondPatient->id,
            'service_type' => $service->name,
            'appointment_date' => $appointmentDate,
            'appointment_time' => '10:00',
        ])->assertCreated()->json('appointment.id');

        $thirdId = (int) $this->postJson('/api/v1/admin/appointments', [
            'patient_id' => $thirdPatient->id,
            'service_type' => $service->name,
            'appointment_date' => $appointmentDate,
            'appointment_time' => '11:00',
        ])->assertCreated()->json('appointment.id');

        $appointmentService = app(AppointmentService::class);
        $appointmentService->updateStatus(
            \App\Models\Appointment::query()->findOrFail($secondId),
            'cancelled',
            (int) $staff->id,
        );

        $this->assertDatabaseMissing('queues', [
            'appointment_id' => $secondId,
        ]);
        $this->assertDatabaseHas('queues', [
            'appointment_id' => $firstId,
            'queue_number' => 1,
        ]);
        $this->assertDatabaseHas('queues', [
            'appointment_id' => $thirdId,
            'queue_number' => 2,
        ]);

        $appointmentService->restoreAppointment(
            \App\Models\Appointment::withTrashed()->findOrFail($secondId),
        );

        $this->assertDatabaseHas('queues', [
            'appointment_id' => $firstId,
            'queue_number' => 1,
        ]);
        $this->assertDatabaseHas('queues', [
            'appointment_id' => $secondId,
            'queue_number' => 2,
        ]);
        $this->assertDatabaseHas('queues', [
            'appointment_id' => $thirdId,
            'queue_number' => 3,
        ]);
    }

    public function test_booking_is_rejected_once_daily_queue_reaches_fifty(): void
    {
        $staff = $this->createUserWithRole('Staff');
        $service = $this->createService();
        $appointmentDate = now()->next('Wednesday')->format('Y-m-d');
        Sanctum::actingAs($staff);

        for ($expectedQueueNumber = 1; $expectedQueueNumber <= 50; $expectedQueueNumber++) {
            $patient = $this->createUserWithRole('Patient');

            $this->postJson('/api/v1/admin/appointments', [
                'patient_id' => $patient->id,
                'service_type' => $service->name,
                'appointment_date' => $appointmentDate,
                'appointment_time' => $this->resolveTimeSlotByIndex($expectedQueueNumber),
            ])->assertCreated()->assertJsonPath('appointment.queue_number', str_pad((string) $expectedQueueNumber, 2, '0', STR_PAD_LEFT));
        }

        $extraPatient = $this->createUserWithRole('Patient');
        $response = $this->postJson('/api/v1/admin/appointments', [
            'patient_id' => $extraPatient->id,
            'service_type' => $service->name,
            'appointment_date' => $appointmentDate,
            'appointment_time' => '16:00',
        ]);

        $response->assertStatus(422)
            ->assertJsonValidationErrors(['appointment_date'])
            ->assertJsonPath('errors.appointment_date.0', 'The daily limit of 50 patients has been reached for this date.');

        $this->assertSame(
            range(1, 50),
            Queue::query()
                ->where('queue_date', $appointmentDate)
                ->orderBy('queue_number')
                ->pluck('queue_number')
                ->all()
        );
    }

    private function createUserWithRole(string $roleName): User
    {
        $role = Role::firstOrCreate(['name' => $roleName]);
        $suffix = Str::lower($roleName) . '_' . Str::lower(Str::random(8));

        return User::create([
            'first_name' => $roleName,
            'middle_name' => null,
            'last_name' => 'User',
            'username' => $suffix,
            'email' => $suffix . '@example.com',
            'password' => Hash::make('password123'),
            'phone_number' => '09123456789',
            'location' => 'Test City',
            'gender' => 'other',
            'role_id' => $role->id,
            'is_active' => true,
        ]);
    }

    private function createService(): Service
    {
        return Service::create([
            'name' => 'Queue Assignment Service',
            'description' => 'Queue assignment test service.',
            'is_active' => true,
        ]);
    }

    private function resolveTimeSlotByIndex(int $index): string
    {
        return Carbon::createFromTime(7, 30)
            ->addMinutes(($index - 1) * 10)
            ->format('H:i');
    }
}
