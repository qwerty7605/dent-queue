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
    private $internRole;

    protected function setUp(): void
    {
        parent::setUp();

        Role::create(['name' => 'Admin']);
        $this->staffRole = Role::create(['name' => 'Staff']);
        $this->internRole = Role::create(['name' => 'Intern']);
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
        $staffUser = User::create([
            'first_name' => 'Staff',
            'last_name' => 'One',
            'email' => 'staff1@example.com',
            'username' => 'staff1',
            'password' => bcrypt('password123'),
            'role_id' => $this->staffRole->id,
            'is_active' => true,
        ]);
        $internUser = User::create([
            'first_name' => 'Intern',
            'last_name' => 'One',
            'email' => 'intern1@example.com',
            'username' => 'intern1',
            'password' => bcrypt('password123'),
            'role_id' => $this->internRole->id,
            'is_active' => true,
        ]);

        Sanctum::actingAs($this->admin);

        $response = $this->getJson('/api/v1/admin/staff');

        $response->assertStatus(200)
            ->assertJsonCount(2, 'data')
            ->assertJsonStructure([
                'data' => [
                    '*' => [
                        'role',
                        'staff_record'
                    ]
                ]
            ]);

        $listedUsers = collect($response->json('data'));

        $this->assertTrue($listedUsers->contains(fn ($user) => data_get($user, 'username') === $staffUser->username && data_get($user, 'role.name') === 'Staff'));
        $this->assertTrue($listedUsers->contains(fn ($user) => data_get($user, 'username') === $internUser->username && data_get($user, 'role.name') === 'Intern'));
    }

    public function test_admin_can_create_staff(): void
    {
        Sanctum::actingAs($this->admin);

        $response = $this->postJson('/api/v1/admin/staff', [
            'first_name' => 'New',
            'middle_name' => 'Mae',
            'last_name' => 'Staff',
            'gender' => 'female',
            'address' => 'Staff House 1',
            'contact_number' => '09123456789',
            'role' => 'staff',
            'username' => 'newstaff',
            'password' => 'password123',
            'password_confirmation' => 'password123',
        ]);

        $response->assertStatus(201)
            ->assertJsonPath('message', 'Staff account successfully created.')
            ->assertJsonPath('data.username', 'newstaff')
            ->assertJsonPath('data.middle_name', 'Mae')
            ->assertJsonPath('data.role.name', 'Staff')
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
            'middle_name' => 'Mae',
            'role_id' => $this->staffRole->id,
        ]);

        $this->assertDatabaseHas('staff_records', [
            'first_name' => 'New',
            'middle_name' => 'Mae',
            'last_name' => 'Staff',
            'contact_number' => '09123456789',
        ]);
    }

    public function test_admin_can_create_intern(): void
    {
        Sanctum::actingAs($this->admin);

        $response = $this->postJson('/api/v1/admin/staff', [
            'first_name' => 'New',
            'last_name' => 'Intern',
            'gender' => 'male',
            'address' => 'Intern House 1',
            'contact_number' => '09999999999',
            'role' => 'intern',
            'username' => 'newintern',
            'password' => 'password123',
            'password_confirmation' => 'password123',
        ]);

        $response->assertStatus(201)
            ->assertJsonPath('message', 'Intern account successfully created.')
            ->assertJsonPath('data.username', 'newintern')
            ->assertJsonPath('data.role.name', 'Intern')
            ->assertJsonPath('data.staff_record', null);

        $this->assertDatabaseHas('users', [
            'username' => 'newintern',
            'email' => 'newintern@system.intern',
            'role_id' => $this->internRole->id,
        ]);
    }

    public function test_admin_cannot_create_staff_with_invalid_contact_number(): void
    {
        Sanctum::actingAs($this->admin);

        $response = $this->postJson('/api/v1/admin/staff', [
            'first_name' => 'New',
            'last_name' => 'Staff',
            'gender' => 'female',
            'address' => 'Staff House 1',
            'contact_number' => '12345678901',
            'role' => 'staff',
            'username' => 'badstaff',
            'password' => 'password123',
            'password_confirmation' => 'password123',
        ]);

        $response->assertStatus(422)
            ->assertJsonValidationErrors(['contact_number'])
            ->assertJsonPath('errors.contact_number.0', 'Contact number must be a valid 11-digit mobile number starting with 09.');
    }

    public function test_admin_cannot_create_staff_with_invalid_username_format(): void
    {
        Sanctum::actingAs($this->admin);

        $response = $this->postJson('/api/v1/admin/staff', [
            'first_name' => 'New',
            'last_name' => 'Staff',
            'gender' => 'female',
            'address' => 'Staff House 1',
            'contact_number' => '09123456789',
            'role' => 'staff',
            'username' => 'bad staff',
            'password' => 'password123',
            'password_confirmation' => 'password123',
        ]);

        $response->assertStatus(422)
            ->assertJsonValidationErrors(['username'])
            ->assertJsonPath('errors.username.0', 'Username may only contain letters, numbers, dots, hyphens, and underscores.');
    }

    public function test_admin_can_create_intern_even_if_role_row_was_missing(): void
    {
        $this->internRole->delete();
        Sanctum::actingAs($this->admin);

        $response = $this->postJson('/api/v1/admin/staff', [
            'first_name' => 'Recovered',
            'last_name' => 'Intern',
            'gender' => 'male',
            'address' => 'Intern House 2',
            'contact_number' => '09123456789',
            'role' => 'intern',
            'username' => 'recoveredintern',
            'password' => 'password123',
            'password_confirmation' => 'password123',
        ]);

        $response->assertStatus(201)
            ->assertJsonPath('message', 'Intern account successfully created.')
            ->assertJsonPath('data.role.name', 'Intern');

        $this->assertDatabaseHas('roles', [
            'name' => 'Intern',
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

    public function test_admin_can_deactivate_intern(): void
    {
        $intern = User::create([
            'first_name' => 'To',
            'last_name' => 'Remove',
            'email' => 'removeintern@example.com',
            'username' => 'removeintern',
            'password' => bcrypt('password123'),
            'role_id' => $this->internRole->id,
            'is_active' => true,
        ]);

        Sanctum::actingAs($this->admin);

        $response = $this->deleteJson("/api/v1/admin/staff/{$intern->id}");

        $response->assertStatus(200)
            ->assertJsonPath('message', 'Intern account successfully removed.');

        $this->assertDatabaseHas('users', [
            'id' => $intern->id,
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
