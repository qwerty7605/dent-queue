<?php

namespace Tests\Feature;

use App\Models\PatientRecord;
use App\Models\Role;
use App\Models\Service;
use App\Models\User;
use App\Services\AppointmentService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Str;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class AppointmentActionCacheInvalidationTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();

        Cache::flush();
        config()->set('cache.centralized_ttl_seconds.dashboard', 60);
        config()->set('cache.centralized_ttl_seconds.reports', 60);
        config()->set('cache.centralized_ttl_seconds.queue', 60);
    }

    public function test_create_appointment_refreshes_dashboard_reports_and_queue_after_commit(): void
    {
        $admin = $this->createUserWithRole('Admin');
        $patient = $this->createUserWithRole('Patient');
        $patientRecord = PatientRecord::resolveForUser($patient);
        $service = $this->createService('AGD-127 Create Cache');
        $date = now()->next('Monday')->format('Y-m-d');

        Sanctum::actingAs($admin);

        $this->getJson('/api/v1/admin/dashboard/stats')
            ->assertOk()
            ->assertJsonPath('data.appointments_count', 0);
        $this->getJson('/api/v1/admin/reports/summary')
            ->assertOk()
            ->assertJsonPath('data.total_appointments', 0);
        $this->getJson('/api/v1/admin/queues/today?date='.$date)
            ->assertOk()
            ->assertJsonPath('queue_summary.total_queued', 0)
            ->assertJsonPath('next_up', null);

        $initialVersions = $this->cacheVersions();

        DB::beginTransaction();
        try {
            app(AppointmentService::class)->createAppointment([
                'patient_id' => (int) $patientRecord->id,
                'service_id' => (int) $service->id,
                'appointment_date' => $date,
                'time_slot' => '09:00',
                'status' => 'approved',
                'notes' => 'AGD-127 create cache invalidation',
            ]);

            $this->assertCacheVersionsUnchanged($initialVersions);

            DB::commit();
        } catch (\Throwable $throwable) {
            DB::rollBack();

            throw $throwable;
        }

        $this->assertCacheVersionsAdvanced($initialVersions);

        $this->getJson('/api/v1/admin/dashboard/stats')
            ->assertOk()
            ->assertJsonPath('data.appointments_count', 1);
        $this->getJson('/api/v1/admin/reports/summary')
            ->assertOk()
            ->assertJsonPath('data.total_appointments', 1)
            ->assertJsonPath('data.approved_count', 1);
        $this->getJson('/api/v1/admin/queues/today?date='.$date)
            ->assertOk()
            ->assertJsonPath('queue_summary.total_queued', 1)
            ->assertJsonPath('next_up.queue_number', 1);
    }

    public function test_updating_appointment_status_refreshes_reports_and_queue_after_commit(): void
    {
        $admin = $this->createUserWithRole('Admin');
        $patient = $this->createUserWithRole('Patient');
        $patientRecord = PatientRecord::resolveForUser($patient);
        $service = $this->createService('AGD-127 Update Cache');
        $date = now()->next('Tuesday')->format('Y-m-d');

        $appointment = app(AppointmentService::class)->createAppointment([
            'patient_id' => (int) $patientRecord->id,
            'service_id' => (int) $service->id,
            'appointment_date' => $date,
            'time_slot' => '10:00',
            'status' => 'pending',
            'notes' => 'AGD-127 update cache invalidation',
        ]);

        Sanctum::actingAs($admin);

        $this->getJson('/api/v1/admin/reports/summary')
            ->assertOk()
            ->assertJsonPath('data.total_appointments', 1)
            ->assertJsonPath('data.pending_count', 1)
            ->assertJsonPath('data.approved_count', 0);
        $this->getJson('/api/v1/admin/queues/today?date='.$date)
            ->assertOk()
            ->assertJsonPath('queue_summary.total_queued', 1)
            ->assertJsonPath('next_up', null);

        $initialVersions = $this->cacheVersions();

        DB::beginTransaction();
        try {
            app(AppointmentService::class)->updateStatus(
                $appointment->fresh(),
                'approved',
                (int) $admin->id,
            );

            $this->assertCacheVersionsUnchanged($initialVersions);

            DB::commit();
        } catch (\Throwable $throwable) {
            DB::rollBack();

            throw $throwable;
        }

        $this->assertCacheVersionsAdvanced($initialVersions);

        $this->getJson('/api/v1/admin/reports/summary')
            ->assertOk()
            ->assertJsonPath('data.total_appointments', 1)
            ->assertJsonPath('data.pending_count', 0)
            ->assertJsonPath('data.approved_count', 1);
        $this->getJson('/api/v1/admin/queues/today?date='.$date)
            ->assertOk()
            ->assertJsonPath('queue_summary.total_queued', 1)
            ->assertJsonPath('next_up.queue_number', 1);
    }

    public function test_cancelling_appointment_refreshes_reports_and_queue_after_commit(): void
    {
        $admin = $this->createUserWithRole('Admin');
        $patient = $this->createUserWithRole('Patient');
        $patientRecord = PatientRecord::resolveForUser($patient);
        $service = $this->createService('AGD-127 Cancel Cache');
        $date = now()->next('Wednesday')->format('Y-m-d');

        $appointment = app(AppointmentService::class)->createAppointment([
            'patient_id' => (int) $patientRecord->id,
            'service_id' => (int) $service->id,
            'appointment_date' => $date,
            'time_slot' => '11:00',
            'status' => 'approved',
            'notes' => 'AGD-127 cancel cache invalidation',
        ]);

        Sanctum::actingAs($admin);

        $this->getJson('/api/v1/admin/reports/summary')
            ->assertOk()
            ->assertJsonPath('data.total_appointments', 1)
            ->assertJsonPath('data.approved_count', 1)
            ->assertJsonPath('data.cancelled_count', 0);
        $this->getJson('/api/v1/admin/queues/today?date='.$date)
            ->assertOk()
            ->assertJsonPath('queue_summary.total_queued', 1)
            ->assertJsonPath('next_up.queue_number', 1);

        $initialVersions = $this->cacheVersions();

        DB::beginTransaction();
        try {
            app(AppointmentService::class)->cancelByPatient(
                $appointment->fresh(),
                (int) $patientRecord->id,
            );

            $this->assertCacheVersionsUnchanged($initialVersions);

            DB::commit();
        } catch (\Throwable $throwable) {
            DB::rollBack();

            throw $throwable;
        }

        $this->assertCacheVersionsAdvanced($initialVersions);

        $this->getJson('/api/v1/admin/reports/summary')
            ->assertOk()
            ->assertJsonPath('data.total_appointments', 1)
            ->assertJsonPath('data.approved_count', 0)
            ->assertJsonPath('data.cancelled_count', 1);
        $this->getJson('/api/v1/admin/queues/today?date='.$date)
            ->assertOk()
            ->assertJsonPath('queue_summary.total_queued', 0)
            ->assertJsonPath('next_up', null);
    }

    private function cacheVersions(): array
    {
        return [
            'dashboard' => $this->cacheVersion('dashboard'),
            'reports' => $this->cacheVersion('reports'),
            'queue' => $this->cacheVersion('queue'),
        ];
    }

    private function cacheVersion(string $namespace): int
    {
        return (int) Cache::get('central_cache:'.$namespace.':version', 1);
    }

    private function assertCacheVersionsUnchanged(array $initialVersions): void
    {
        foreach ($initialVersions as $namespace => $version) {
            $this->assertSame($version, $this->cacheVersion($namespace));
        }
    }

    private function assertCacheVersionsAdvanced(array $initialVersions): void
    {
        foreach ($initialVersions as $namespace => $version) {
            $this->assertGreaterThan($version, $this->cacheVersion($namespace));
        }
    }

    private function createService(string $name): Service
    {
        return Service::create([
            'name' => $name,
            'description' => 'Service used by appointment cache invalidation tests.',
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
