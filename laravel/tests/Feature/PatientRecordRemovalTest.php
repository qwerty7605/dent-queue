<?php

namespace Tests\Feature;

use App\Models\Appointment;
use App\Models\PatientRecord;
use App\Models\Service;
use App\Models\User;
use App\Models\Role;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;
use Carbon\Carbon;

class PatientRecordRemovalTest extends TestCase
{
    use RefreshDatabase;

    private User $admin;
    private Service $service;

    protected function setUp(): void
    {
        parent::setUp();

        $adminRole = Role::firstOrCreate(['name' => 'admin', 'description' => 'System Administrator']);
        $this->admin = User::firstOrCreate([
            'email' => 'admin@test.com'
        ], [
            'first_name' => 'Admin',
            'last_name' => 'User',
            'username' => 'admin_test',
            'password' => bcrypt('password'),
            'role_id' => $adminRole->id,
            'is_active' => true,
        ]);

        $this->service = Service::create([
            'name' => 'Test Service',
            'description' => 'Test Service Description',
            'price' => 100,
            'is_active' => true,
        ]);
    }

    public function test_registered_patient_removal_deactivates_user_but_preserves_record(): void
    {
        $patientRole = Role::firstOrCreate(['name' => 'patient', 'description' => 'Patient']);
        $user = User::create([
            'first_name' => 'John',
            'last_name' => 'Doe',
            'email' => 'john.doe@example.com',
            'username' => 'johndoe',
            'password' => bcrypt('password'),
            'role_id' => $patientRole->id,
            'is_active' => true,
        ]);

        // Patient record should be automatically created through the User boot event
        $patientRecord = $user->patientRecord;
        $this->assertNotNull($patientRecord);
        $this->assertFalse($patientRecord->trashed());

        $appointment = Appointment::create([
            'patient_id' => $patientRecord->id,
            'service_id' => $this->service->id,
            'appointment_date' => Carbon::tomorrow(),
            'time_slot' => '10:00:00',
            'status' => 'pending',
            'notes' => 'Test appointment',
        ]);

        $response = $this->actingAs($this->admin)->deleteJson('/api/v1/admin/patients/' . $patientRecord->patient_id);

        $response->assertStatus(200)
            ->assertJson(['message' => 'Patient record successfully removed.']);

        // User should be deactivated
        $this->assertEmpty($user->fresh()->is_active);

        // Patient record should NOT be soft deleted
        $this->assertFalse($patientRecord->fresh()->trashed());

        // Appointments should remain intact
        $this->assertDatabaseHas('appointments', ['id' => $appointment->id]);
    }

    public function test_walk_in_patient_removal_soft_deletes_record(): void
    {
        $patientRecord = PatientRecord::create([
            'id' => 9000000000001,
            'patient_id' => 'PAT-009000000000001',
            'first_name' => 'Walkin',
            'last_name' => 'Patient',
            'contact_number' => '09123456789',
        ]);

        $appointment = Appointment::create([
            'patient_id' => $patientRecord->id,
            'service_id' => $this->service->id,
            'appointment_date' => Carbon::tomorrow(),
            'time_slot' => '11:00:00',
            'status' => 'pending',
            'notes' => 'Walk in appointment',
        ]);

        $response = $this->actingAs($this->admin)->deleteJson('/api/v1/admin/patients/' . $patientRecord->patient_id);

        $response->assertStatus(200)
            ->assertJson(['message' => 'Patient record successfully removed.']);

        // Patient record should be soft deleted
        $this->assertTrue($patientRecord->fresh()->trashed());

        // Appointments should remain intact
        $this->assertDatabaseHas('appointments', ['id' => $appointment->id]);
    }

    public function test_removal_returns_404_for_invalid_target(): void
    {
        $response = $this->actingAs($this->admin)->deleteJson('/api/v1/admin/patients/PAT-9999999999999');

        $response->assertStatus(404);
    }
}
