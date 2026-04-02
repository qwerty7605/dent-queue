<?php

namespace Tests\Feature;

use App\Models\Appointment;
use App\Models\PatientRecord;
use App\Models\Role;
use App\Models\Service;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class AdminDashboardControllerTest extends TestCase
{
    use RefreshDatabase;

    public function test_dashboard_stats_include_staff_and_intern_account_counts(): void
    {
        $adminRole = Role::create(['name' => 'Admin']);
        $staffRole = Role::create(['name' => 'Staff']);
        $internRole = Role::create(['name' => 'Intern']);
        $patientRole = Role::create(['name' => 'Patient']);

        $admin = User::create([
            'first_name' => 'Admin',
            'last_name' => 'User',
            'email' => 'admin@example.com',
            'username' => 'admin',
            'password' => bcrypt('password123'),
            'role_id' => $adminRole->id,
            'is_active' => true,
        ]);

        User::create([
            'first_name' => 'Staff',
            'last_name' => 'Member',
            'email' => 'staff@example.com',
            'username' => 'staffmember',
            'password' => bcrypt('password123'),
            'role_id' => $staffRole->id,
            'is_active' => true,
        ]);

        User::create([
            'first_name' => 'Intern',
            'last_name' => 'Member',
            'email' => 'intern@example.com',
            'username' => 'internmember',
            'password' => bcrypt('password123'),
            'role_id' => $internRole->id,
            'is_active' => true,
        ]);

        User::create([
            'first_name' => 'Inactive',
            'last_name' => 'Intern',
            'email' => 'inactive-intern@example.com',
            'username' => 'inactiveintern',
            'password' => bcrypt('password123'),
            'role_id' => $internRole->id,
            'is_active' => false,
        ]);

        User::create([
            'first_name' => 'Patient',
            'last_name' => 'User',
            'email' => 'patient@example.com',
            'username' => 'patientuser',
            'password' => bcrypt('password123'),
            'role_id' => $patientRole->id,
            'is_active' => true,
        ]);

        $walkInPatient = PatientRecord::create([
            'id' => 1000000000002,
            'patient_id' => 'PAT-0002',
            'first_name' => 'Walkin',
            'middle_name' => null,
            'last_name' => 'Patient',
            'address' => 'Sample Address',
            'gender' => 'male',
            'contact_number' => '09123456780',
            'birthdate' => null,
            'user_id' => null,
        ]);

        $service = Service::create([
            'name' => 'Consultation',
            'description' => 'General consultation',
            'duration_minutes' => 30,
            'price' => 500,
        ]);

        Appointment::create([
            'patient_id' => $walkInPatient->id,
            'service_id' => $service->id,
            'appointment_date' => now()->format('Y-m-d'),
            'time_slot' => '09:00',
            'status' => 'confirmed',
        ]);

        Sanctum::actingAs($admin);

        $response = $this->getJson('/api/v1/admin/dashboard/stats');

        $response->assertOk()
            ->assertJsonPath('data.patients_count', 2)
            ->assertJsonPath('data.staff_count', 1)
            ->assertJsonPath('data.intern_count', 1)
            ->assertJsonPath('data.staff_accounts_count', 2)
            ->assertJsonPath('data.appointments_count', 1);
    }
}
