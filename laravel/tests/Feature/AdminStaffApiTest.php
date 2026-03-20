<?php

namespace Tests\Feature;

use App\Models\Role;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class AdminStaffApiTest extends TestCase
{
    use RefreshDatabase;

    private $admin;
    private $staffRole;

    protected function setUp(): void
    {
        parent::setUp();

        Role::create(['name' => 'Admin']);
        $this->staffRole = Role::create(['name' => 'Staff']);
        Role::create(['name' => 'Patient']);

        $this->admin = User::create([
            'first_name' => 'Admin',
            'last_name' => 'User',
            'email' => 'admin@example.com',
            'username' => 'admin',
            'password' => bcrypt('password123'),
            'role_id' => Role::where('name', 'Admin')->first()->id,
            'is_active' => true,
        ]);
    }

    public function test_admin_can_list_staff(): void
    {
        $user = User::create([
            'first_name' => 'Staff',
            'last_name' => 'One',
            'email' => 'staff1@example.com',
            'username' => 'staff1',
            'password' => bcrypt('password123'),
            'role_id' => $this->staffRole->id,
            'is_active' => true,
        ]);

        Sanctum::actingAs($this->admin);

        $response = $this->getJson('/api/v1/admin/staff');

        $response->assertStatus(200)
            ->assertJsonCount(1, 'data')
            ->assertJsonPath('data.0.username', 'staff1')
            ->assertJsonStructure([
                'data' => [
                    '*' => [
                        'staff_record'
                    ]
                ]
            ]);
    }

    public function test_admin_can_create_staff(): void
    {
        Sanctum::actingAs($this->admin);

        $response = $this->postJson('/api/v1/admin/staff', [
            'first_name' => 'New',
            'last_name' => 'Staff',
            'birthdate' => '1990-01-01',
            'gender' => 'female',
            'address' => 'Staff House 1',
            'contact_number' => '09123456789',
            'username' => 'newstaff',
            'password' => 'password123',
            'password_confirmation' => 'password123',
        ]);

        $response->assertStatus(201)
            ->assertJsonPath('data.username', 'newstaff')
            ->assertJsonStructure([
                'data' => [
                    'staff_record' => [
                        'staff_id'
                    ]
                ]
            ]);

        $this->assertDatabaseHas('users', [
            'username' => 'newstaff',
            'email' => 'newstaff@system.staff',
            'role_id' => $this->staffRole->id,
        ]);

        $this->assertDatabaseHas('staff_records', [
            'first_name' => 'New',
            'last_name' => 'Staff',
            'contact_number' => '09123456789',
        ]);
    }

    public function test_admin_can_deactivate_staff(): void
    {
        $staff = User::create([
            'first_name' => 'To',
            'last_name' => 'Remove',
            'email' => 'remove@example.com',
            'username' => 'removeme',
            'password' => bcrypt('password123'),
            'role_id' => $this->staffRole->id,
            'is_active' => true,
        ]);

        Sanctum::actingAs($this->admin);

        $response = $this->deleteJson("/api/v1/admin/staff/{$staff->id}");

        $response->assertStatus(200);
        $this->assertDatabaseHas('users', [
            'id' => $staff->id,
            'is_active' => false,
        ]);
    }

    public function test_patient_cannot_access_staff_api(): void
    {
        $patientRole = Role::where('name', 'Patient')->first();
        $patient = User::create([
            'first_name' => 'Patient',
            'last_name' => 'User',
            'email' => 'patient@example.com',
            'username' => 'patient',
            'password' => bcrypt('password123'),
            'role_id' => $patientRole->id,
            'is_active' => true,
        ]);

        Sanctum::actingAs($patient);

        $response = $this->getJson('/api/v1/admin/staff');
        $response->assertStatus(403);

        $response = $this->postJson('/api/v1/admin/staff', []);
        $response->assertStatus(403);
    }
}
