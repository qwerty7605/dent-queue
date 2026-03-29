<?php

namespace Tests\Feature;

use App\Models\Appointment;
use App\Models\Role;
use App\Models\Service;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Str;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class AdminReportsTrendsApiTest extends TestCase
{
    use RefreshDatabase;

    public function test_admin_can_access_daily_trends_in_consistent_order(): void
    {
        [$admin, $patient, $service] = $this->createTrendFixture();

        Sanctum::actingAs($admin);

        $response = $this->getJson('/api/v1/admin/reports/trends?trend_type=daily');

        $response->assertOk()->assertExactJson([
            'data' => [
                ['trend_type' => 'daily', 'label' => '2026-04-01', 'count' => 2],
                ['trend_type' => 'daily', 'label' => '2026-04-02', 'count' => 1],
                ['trend_type' => 'daily', 'label' => '2026-04-08', 'count' => 1],
                ['trend_type' => 'daily', 'label' => '2026-04-10', 'count' => 1],
                ['trend_type' => 'daily', 'label' => '2026-05-03', 'count' => 1],
            ],
        ]);
    }

    public function test_admin_can_access_weekly_trends(): void
    {
        [$admin] = $this->createTrendFixture();

        Sanctum::actingAs($admin);

        $response = $this->getJson('/api/v1/admin/reports/trends?trend_type=weekly');

        $response->assertOk()->assertExactJson([
            'data' => [
                ['trend_type' => 'weekly', 'label' => '2026-W14', 'count' => 3],
                ['trend_type' => 'weekly', 'label' => '2026-W15', 'count' => 2],
                ['trend_type' => 'weekly', 'label' => '2026-W18', 'count' => 1],
            ],
        ]);
    }

    public function test_admin_can_access_monthly_trends(): void
    {
        [$admin] = $this->createTrendFixture();

        Sanctum::actingAs($admin);

        $response = $this->getJson('/api/v1/admin/reports/trends?trend_type=monthly');

        $response->assertOk()->assertExactJson([
            'data' => [
                ['trend_type' => 'monthly', 'label' => '2026-04', 'count' => 5],
                ['trend_type' => 'monthly', 'label' => '2026-05', 'count' => 1],
            ],
        ]);
    }

    public function test_unauthorized_patient_cannot_access_reports_trends(): void
    {
        $patient = $this->createUserWithRole('Patient');
        Sanctum::actingAs($patient);

        $response = $this->getJson('/api/v1/admin/reports/trends?trend_type=daily');

        $response->assertForbidden();
    }

    public function test_reports_trends_return_empty_data_safely(): void
    {
        $admin = $this->createUserWithRole('Admin');
        Sanctum::actingAs($admin);

        $response = $this->getJson('/api/v1/admin/reports/trends?trend_type=monthly');

        $response->assertOk()->assertExactJson([
            'data' => [],
        ]);
    }

    public function test_reports_trends_reject_invalid_trend_type(): void
    {
        $admin = $this->createUserWithRole('Admin');
        Sanctum::actingAs($admin);

        $response = $this->getJson('/api/v1/admin/reports/trends?trend_type=quarterly');

        $response->assertStatus(422)->assertJsonValidationErrors(['trend_type']);
    }

    private function createTrendFixture(): array
    {
        $admin = $this->createUserWithRole('Admin');
        $patient = $this->createUserWithRole('Patient');
        $service = Service::create([
            'name' => 'General Checkup',
            'is_active' => true,
        ]);

        $this->createAppointment($patient, $service, '2026-04-10', '10:00', 'pending');
        $this->createAppointment($patient, $service, '2026-04-01', '09:00', 'confirmed');
        $this->createAppointment($patient, $service, '2026-05-03', '13:00', 'cancelled');
        $this->createAppointment($patient, $service, '2026-04-08', '08:30', 'completed');
        $this->createAppointment($patient, $service, '2026-04-02', '11:15', 'pending');
        $this->createAppointment($patient, $service, '2026-04-01', '15:45', 'confirmed');

        return [$admin, $patient, $service];
    }

    private function createAppointment(
        User $patient,
        Service $service,
        string $date,
        string $time,
        string $status,
    ): Appointment {
        return Appointment::create([
            'patient_id' => $patient->id,
            'service_id' => $service->id,
            'appointment_date' => $date,
            'time_slot' => $time,
            'status' => $status,
        ]);
    }

    private function createUserWithRole(string $roleName): User
    {
        $role = Role::firstOrCreate(['name' => $roleName]);
        $suffix = Str::lower($roleName) . '_' . Str::lower(Str::random(8));

        $user = User::create([
            'first_name' => $roleName,
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
            \App\Models\PatientRecord::syncFromUser($user);
        }

        return $user;
    }
}
