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

class AdminReportsSummaryApiTest extends TestCase
{
    use RefreshDatabase;

    public function test_admin_can_access_reports_summary(): void
    {
        $admin = $this->createUserWithRole('Admin');
        $service = Service::create(['name' => 'General Checkup', 'is_active' => true]);
        $patient = $this->createUserWithRole('Patient');

        // Create appointments with various statuses
        // 2 Pending
        Appointment::create([
            'patient_id' => $patient->id,
            'service_id' => $service->id,
            'appointment_date' => '2026-04-01',
            'time_slot' => '08:00',
            'status' => 'pending',
        ]);
        Appointment::create([
            'patient_id' => $patient->id,
            'service_id' => $service->id,
            'appointment_date' => '2026-04-01',
            'time_slot' => '09:00',
            'status' => 'pending',
        ]);

        // 3 Approved (confirmed)
        Appointment::create([
            'patient_id' => $patient->id,
            'service_id' => $service->id,
            'appointment_date' => '2026-04-02',
            'time_slot' => '10:00',
            'status' => 'confirmed',
        ]);
        Appointment::create([
            'patient_id' => $patient->id,
            'service_id' => $service->id,
            'appointment_date' => '2026-04-02',
            'time_slot' => '11:00',
            'status' => 'confirmed',
        ]);
        Appointment::create([
            'patient_id' => $patient->id,
            'service_id' => $service->id,
            'appointment_date' => '2026-04-02',
            'time_slot' => '12:00',
            'status' => 'confirmed',
        ]);

        // 1 Completed
        Appointment::create([
            'patient_id' => $patient->id,
            'service_id' => $service->id,
            'appointment_date' => '2026-04-03',
            'time_slot' => '13:00',
            'status' => 'completed',
        ]);

        // 1 Cancelled
        Appointment::create([
            'patient_id' => $patient->id,
            'service_id' => $service->id,
            'appointment_date' => '2026-04-04',
            'time_slot' => '14:00',
            'status' => 'cancelled',
        ]);

        Sanctum::actingAs($admin);

        $response = $this->getJson('/api/v1/admin/reports/summary');

        $response->assertOk()
            ->assertJsonStructure([
                'data' => [
                    'total_appointments',
                    'pending_count',
                    'approved_count',
                    'completed_count',
                    'cancelled_count',
                ]
            ])
            ->assertJsonFragment([
                'total_appointments' => 7,
                'pending_count' => 2,
                'approved_count' => 3,
                'completed_count' => 1,
                'cancelled_count' => 1,
            ]);
    }

    public function test_unauthorized_patient_cannot_access_reports_summary(): void
    {
        $patient = $this->createUserWithRole('Patient');
        Sanctum::actingAs($patient);

        $response = $this->getJson('/api/v1/admin/reports/summary');

        $response->assertForbidden();
    }

    public function test_reports_summary_returns_zeros_when_no_appointments_exist(): void
    {
        $admin = $this->createUserWithRole('Admin');
        Sanctum::actingAs($admin);

        $response = $this->getJson('/api/v1/admin/reports/summary');

        $response->assertOk()
            ->assertJsonFragment([
                'total_appointments' => 0,
                'pending_count' => 0,
                'approved_count' => 0,
                'completed_count' => 0,
                'cancelled_count' => 0,
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
