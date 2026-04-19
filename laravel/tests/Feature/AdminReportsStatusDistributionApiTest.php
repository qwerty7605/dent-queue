<?php

namespace Tests\Feature;

use App\Models\Appointment;
use App\Models\PatientRecord;
use App\Models\Role;
use App\Models\Service;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Str;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class AdminReportsStatusDistributionApiTest extends TestCase
{
    use RefreshDatabase;

    public function test_admin_can_access_status_distribution(): void
    {
        $admin = $this->createUserWithRole('Admin');
        $patient = $this->createUserWithRole('Patient');
        $service = Service::create(['name' => 'General Checkup', 'is_active' => true]);

        // Create appointments with various statuses
        $this->createAppointment($patient, $service, 'pending');
        $this->createAppointment($patient, $service, 'pending');
        $this->createAppointment($patient, $service, 'confirmed'); // approved
        $this->createAppointment($patient, $service, 'completed');
        $this->createAppointment($patient, $service, 'cancelled');
        $this->createAppointment($patient, $service, 'cancelled_by_doctor');
        $this->createAppointment($patient, $service, 'reschedule_required');

        Sanctum::actingAs($admin);

        $response = $this->getJson('/api/v1/admin/reports/status-distribution');

        $response->assertOk()
            ->assertJsonStructure([
                'data' => [
                    '*' => ['status', 'count']
                ]
            ])
            ->assertJsonFragment(['status' => 'pending', 'count' => 2])
            ->assertJsonFragment(['status' => 'approved', 'count' => 1])
            ->assertJsonFragment(['status' => 'completed', 'count' => 1])
            ->assertJsonFragment(['status' => 'cancelled', 'count' => 1])
            ->assertJsonFragment(['status' => 'cancelled_by_doctor', 'count' => 1])
            ->assertJsonFragment(['status' => 'reschedule_required', 'count' => 1]);
    }

    public function test_unauthorized_patient_cannot_access_status_distribution(): void
    {
        $patient = $this->createUserWithRole('Patient');
        Sanctum::actingAs($patient);

        $response = $this->getJson('/api/v1/admin/reports/status-distribution');

        $response->assertForbidden();
    }

    public function test_status_distribution_returns_zeros_when_no_appointments_exist(): void
    {
        $admin = $this->createUserWithRole('Admin');
        Sanctum::actingAs($admin);

        $response = $this->getJson('/api/v1/admin/reports/status-distribution');

        $response->assertOk()
            ->assertJsonFragment(['status' => 'pending', 'count' => 0])
            ->assertJsonFragment(['status' => 'approved', 'count' => 0])
            ->assertJsonFragment(['status' => 'completed', 'count' => 0])
            ->assertJsonFragment(['status' => 'cancelled', 'count' => 0])
            ->assertJsonFragment(['status' => 'cancelled_by_doctor', 'count' => 0])
            ->assertJsonFragment(['status' => 'reschedule_required', 'count' => 0]);
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
            PatientRecord::syncFromUser($user);
        }

        return $user;
    }

    private function createAppointment($patient, $service, string $status)
    {
        static $minute = 0;
        return Appointment::create([
            'patient_id' => $patient->id,
            'service_id' => $service->id,
            'appointment_date' => now()->format('Y-m-d'),
            'time_slot' => sprintf('08:%02d', $minute++),
            'status' => $status,
        ]);
    }
}
