<?php

namespace Tests\Feature;

use App\Models\Appointment;
use App\Models\PatientNotification;
use App\Models\PatientRecord;
use App\Models\Role;
use App\Models\Service;
use App\Models\StaffNotification;
use App\Models\User;
use Carbon\Carbon;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Str;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class NotificationListRetrievalApiTest extends TestCase
{
    use RefreshDatabase;

    public function test_patient_notification_list_is_scoped_ordered_and_normalized(): void
    {
        $patient = $this->createUserWithRole('Patient');
        $otherPatient = $this->createUserWithRole('Patient');
        $service = $this->createService();

        $patientRecord = PatientRecord::resolveForUser($patient);
        $otherPatientRecord = PatientRecord::resolveForUser($otherPatient);

        $olderAppointment = $this->createAppointment($patientRecord->id, $service->id, '2026-04-01', '09:00');
        $newerAppointment = $this->createAppointment($patientRecord->id, $service->id, '2026-04-02', '10:00');
        $otherAppointment = $this->createAppointment($otherPatientRecord->id, $service->id, '2026-04-03', '11:00');

        $olderNotification = $this->createNotification(
            $patientRecord->id,
            $olderAppointment->id,
            'Appointment booked',
            'Older patient notification',
            null,
            '2026-03-28 08:15:00',
        );

        $newerNotification = $this->createNotification(
            $patientRecord->id,
            $newerAppointment->id,
            'Appointment approved',
            'Newest patient notification',
            '2026-03-29 10:30:00',
            '2026-03-29 09:45:00',
        );

        $this->createNotification(
            $otherPatientRecord->id,
            $otherAppointment->id,
            'Foreign notification',
            'This should never leak.',
            null,
            '2026-03-30 08:00:00',
        );

        Sanctum::actingAs($patient);

        $response = $this->getJson('/api/v1/patient/notifications');

        $response->assertOk()
            ->assertJsonCount(2, 'notifications')
            ->assertJsonPath('unread_count', 1)
            ->assertJsonStructure([
                'notifications' => [
                    '*' => [
                        'notification_id',
                        'title',
                        'message',
                        'created_at',
                        'is_read',
                        'related_appointment_id',
                    ],
                ],
            ])
            ->assertJsonPath('notifications.0.notification_id', $newerNotification->id)
            ->assertJsonPath('notifications.0.title', 'Appointment approved')
            ->assertJsonPath('notifications.0.message', 'Newest patient notification')
            ->assertJsonPath('notifications.0.is_read', true)
            ->assertJsonPath('notifications.0.related_appointment_id', $newerAppointment->id)
            ->assertJsonPath('notifications.1.notification_id', $olderNotification->id)
            ->assertJsonPath('notifications.1.title', 'Appointment booked')
            ->assertJsonPath('notifications.1.is_read', false)
            ->assertJsonPath('notifications.1.related_appointment_id', $olderAppointment->id)
            ->assertJsonMissing([
                'title' => 'Foreign notification',
                'message' => 'This should never leak.',
            ]);
    }

    public function test_staff_notification_list_returns_staff_scoped_notifications(): void
    {
        $patient = $this->createUserWithRole('Patient');
        $staff = $this->createUserWithRole('Staff');
        $otherStaff = $this->createUserWithRole('Staff');
        $service = $this->createService();
        $patientRecord = PatientRecord::resolveForUser($patient);
        $appointment = $this->createAppointment($patientRecord->id, $service->id, '2026-04-05', '13:00');

        $this->createStaffNotification(
            (int) $staff->id,
            $appointment->id,
            'New appointment booked',
            'Staff should receive this booking notification.',
            null,
            '2026-03-29 14:00:00',
        );

        $this->createStaffNotification(
            (int) $otherStaff->id,
            $appointment->id,
            'Foreign staff notification',
            'This should never leak.',
            null,
            '2026-03-30 08:00:00',
        );

        Sanctum::actingAs($staff);

        $this->getJson('/api/v1/staff/notifications')
            ->assertOk()
            ->assertJsonCount(1, 'notifications')
            ->assertJsonPath('unread_count', 1)
            ->assertJsonPath('notifications.0.title', 'New appointment booked')
            ->assertJsonPath('notifications.0.message', 'Staff should receive this booking notification.')
            ->assertJsonMissing([
                'title' => 'Foreign staff notification',
                'message' => 'This should never leak.',
            ]);
    }

    public function test_empty_patient_notification_list_returns_safely(): void
    {
        $patient = $this->createUserWithRole('Patient');

        Sanctum::actingAs($patient);

        $this->getJson('/api/v1/patient/notifications')
            ->assertOk()
            ->assertExactJson([
                'notifications' => [],
                'unread_count' => 0,
            ]);
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
        string $message,
        ?string $readAt,
        string $createdAt,
    ): PatientNotification {
        $notification = PatientNotification::create([
            'patient_id' => $patientRecordId,
            'appointment_id' => $appointmentId,
            'type' => 'appointment_update',
            'title' => $title,
            'message' => $message,
            'read_at' => $readAt !== null ? Carbon::parse($readAt) : null,
        ]);

        $notification->forceFill([
            'created_at' => Carbon::parse($createdAt),
            'updated_at' => Carbon::parse($createdAt),
        ])->saveQuietly();

        return $notification->fresh();
    }

    private function createStaffNotification(
        int $userId,
        int $appointmentId,
        string $title,
        string $message,
        ?string $readAt,
        string $createdAt,
    ): StaffNotification {
        $notification = StaffNotification::create([
            'user_id' => $userId,
            'appointment_id' => $appointmentId,
            'type' => 'staff_appointment_created',
            'title' => $title,
            'message' => $message,
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
            'name' => 'Notification Test Service',
            'description' => 'Notification list retrieval test service.',
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
