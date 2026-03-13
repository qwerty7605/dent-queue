<?php

namespace Tests\Feature;

use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;
use App\Models\User;
use App\Models\Role;
use App\Models\PatientRecord;

class PatientSearchTest extends TestCase
{
    use RefreshDatabase;

    public function test_staff_can_search_patients()
    {
        // Require role
        $staffRole = Role::updateOrCreate(['name' => 'staff'], ['name' => 'staff']);
        $staff = User::create([
            'role_id' => $staffRole->id,
            'first_name' => 'Staff',
            'last_name' => 'User',
            'username' => 'staff123',
            'email' => 'staff@example.com',
            'password' => bcrypt('password'),
            'phone_number' => '09123456780',
            'birthdate' => '1990-01-01',
            'location' => 'Clinic',
            'gender' => 'Male',
            'is_active' => true,
        ]);

        // Create a patient record
        $patientRole = Role::updateOrCreate(['name' => 'patient'], ['name' => 'patient']);
        $userPatient = User::create([
            'role_id' => $patientRole->id,
            'first_name' => 'Kyle',
            'last_name' => 'Aldea',
            'username' => 'kyle123',
            'email' => 'kyle@example.com',
            'password' => bcrypt('password'),
            'phone_number' => '09169014483',
            'birthdate' => '1995-01-01',
            'location' => 'City',
            'gender' => 'Male',
            'is_active' => true,
        ]);
        $patientRecord = PatientRecord::resolveForUser($userPatient);

        $this->actingAs($staff);

        // Test searching by name
        $response = $this->getJson('/api/v1/admin/patients/search?query=kyle');
        $response->assertStatus(200);
        $response->assertJsonFragment([
            'full_name' => 'Kyle Aldea',
            'contact_number' => '09169014483'
        ]);

        // Test searching by phone suffix
        $response = $this->getJson('/api/v1/admin/patients/search?query=14483');
        $response->assertStatus(200);
        $response->assertJsonFragment([
            'full_name' => 'Kyle Aldea',
            'contact_number' => '09169014483'
        ]);

        // Test searching by patient ID
        $response = $this->getJson('/api/v1/admin/patients/search?query=' . $patientRecord->patient_id);
        $response->assertStatus(200);
        $response->assertJsonFragment([
            'patient_id' => $patientRecord->patient_id,
            'full_name' => 'Kyle Aldea',
            'contact_number' => '09169014483'
        ]);

        // Test empty query returns empty data
        $response = $this->getJson('/api/v1/admin/patients/search?query=');
        $response->assertStatus(200);
        $response->assertJsonStructure(['data']);
        $this->assertEmpty($response->json('data'));
        
        echo "All search tests passed!\n";
    }
}
