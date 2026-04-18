<?php

namespace Tests\Feature;

use App\Models\Appointment;
use App\Models\Queue;
use App\Models\Role;
use App\Models\Service;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Str;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class AdminAppointmentListByDateApiTest extends TestCase
{
    use RefreshDatabase;

    public function test_admin_appointments_endpoint_filters_by_date_and_orders_by_time_then_created_at(): void
    {
        $staff = $this->createUserWithRole('Staff');
        $serviceA = $this->createService('Dental Check-up');
        $serviceB = $this->createService('Root Canal');

        $patientA = $this->createUserWithRole('Patient');
        $patientB = $this->createUserWithRole('Patient');
        $patientC = $this->createUserWithRole('Patient');
        $patientD = $this->createUserWithRole('Patient');
        $otherDatePatient = $this->createUserWithRole('Patient');

        $date = '2026-03-17';
        $otherDate = '2026-03-18';

        $earliestAppointment = $this->createAppointment($patientA->id, $serviceA->id, $date, '08:30', 'confirmed');
        $sameTimeEarlierCreated = $this->createAppointment($patientB->id, $serviceB->id, $date, '09:00', 'pending');
        $sameTimeLaterCreated = $this->createAppointment($patientC->id, $serviceA->id, $date, '09:00', 'confirmed');
        $cancelledAppointment = $this->createAppointment($patientD->id, $serviceA->id, $date, '10:00', 'cancelled');
        $otherDateAppointment = $this->createAppointment($otherDatePatient->id, $serviceA->id, $otherDate, '08:00', 'pending');
        $cancelledAppointment->delete();

        $earliestAppointment->forceFill([
            'created_at' => '2026-03-10 07:15:00',
            'updated_at' => '2026-03-10 07:15:00',
        ])->saveQuietly();
        $sameTimeEarlierCreated->forceFill([
            'created_at' => '2026-03-10 07:30:00',
            'updated_at' => '2026-03-10 07:30:00',
        ])->saveQuietly();
        $sameTimeLaterCreated->forceFill([
            'created_at' => '2026-03-10 07:45:00',
            'updated_at' => '2026-03-10 07:45:00',
        ])->saveQuietly();

        // Seed intentionally mismatched queue numbers to verify the endpoint
        // reuses the same daily ordering as queue generation.
        $this->createQueue($sameTimeLaterCreated->id, $date, 1);
        $this->createQueue($earliestAppointment->id, $date, 3);
        $this->createQueue($sameTimeEarlierCreated->id, $date, 2);
        $this->createQueue($cancelledAppointment->id, $date, 4);
        $this->createQueue($otherDateAppointment->id, $otherDate, 9);

        Sanctum::actingAs($staff);

        $response = $this->getJson('/api/v1/admin/appointments?date=' . $date);

        $response->assertOk()
            ->assertJsonPath('date', $date)
            ->assertJsonCount(3, 'appointments')
            ->assertJsonPath('appointments.0.id', $earliestAppointment->id)
            ->assertJsonPath('appointments.0.patient_name', trim($patientA->first_name . ' ' . $patientA->last_name))
            ->assertJsonPath('appointments.0.service_type', $serviceA->name)
            ->assertJsonPath('appointments.0.time', '08:30')
            ->assertJsonPath('appointments.0.status', 'Confirmed')
            ->assertJsonPath('appointments.0.queue_number', 1)
            ->assertJsonPath('appointments.1.id', $sameTimeEarlierCreated->id)
            ->assertJsonPath('appointments.1.time', '09:00')
            ->assertJsonPath('appointments.1.status', 'Pending')
            ->assertJsonPath('appointments.1.queue_number', 2)
            ->assertJsonPath('appointments.2.id', $sameTimeLaterCreated->id)
            ->assertJsonPath('appointments.2.time', '09:00')
            ->assertJsonPath('appointments.2.status', 'Confirmed')
            ->assertJsonPath('appointments.2.queue_number', 3);

        $appointmentIds = array_map(
            fn (array $appointment): int => (int) ($appointment['id'] ?? 0),
            $response->json('appointments', []),
        );

        $this->assertNotContains($cancelledAppointment->id, $appointmentIds);
        $this->assertNotContains($otherDateAppointment->id, $appointmentIds);

        $appointmentDates = array_map(
            fn (array $appointment): string => (string) ($appointment['appointment_date'] ?? ''),
            $response->json('appointments', []),
        );

        $this->assertSame([$date, $date, $date], $appointmentDates);
        $this->assertNotEmpty($response->json('appointments.1.timestamp_created'));

        $this->assertDatabaseHas('queues', [
            'appointment_id' => $earliestAppointment->id,
            'queue_date' => $date,
            'queue_number' => 1,
        ]);
        $this->assertDatabaseHas('queues', [
            'appointment_id' => $sameTimeEarlierCreated->id,
            'queue_date' => $date,
            'queue_number' => 2,
        ]);
        $this->assertDatabaseHas('queues', [
            'appointment_id' => $sameTimeLaterCreated->id,
            'queue_date' => $date,
            'queue_number' => 3,
        ]);
    }

    public function test_admin_appointments_endpoint_requires_date_parameter(): void
    {
        $staff = $this->createUserWithRole('Staff');
        Sanctum::actingAs($staff);

        $response = $this->getJson('/api/v1/admin/appointments');

        $response->assertStatus(422)
            ->assertJsonValidationErrors(['date']);
    }

    public function test_admin_appointments_endpoint_does_not_rebuild_already_aligned_queue_rows(): void
    {
        $staff = $this->createUserWithRole('Staff');
        $service = $this->createService('Aligned Queue Check');
        $patientA = $this->createUserWithRole('Patient');
        $patientB = $this->createUserWithRole('Patient');
        $date = '2026-03-19';

        $earlierAppointment = $this->createAppointment($patientA->id, $service->id, $date, '08:30', 'confirmed');
        $laterAppointment = $this->createAppointment($patientB->id, $service->id, $date, '09:00', 'pending');

        $earlierQueue = $this->createQueue($earlierAppointment->id, $date, 1);
        $laterQueue = $this->createQueue($laterAppointment->id, $date, 2);

        Sanctum::actingAs($staff);

        $this->getJson('/api/v1/admin/appointments?date=' . $date)
            ->assertOk()
            ->assertJsonPath('appointments.0.queue_number', 1)
            ->assertJsonPath('appointments.1.queue_number', 2);

        $this->assertDatabaseHas('queues', [
            'id' => $earlierQueue->id,
            'appointment_id' => $earlierAppointment->id,
            'queue_date' => $date,
            'queue_number' => 1,
        ]);
        $this->assertDatabaseHas('queues', [
            'id' => $laterQueue->id,
            'appointment_id' => $laterAppointment->id,
            'queue_date' => $date,
            'queue_number' => 2,
        ]);
        $this->assertDatabaseCount('queues', 2);
    }

    private function createQueue(int $appointmentId, string $date, int $queueNumber): Queue
    {
        return Queue::create([
            'appointment_id' => $appointmentId,
            'queue_date' => $date,
            'queue_number' => $queueNumber,
            'is_called' => false,
        ]);
    }

    private function createAppointment(
        int $patientId,
        int $serviceId,
        string $date,
        string $timeSlot,
        string $status,
    ): Appointment {
        return Appointment::create([
            'patient_id' => $patientId,
            'service_id' => $serviceId,
            'appointment_date' => $date,
            'time_slot' => $timeSlot,
            'status' => $status,
        ]);
    }

    private function createService(string $name): Service
    {
        return Service::create([
            'name' => $name,
            'description' => 'Staff appointment list API test service.',
            'is_active' => true,
        ]);
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
}
