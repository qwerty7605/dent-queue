<?php

namespace Tests\Feature;

use App\Models\Appointment;
use App\Models\ClinicSetting;
use App\Models\DoctorUnavailability;
use App\Models\PatientNotification;
use App\Models\PatientRecord;
use App\Models\Role;
use App\Models\Service;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Str;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class DoctorAvailabilityApiTest extends TestCase
{
    use RefreshDatabase;

    public function test_admin_can_manage_doctor_unavailability_ranges(): void
    {
        $admin = $this->createUserWithRole('Admin');
        Sanctum::actingAs($admin);

        $create = $this->postJson('/api/v1/admin/settings/doctor-unavailability', [
            'unavailable_date' => '2026-05-12',
            'start_time' => '12:00',
            'end_time' => '17:00',
            'reason' => 'Afternoon only unavailable',
        ]);

        $create->assertCreated();

        $schedule = DoctorUnavailability::query()->firstOrFail();

        $this->getJson('/api/v1/admin/settings/doctor-unavailability')
            ->assertOk()
            ->assertJsonPath('data.0.unavailable_date', '2026-05-12')
            ->assertJsonPath('data.0.start_time', '12:00')
            ->assertJsonPath('data.0.end_time', '17:00')
            ->assertJsonPath('data.0.reason', 'Afternoon only unavailable');

        $this->deleteJson('/api/v1/admin/settings/doctor-unavailability/' . $schedule->id)
            ->assertOk()
            ->assertJsonPath('message', 'Doctor unavailability removed successfully.');

        $this->assertDatabaseCount('doctor_unavailabilities', 0);
    }

    public function test_slot_availability_api_marks_doctor_unavailable_and_available_ranges(): void
    {
        $patient = $this->createUserWithRole('Patient');
        $targetDate = now()->addDays(30);
        $date = $targetDate->format('Y-m-d');
        Sanctum::actingAs($patient);

        ClinicSetting::query()->create([
            'opening_time' => '08:00',
            'closing_time' => '17:00',
            'working_days' => [$targetDate->format('l')],
            'daily_operating_hours' => [
                $targetDate->format('l') => ['opening_time' => '08:00', 'closing_time' => '17:00'],
            ],
        ]);

        DoctorUnavailability::create([
            'unavailable_date' => $date,
            'start_time' => '07:30',
            'end_time' => '12:00',
            'reason' => 'Morning only availability starts after lunch',
        ]);

        $response = $this->getJson('/api/v1/availability/slots?date=' . $date);

        $response->assertOk()
            ->assertJsonPath('data.date', $date)
            ->assertJsonPath('data.unavailable_ranges.0.reason', 'Morning only availability starts after lunch');

        $slots = $response->json('data.slots', []);

        $this->assertIsArray($slots);
        $this->assertSame(30, $response->json('data.slot_duration_minutes'));
    }

    public function test_slot_availability_api_can_ignore_current_appointment(): void
    {
        $patient = $this->createUserWithRole('Patient');
        $targetDate = now()->addDays(30);
        $date = $targetDate->format('Y-m-d');
        ClinicSetting::query()->create([
            'opening_time' => '07:30',
            'closing_time' => '18:00',
            'working_days' => [$targetDate->format('l')],
            'daily_operating_hours' => [
                $targetDate->format('l') => ['opening_time' => '07:30', 'closing_time' => '18:00'],
            ],
        ]);
        $appointment = $this->createAppointment(
            PatientRecord::resolveForUser($patient)->id,
            $this->createService()->id,
            $date,
            '07:30',
        );
        Sanctum::actingAs($patient);

        $this->getJson(sprintf(
            '/api/v1/availability/slots?date=%s&ignore_appointment_id=%d',
            $date,
            $appointment->id,
        ))->assertOk()
            ->assertJsonPath('data.date', $date)
            ->assertJsonStructure([
                'data' => [
                    'slots',
                    'unavailable_ranges',
                ],
            ]);
    }

    public function test_creating_doctor_unavailability_notifies_only_affected_patients(): void
    {
        $admin = $this->createUserWithRole('Admin');
        $service = $this->createService();
        $affectedPatientOne = $this->createUserWithRole('Patient');
        $affectedPatientTwo = $this->createUserWithRole('Patient');
        $unaffectedPatient = $this->createUserWithRole('Patient');
        $otherDatePatient = $this->createUserWithRole('Patient');
        $targetDate = now()->addDays(21);
        $date = $targetDate->format('Y-m-d');

        ClinicSetting::query()->create([
            'opening_time' => '08:00',
            'closing_time' => '17:00',
            'working_days' => [$targetDate->format('l')],
            'daily_operating_hours' => [
                $targetDate->format('l') => ['opening_time' => '08:00', 'closing_time' => '17:00'],
            ],
        ]);

        $affectedAppointmentOne = $this->createAppointment(
            PatientRecord::resolveForUser($affectedPatientOne)->id,
            $service->id,
            $date,
            '10:00',
        );
        $affectedAppointmentTwo = $this->createAppointment(
            PatientRecord::resolveForUser($affectedPatientTwo)->id,
            $service->id,
            $date,
            '10:15',
            'confirmed',
        );
        $unaffectedAppointment = $this->createAppointment(
            PatientRecord::resolveForUser($unaffectedPatient)->id,
            $service->id,
            $date,
            '14:00',
        );
        $otherDateAppointment = $this->createAppointment(
            PatientRecord::resolveForUser($otherDatePatient)->id,
            $service->id,
            now()->addDays(22)->format('Y-m-d'),
            '10:00',
        );

        Sanctum::actingAs($admin);

        $this->postJson('/api/v1/admin/settings/doctor-unavailability', [
            'unavailable_date' => $date,
            'start_time' => '10:00',
            'end_time' => '12:00',
            'reason' => 'Emergency leave',
        ])->assertCreated();

        $this->assertDatabaseCount('patient_notifications', 2);
        $this->assertDatabaseHas('patient_notifications', [
            'patient_id' => (int) $affectedAppointmentOne->patient_id,
            'appointment_id' => (int) $affectedAppointmentOne->id,
            'type' => 'appointment_reschedule_required',
            'title' => 'Appointment Needs Reschedule',
        ]);
        $this->assertDatabaseHas('patient_notifications', [
            'patient_id' => (int) $affectedAppointmentTwo->patient_id,
            'appointment_id' => (int) $affectedAppointmentTwo->id,
            'type' => 'appointment_cancelled_by_doctor',
            'title' => 'Appointment Cancelled by Doctor',
        ]);
        $this->assertDatabaseMissing('patient_notifications', [
            'appointment_id' => (int) $unaffectedAppointment->id,
        ]);
        $this->assertDatabaseMissing('patient_notifications', [
            'appointment_id' => (int) $otherDateAppointment->id,
        ]);
        $this->assertDatabaseHas('appointments', [
            'id' => (int) $affectedAppointmentOne->id,
            'status' => 'reschedule_required',
        ]);
        $this->assertDatabaseHas('appointments', [
            'id' => (int) $affectedAppointmentTwo->id,
            'status' => 'cancelled_by_doctor',
        ]);
        $this->assertDatabaseHas('appointments', [
            'id' => (int) $unaffectedAppointment->id,
            'status' => 'pending',
        ]);

        $notification = PatientNotification::query()
            ->where('appointment_id', (int) $affectedAppointmentOne->id)
            ->firstOrFail();

        $this->assertStringContainsString('doctor is unavailable', (string) $notification->message);
        $this->assertStringContainsString('needs attention', (string) $notification->message);
        $this->assertStringContainsString('Emergency leave', (string) $notification->message);
        $this->assertStringContainsString($date, (string) $notification->message);
        $this->assertStringContainsString('10:00', (string) $notification->message);
        $this->assertStringContainsString('Please choose a new appointment time.', (string) $notification->message);

        $cancelledNotification = PatientNotification::query()
            ->where('appointment_id', (int) $affectedAppointmentTwo->id)
            ->firstOrFail();

        $this->assertStringContainsString('doctor is unavailable', (string) $cancelledNotification->message);
        $this->assertStringContainsString('follow-up on the cancellation', (string) $cancelledNotification->message);
        $this->assertStringNotContainsString('Please choose a new appointment time.', (string) $cancelledNotification->message);

        Sanctum::actingAs($affectedPatientOne);

        $this->getJson('/api/v1/patient/notifications')
            ->assertOk()
            ->assertJsonPath('notifications.0.type', 'appointment_reschedule_required')
            ->assertJsonPath('notifications.0.related_appointment_id', (int) $affectedAppointmentOne->id)
            ->assertJsonPath('notifications.0.title', 'Appointment Needs Reschedule');
    }

    private function createAppointment(
        int $patientId,
        int $serviceId,
        string $date,
        string $timeSlot,
        string $status = 'pending',
    ): Appointment {
        return Appointment::create([
            'patient_id' => $patientId,
            'service_id' => $serviceId,
            'appointment_date' => $date,
            'time_slot' => $timeSlot,
            'status' => $status,
        ]);
    }

    private function createService(): Service
    {
        return Service::create([
            'name' => 'Dental Check-up',
            'description' => 'Doctor availability notification test service.',
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
