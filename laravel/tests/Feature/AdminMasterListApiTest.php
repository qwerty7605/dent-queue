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

class AdminMasterListApiTest extends TestCase
{
    use RefreshDatabase;

    public function test_admin_master_list_returns_all_appointments_with_mapped_status(): void
    {
        $admin = $this->createUserWithRole('Admin');
        $service = Service::create(['name' => 'General Checkup', 'is_active' => true]);
        
        $patient = $this->createUserWithRole('Patient');
        
        // Create appointments with different statuses
        Appointment::create([
            'patient_id' => $patient->id,
            'service_id' => $service->id,
            'appointment_date' => '2026-04-01',
            'time_slot' => '08:00',
            'status' => 'confirmed', // Should be mapped to 'Approved'
            'contact' => '09123456789'
        ]);

        Appointment::create([
            'patient_id' => $patient->id,
            'service_id' => $service->id,
            'appointment_date' => '2026-04-01',
            'time_slot' => '09:00',
            'status' => 'pending', // Should stay 'Pending'
            'contact' => '09123456789'
        ]);

        Sanctum::actingAs($admin);

        $response = $this->getJson('/api/v1/admin/appointments/master-list');

        $response->assertOk()
            ->assertJsonCount(2, 'data');

        $data = $response->json('data');

        // Check if 'confirmed' is mapped to 'Approved'
        $confirmedToApproved = collect($data)->firstWhere('status', 'Approved');
        $this->assertNotNull($confirmedToApproved);
        $this->assertEquals('Approved', $confirmedToApproved['status']);

        // Check if 'pending' is mapped to 'Pending'
        $pendingToPending = collect($data)->firstWhere('status', 'Pending');
        $this->assertNotNull($pendingToPending);
        $this->assertEquals('Pending', $pendingToPending['status']);
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
}
