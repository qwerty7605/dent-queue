<?php

namespace Tests\Feature;

use App\Models\Appointment;
use App\Models\PatientNotification;
use App\Models\PatientRecord;
use App\Models\Role;
use App\Models\Service;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Str;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class NotificationCacheConsistencyTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();

        Cache::flush();
        config()->set('cache.centralized_ttl_seconds.notifications', 60);
    }

    public function test_mark_as_read_refreshes_cached_notification_list_and_unread_count(): void
    {
        $patient = $this->createUserWithRole('Patient');
        $patientRecord = PatientRecord::resolveForUser($patient);
        $service = $this->createService('Notification mark-as-read cache');
        $appointment = $this->createAppointment((int) $patientRecord->id, (int) $service->id, '2026-04-18', '09:00');

        $notification = PatientNotification::create([
            'patient_id' => (int) $patientRecord->id,
            'appointment_id' => (int) $appointment->id,
            'type' => 'appointment_created',
            'title' => 'Unread notification',
            'message' => 'This notification starts unread.',
        ]);

        Sanctum::actingAs($patient);

        $this->getJson('/api/v1/patient/notifications')
            ->assertOk()
            ->assertJsonPath('unread_count', 1)
            ->assertJsonPath('notifications.0.notification_id', (int) $notification->id)
            ->assertJsonPath('notifications.0.is_read', false);

        $this->patchJson('/api/v1/patient/notifications/'.$notification->id.'/read')
            ->assertOk()
            ->assertJsonPath('unread_count', 0)
            ->assertJsonPath('notification.is_read', true);

        $this->getJson('/api/v1/patient/notifications')
            ->assertOk()
            ->assertJsonPath('unread_count', 0)
            ->assertJsonPath('notifications.0.notification_id', (int) $notification->id)
            ->assertJsonPath('notifications.0.is_read', true);
    }

    public function test_mark_all_as_read_refreshes_cached_notification_list_and_unread_count(): void
    {
        $patient = $this->createUserWithRole('Patient');
        $patientRecord = PatientRecord::resolveForUser($patient);
        $service = $this->createService('Notification mark-all cache');
        $firstAppointment = $this->createAppointment((int) $patientRecord->id, (int) $service->id, '2026-04-19', '09:00');
        $secondAppointment = $this->createAppointment((int) $patientRecord->id, (int) $service->id, '2026-04-20', '10:00');

        PatientNotification::create([
            'patient_id' => (int) $patientRecord->id,
            'appointment_id' => (int) $firstAppointment->id,
            'type' => 'appointment_created',
            'title' => 'Unread one',
            'message' => 'Unread notification one.',
        ]);

        PatientNotification::create([
            'patient_id' => (int) $patientRecord->id,
            'appointment_id' => (int) $secondAppointment->id,
            'type' => 'appointment_created',
            'title' => 'Unread two',
            'message' => 'Unread notification two.',
        ]);

        Sanctum::actingAs($patient);

        $this->getJson('/api/v1/patient/notifications')
            ->assertOk()
            ->assertJsonPath('unread_count', 2)
            ->assertJsonCount(2, 'notifications');

        $this->patchJson('/api/v1/patient/notifications/read-all')
            ->assertOk()
            ->assertJsonPath('updated_count', 2)
            ->assertJsonPath('unread_count', 0);

        $response = $this->getJson('/api/v1/patient/notifications');
        $response->assertOk()
            ->assertJsonPath('unread_count', 0)
            ->assertJsonCount(2, 'notifications');

        $notifications = collect($response->json('notifications'));
        $this->assertTrue(
            $notifications->every(
                fn (mixed $item): bool => is_array($item) && ($item['is_read'] ?? false) === true,
            ),
        );
    }

    public function test_notification_cache_version_advances_only_after_commit_when_notifications_are_created(): void
    {
        $patient = $this->createUserWithRole('Patient');
        $patientRecord = PatientRecord::resolveForUser($patient);
        $service = $this->createService('Notification after-commit cache');
        $appointment = $this->createAppointment((int) $patientRecord->id, (int) $service->id, '2026-04-21', '11:00');

        Sanctum::actingAs($patient);

        $this->getJson('/api/v1/patient/notifications')
            ->assertOk()
            ->assertJsonPath('unread_count', 0)
            ->assertJsonCount(0, 'notifications');

        $initialVersion = $this->patientNotificationCacheVersion((int) $patientRecord->id);

        DB::beginTransaction();
        try {
            PatientNotification::create([
                'patient_id' => (int) $patientRecord->id,
                'appointment_id' => (int) $appointment->id,
                'type' => 'appointment_created',
                'title' => 'Fresh notification',
                'message' => 'This should appear after commit.',
            ]);

            $this->assertSame($initialVersion, $this->patientNotificationCacheVersion((int) $patientRecord->id));

            DB::commit();
        } catch (\Throwable $throwable) {
            DB::rollBack();

            throw $throwable;
        }

        $this->assertGreaterThan($initialVersion, $this->patientNotificationCacheVersion((int) $patientRecord->id));

        $this->getJson('/api/v1/patient/notifications')
            ->assertOk()
            ->assertJsonPath('unread_count', 1)
            ->assertJsonCount(1, 'notifications')
            ->assertJsonPath('notifications.0.title', 'Fresh notification')
            ->assertJsonPath('notifications.0.is_read', false);
    }

    private function patientNotificationCacheVersion(int $patientRecordId): int
    {
        return (int) Cache::get(
            'central_cache:notifications:patient:'.$patientRecordId.':version',
            1,
        );
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

    private function createService(string $name): Service
    {
        return Service::create([
            'name' => $name,
            'description' => 'Service used by notification cache consistency tests.',
            'is_active' => true,
        ]);
    }

    private function createUserWithRole(string $roleName): User
    {
        $role = Role::firstOrCreate(['name' => $roleName]);
        $suffix = Str::lower($roleName).'_'.Str::lower(Str::random(8));

        return User::create([
            'first_name' => $roleName,
            'middle_name' => null,
            'last_name' => 'User',
            'username' => $suffix,
            'email' => $suffix.'@example.com',
            'password' => Hash::make('password123'),
            'phone_number' => '09123456789',
            'location' => 'Test City',
            'gender' => 'other',
            'role_id' => $role->id,
            'is_active' => true,
        ]);
    }
}
