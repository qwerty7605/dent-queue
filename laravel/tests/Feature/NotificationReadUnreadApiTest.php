<?php

namespace Tests\Feature;

use App\Models\Appointment;
use App\Models\PatientNotification;
use App\Models\PatientRecord;
use App\Models\Role;
use App\Models\Service;
use App\Models\User;
use Carbon\Carbon;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Str;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class NotificationReadUnreadApiTest extends TestCase
{
    use RefreshDatabase;

    public function test_new_notifications_are_unread_by_default(): void
    {
        $patient = $this->createUserWithRole('Patient');
        $service = $this->createService();
        $patientRecord = PatientRecord::resolveForUser($patient);
        $appointment = $this->createAppointment($patientRecord->id, $service->id, '2026-04-08', '09:00');

        $notification = PatientNotification::create([
            'patient_id' => $patientRecord->id,
            'appointment_id' => $appointment->id,
            'type' => 'appointment_created',
            'title' => 'Appointment booked',
            'message' => 'Your appointment has been booked.',
        ]);

        $this->assertDatabaseHas('patient_notifications', [
            'id' => $notification->id,
            'read_at' => null,
        ]);

        Sanctum::actingAs($patient);

        $this->getJson('/api/v1/patient/notifications')
            ->assertOk()
            ->assertJsonPath('unread_count', 1)
            ->assertJsonPath('notifications.0.notification_id', $notification->id)
            ->assertJsonPath('notifications.0.is_read', false)
            ->assertJsonPath('notifications.0.read_at', null);
    }

    public function test_patient_can_mark_own_notification_as_read_and_state_persists(): void
    {
        $patient = $this->createUserWithRole('Patient');
        $service = $this->createService();
        $patientRecord = PatientRecord::resolveForUser($patient);
        $appointment = $this->createAppointment($patientRecord->id, $service->id, '2026-04-09', '10:00');

        $notification = PatientNotification::create([
            'patient_id' => $patientRecord->id,
            'appointment_id' => $appointment->id,
            'type' => 'appointment_created',
            'title' => 'Appointment booked',
            'message' => 'Please review your appointment details.',
        ]);

        Sanctum::actingAs($patient);

        $this->patchJson('/api/v1/patient/notifications/' . $notification->id . '/read')
            ->assertOk()
            ->assertJsonPath('message', 'Notification marked as read.')
            ->assertJsonPath('notification.notification_id', $notification->id)
            ->assertJsonPath('notification.is_read', true)
            ->assertJsonPath('unread_count', 0);

        $notification->refresh();
        $this->assertNotNull($notification->read_at);

        Sanctum::actingAs($patient->fresh());

        $this->getJson('/api/v1/patient/notifications')
            ->assertOk()
            ->assertJsonPath('unread_count', 0)
            ->assertJsonPath('notifications.0.notification_id', $notification->id)
            ->assertJsonPath('notifications.0.is_read', true);
    }

    public function test_patient_can_mark_all_notifications_as_read(): void
    {
        $patient = $this->createUserWithRole('Patient');
        $service = $this->createService();
        $patientRecord = PatientRecord::resolveForUser($patient);

        $firstAppointment = $this->createAppointment($patientRecord->id, $service->id, '2026-04-10', '09:00');
        $secondAppointment = $this->createAppointment($patientRecord->id, $service->id, '2026-04-11', '10:00');
        $thirdAppointment = $this->createAppointment($patientRecord->id, $service->id, '2026-04-12', '11:00');

        $firstNotification = $this->createNotification(
            $patientRecord->id,
            $firstAppointment->id,
            'Unread one',
            null,
            '2026-03-28 08:00:00',
        );
        $secondNotification = $this->createNotification(
            $patientRecord->id,
            $secondAppointment->id,
            'Unread two',
            null,
            '2026-03-29 08:00:00',
        );
        $thirdNotification = $this->createNotification(
            $patientRecord->id,
            $thirdAppointment->id,
            'Already read',
            '2026-03-29 12:00:00',
            '2026-03-27 08:00:00',
        );

        Sanctum::actingAs($patient);

        $response = $this->patchJson('/api/v1/patient/notifications/read-all');

        $response->assertOk()
            ->assertJsonPath('message', 'Notifications marked as read.')
            ->assertJsonPath('updated_count', 2)
            ->assertJsonPath('unread_count', 0);

        $firstNotification->refresh();
        $secondNotification->refresh();
        $thirdNotification->refresh();

        $this->assertNotNull($firstNotification->read_at);
        $this->assertNotNull($secondNotification->read_at);
        $this->assertNotNull($thirdNotification->read_at);

        $listResponse = $this->getJson('/api/v1/patient/notifications');
        $listResponse->assertOk()
            ->assertJsonPath('unread_count', 0);

        $notifications = collect($listResponse->json('notifications'));
        $this->assertTrue(
            $notifications->every(fn (mixed $item) => is_array($item) && ($item['is_read'] ?? false) === true)
        );
    }

    public function test_patient_cannot_mark_another_patients_notification_as_read(): void
    {
        $patient = $this->createUserWithRole('Patient');
        $otherPatient = $this->createUserWithRole('Patient');
        $service = $this->createService();
        $otherPatientRecord = PatientRecord::resolveForUser($otherPatient);
        $appointment = $this->createAppointment($otherPatientRecord->id, $service->id, '2026-04-13', '09:00');

        $notification = PatientNotification::create([
            'patient_id' => $otherPatientRecord->id,
            'appointment_id' => $appointment->id,
            'type' => 'appointment_created',
            'title' => 'Private notification',
            'message' => 'This should stay private.',
        ]);

        Sanctum::actingAs($patient);

        $this->patchJson('/api/v1/patient/notifications/' . $notification->id . '/read')
            ->assertStatus(403)
            ->assertJsonPath('message', 'Unauthorized. You can only update your own notifications.');

        $notification->refresh();
        $this->assertNull($notification->read_at);
    }

    public function test_staff_mark_all_as_read_returns_safe_empty_result(): void
    {
        $staff = $this->createUserWithRole('Staff');

        Sanctum::actingAs($staff);

        $this->patchJson('/api/v1/staff/notifications/read-all')
            ->assertOk()
            ->assertJsonPath('message', 'Notifications marked as read.')
            ->assertJsonPath('updated_count', 0)
            ->assertJsonPath('unread_count', 0);
    }

    private function createAppointment(int $patientId, int $serviceId, string $date, string $timeSlot): Appointment
    {
        return Appointment::create([
            'patient_id' => $patientId,
            'service_id' => $serviceId,
            'appointment_date' => $date,
            'time_slot' => $timeSlot,
            'status' => 'pending',
        ]);
    }

    private function createNotification(
        int $patientRecordId,
        int $appointmentId,
        string $title,
        ?string $readAt,
        string $createdAt,
    ): PatientNotification {
        $notification = PatientNotification::create([
            'patient_id' => $patientRecordId,
            'appointment_id' => $appointmentId,
            'type' => 'appointment_update',
            'title' => $title,
            'message' => $title,
            'read_at' => $readAt !== null ? Carbon::parse($readAt) : null,
        ]);

        $notification->forceFill([
            'created_at' => Carbon::parse($createdAt),
            'updated_at' => Carbon::parse($createdAt),
        ])->saveQuietly();

        return $notification->fresh();
    }

    private function createService(): Service
    {
        return Service::create([
            'name' => 'Notification Read Test Service',
            'description' => 'Notification read state service.',
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
