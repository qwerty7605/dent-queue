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

class CentralizedCacheStrategyTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();

        Cache::flush();
        config()->set('cache.centralized_ttl_seconds.dashboard', 60);
        config()->set('cache.centralized_ttl_seconds.reports', 120);
        config()->set('cache.centralized_ttl_seconds.notifications', 30);
    }

    public function test_dashboard_stats_are_served_from_cache_and_invalidated_on_model_changes(): void
    {
        $admin = $this->createUserWithRole('Admin');
        $patient = $this->createUserWithRole('Patient');
        $service = $this->createService();

        Appointment::create([
            'patient_id' => $patient->id,
            'service_id' => $service->id,
            'appointment_date' => '2026-04-12',
            'time_slot' => '09:00',
            'status' => 'pending',
        ]);

        Sanctum::actingAs($admin);

        $this->getJson('/api/v1/admin/dashboard/stats')
            ->assertOk()
            ->assertJsonPath('data.appointments_count', 1);

        DB::table('appointments')->delete();

        $this->getJson('/api/v1/admin/dashboard/stats')
            ->assertOk()
            ->assertJsonPath('data.appointments_count', 1);

        Appointment::create([
            'patient_id' => $patient->id,
            'service_id' => $service->id,
            'appointment_date' => '2026-04-13',
            'time_slot' => '10:00',
            'status' => 'pending',
        ]);

        Appointment::create([
            'patient_id' => $patient->id,
            'service_id' => $service->id,
            'appointment_date' => '2026-04-14',
            'time_slot' => '11:00',
            'status' => 'confirmed',
        ]);

        $this->getJson('/api/v1/admin/dashboard/stats')
            ->assertOk()
            ->assertJsonPath('data.appointments_count', 2);
    }

    public function test_report_summary_uses_cache_before_querying_database_again(): void
    {
        $admin = $this->createUserWithRole('Admin');
        $patient = $this->createUserWithRole('Patient');
        $service = $this->createService();

        Appointment::create([
            'patient_id' => $patient->id,
            'service_id' => $service->id,
            'appointment_date' => '2026-04-12',
            'time_slot' => '09:00',
            'status' => 'pending',
        ]);

        Sanctum::actingAs($admin);

        $this->getJson('/api/v1/admin/reports/summary')
            ->assertOk()
            ->assertJsonPath('data.total_appointments', 1)
            ->assertJsonPath('data.pending_count', 1);

        DB::table('appointments')->delete();

        $this->getJson('/api/v1/admin/reports/summary')
            ->assertOk()
            ->assertJsonPath('data.total_appointments', 1)
            ->assertJsonPath('data.pending_count', 1);

        Appointment::create([
            'patient_id' => $patient->id,
            'service_id' => $service->id,
            'appointment_date' => '2026-04-13',
            'time_slot' => '10:00',
            'status' => 'completed',
        ]);

        Appointment::create([
            'patient_id' => $patient->id,
            'service_id' => $service->id,
            'appointment_date' => '2026-04-14',
            'time_slot' => '11:00',
            'status' => 'cancelled',
        ]);

        $this->getJson('/api/v1/admin/reports/summary')
            ->assertOk()
            ->assertJsonPath('data.total_appointments', 2)
            ->assertJsonPath('data.pending_count', 0)
            ->assertJsonPath('data.completed_count', 1)
            ->assertJsonPath('data.cancelled_count', 1);
    }

    public function test_dashboard_cache_expires_after_configured_ttl(): void
    {
        $admin = $this->createUserWithRole('Admin');
        $patient = $this->createUserWithRole('Patient');
        $service = $this->createService();

        Appointment::create([
            'patient_id' => $patient->id,
            'service_id' => $service->id,
            'appointment_date' => '2026-04-12',
            'time_slot' => '09:00',
            'status' => 'pending',
        ]);

        Sanctum::actingAs($admin);

        $this->getJson('/api/v1/admin/dashboard/stats')
            ->assertOk()
            ->assertJsonPath('data.appointments_count', 1);

        DB::table('appointments')->delete();

        $this->travel(59)->seconds();
        $this->getJson('/api/v1/admin/dashboard/stats')
            ->assertOk()
            ->assertJsonPath('data.appointments_count', 1);

        $this->travel(2)->seconds();
        $this->getJson('/api/v1/admin/dashboard/stats')
            ->assertOk()
            ->assertJsonPath('data.appointments_count', 0);
    }

    public function test_dashboard_force_refresh_bypasses_cached_stats(): void
    {
        $admin = $this->createUserWithRole('Admin');
        $patient = $this->createUserWithRole('Patient');
        $service = $this->createService();

        Appointment::create([
            'patient_id' => $patient->id,
            'service_id' => $service->id,
            'appointment_date' => '2026-04-12',
            'time_slot' => '09:00',
            'status' => 'pending',
        ]);

        Sanctum::actingAs($admin);

        $this->getJson('/api/v1/admin/dashboard/stats')
            ->assertOk()
            ->assertJsonPath('data.appointments_count', 1);

        DB::table('appointments')->delete();

        $this->getJson('/api/v1/admin/dashboard/stats?force_refresh=true')
            ->assertOk()
            ->assertJsonPath('data.appointments_count', 0);
    }

    public function test_report_cache_expires_after_configured_ttl(): void
    {
        $admin = $this->createUserWithRole('Admin');
        $patient = $this->createUserWithRole('Patient');
        $service = $this->createService();

        Appointment::create([
            'patient_id' => $patient->id,
            'service_id' => $service->id,
            'appointment_date' => '2026-04-12',
            'time_slot' => '09:00',
            'status' => 'pending',
        ]);

        Sanctum::actingAs($admin);

        $this->getJson('/api/v1/admin/reports/summary')
            ->assertOk()
            ->assertJsonPath('data.total_appointments', 1);

        DB::table('appointments')->delete();

        $this->travel(119)->seconds();
        $this->getJson('/api/v1/admin/reports/summary')
            ->assertOk()
            ->assertJsonPath('data.total_appointments', 1);

        $this->travel(2)->seconds();
        $this->getJson('/api/v1/admin/reports/summary')
            ->assertOk()
            ->assertJsonPath('data.total_appointments', 0);
    }

    public function test_notifications_are_cached_then_refreshed_when_notifications_change(): void
    {
        $patient = $this->createUserWithRole('Patient');
        $service = $this->createService();
        $patientRecord = PatientRecord::resolveForUser($patient);

        $appointment = Appointment::create([
            'patient_id' => $patientRecord->id,
            'service_id' => $service->id,
            'appointment_date' => '2026-04-12',
            'time_slot' => '09:00',
            'status' => 'pending',
        ]);

        PatientNotification::create([
            'patient_id' => $patientRecord->id,
            'appointment_id' => $appointment->id,
            'type' => 'appointment_created',
            'title' => 'First cached notification',
            'message' => 'Initial cached notification.',
        ]);

        Sanctum::actingAs($patient);

        $this->getJson('/api/v1/patient/notifications')
            ->assertOk()
            ->assertJsonPath('unread_count', 1)
            ->assertJsonCount(1, 'notifications')
            ->assertJsonPath('notifications.0.title', 'First cached notification');

        DB::table('patient_notifications')->delete();

        $this->getJson('/api/v1/patient/notifications')
            ->assertOk()
            ->assertJsonPath('unread_count', 1)
            ->assertJsonCount(1, 'notifications')
            ->assertJsonPath('notifications.0.title', 'First cached notification');

        PatientNotification::create([
            'patient_id' => $patientRecord->id,
            'appointment_id' => $appointment->id,
            'type' => 'appointment_created',
            'title' => 'New notification A',
            'message' => 'New notification A',
        ]);

        PatientNotification::create([
            'patient_id' => $patientRecord->id,
            'appointment_id' => $appointment->id,
            'type' => 'appointment_created',
            'title' => 'New notification B',
            'message' => 'New notification B',
        ]);

        $this->getJson('/api/v1/patient/notifications')
            ->assertOk()
            ->assertJsonPath('unread_count', 2)
            ->assertJsonCount(2, 'notifications')
            ->assertJsonPath('notifications.0.title', 'New notification B');
    }

    public function test_notification_cache_expires_after_configured_ttl(): void
    {
        $patient = $this->createUserWithRole('Patient');
        $service = $this->createService();
        $patientRecord = PatientRecord::resolveForUser($patient);

        $appointment = Appointment::create([
            'patient_id' => $patientRecord->id,
            'service_id' => $service->id,
            'appointment_date' => '2026-04-12',
            'time_slot' => '09:00',
            'status' => 'pending',
        ]);

        PatientNotification::create([
            'patient_id' => $patientRecord->id,
            'appointment_id' => $appointment->id,
            'type' => 'appointment_created',
            'title' => 'TTL notification',
            'message' => 'Will expire after the configured window.',
        ]);

        Sanctum::actingAs($patient);

        $this->getJson('/api/v1/patient/notifications')
            ->assertOk()
            ->assertJsonPath('unread_count', 1)
            ->assertJsonCount(1, 'notifications');

        DB::table('patient_notifications')->delete();

        $this->travel(29)->seconds();
        $this->getJson('/api/v1/patient/notifications')
            ->assertOk()
            ->assertJsonPath('unread_count', 1)
            ->assertJsonCount(1, 'notifications');

        $this->travel(2)->seconds();
        $this->getJson('/api/v1/patient/notifications')
            ->assertOk()
            ->assertJsonPath('unread_count', 0)
            ->assertJsonCount(0, 'notifications');
    }

    public function test_notifications_force_refresh_bypasses_cached_list(): void
    {
        $patient = $this->createUserWithRole('Patient');
        $service = $this->createService();
        $patientRecord = PatientRecord::resolveForUser($patient);

        $appointment = Appointment::create([
            'patient_id' => $patientRecord->id,
            'service_id' => $service->id,
            'appointment_date' => '2026-04-12',
            'time_slot' => '09:00',
            'status' => 'pending',
        ]);

        PatientNotification::create([
            'patient_id' => $patientRecord->id,
            'appointment_id' => $appointment->id,
            'type' => 'appointment_created',
            'title' => 'Cached notification',
            'message' => 'Cached notification.',
        ]);

        Sanctum::actingAs($patient);

        $this->getJson('/api/v1/patient/notifications')
            ->assertOk()
            ->assertJsonPath('unread_count', 1)
            ->assertJsonCount(1, 'notifications');

        DB::table('patient_notifications')->delete();

        $this->getJson('/api/v1/patient/notifications?force_refresh=true')
            ->assertOk()
            ->assertJsonPath('unread_count', 0)
            ->assertJsonCount(0, 'notifications');
    }

    private function createService(): Service
    {
        return Service::create([
            'name' => 'Cache Test Service',
            'description' => 'Service used by cache strategy tests.',
            'is_active' => true,
        ]);
    }

    private function createUserWithRole(string $roleName): User
    {
        $role = Role::firstOrCreate(['name' => $roleName]);
        $suffix = Str::lower($roleName) . '_' . Str::lower(Str::random(8));

        $user = User::create([
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

        if ($roleName === 'Patient') {
            PatientRecord::syncFromUser($user);
        }

        return $user;
    }
}
