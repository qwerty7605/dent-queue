<?php

namespace Tests\Feature;

use App\Models\Appointment;
use App\Models\Queue;
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

class QueueSummaryCacheTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();

        Cache::flush();
        config()->set('cache.centralized_ttl_seconds.queue', 60);
    }

    public function test_queue_snapshot_reuses_cached_summary_data(): void
    {
        $staff = $this->createUserWithRole('Staff');
        $service = $this->createService('Cached Queue Summary');
        $date = '2026-04-12';

        $patientA = $this->createUserWithRole('Patient');
        $patientB = $this->createUserWithRole('Patient');
        $patientC = $this->createUserWithRole('Patient');

        $appointmentA = $this->createAppointment((int) $patientA->id, $service->id, $date, '09:00', 'confirmed');
        $appointmentB = $this->createAppointment((int) $patientB->id, $service->id, $date, '10:00', 'confirmed');
        $appointmentC = $this->createAppointment((int) $patientC->id, $service->id, $date, '11:00', 'pending');

        $this->createQueue($appointmentA->id, $date, 1, true);
        $this->createQueue($appointmentB->id, $date, 2, false);
        $this->createQueue($appointmentC->id, $date, 3, false);

        Sanctum::actingAs($staff);

        $this->getJson('/api/v1/admin/queues/today?date=' . $date)
            ->assertOk()
            ->assertJsonPath('now_serving.queue_number', 1)
            ->assertJsonPath('next_up.queue_number', 2)
            ->assertJsonPath('queue_summary.total_queued', 3)
            ->assertJsonPath('queue_summary.next_slot', '10:00');

        DB::table('queues')->delete();

        $this->getJson('/api/v1/admin/queues/today?date=' . $date)
            ->assertOk()
            ->assertJsonPath('now_serving.queue_number', 1)
            ->assertJsonPath('next_up.queue_number', 2)
            ->assertJsonPath('queue_summary.total_queued', 3)
            ->assertJsonPath('queue_summary.next_slot', '10:00');
    }

    public function test_queue_summary_refreshes_after_queue_related_changes(): void
    {
        $staff = $this->createUserWithRole('Staff');
        $service = $this->createService('Queue Refresh');
        $date = '2026-04-12';

        $patientA = $this->createUserWithRole('Patient');
        $patientB = $this->createUserWithRole('Patient');

        $appointmentA = $this->createAppointment((int) $patientA->id, $service->id, $date, '09:00', 'confirmed');
        $appointmentB = $this->createAppointment((int) $patientB->id, $service->id, $date, '10:00', 'confirmed');

        $this->createQueue($appointmentA->id, $date, 1, true);
        $this->createQueue($appointmentB->id, $date, 2, false);

        Sanctum::actingAs($staff);

        $this->getJson('/api/v1/admin/queues/today?date=' . $date)
            ->assertOk()
            ->assertJsonPath('queue_summary.total_queued', 2)
            ->assertJsonPath('next_up.queue_number', 2);

        $patientC = $this->createUserWithRole('Patient');
        $appointmentC = $this->createAppointment((int) $patientC->id, $service->id, $date, '10:30', 'confirmed');
        $this->createQueue($appointmentC->id, $date, 3, false);

        $this->getJson('/api/v1/admin/queues/today?date=' . $date)
            ->assertOk()
            ->assertJsonPath('queue_summary.total_queued', 3)
            ->assertJsonPath('next_up.queue_number', 2);
    }

    private function createQueue(int $appointmentId, string $date, int $queueNumber, bool $isCalled): Queue
    {
        return Queue::create([
            'appointment_id' => $appointmentId,
            'queue_date' => $date,
            'queue_number' => $queueNumber,
            'is_called' => $isCalled,
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
            'description' => 'Queue summary cache service.',
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
