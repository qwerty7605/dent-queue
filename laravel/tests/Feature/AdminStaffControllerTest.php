<?php

namespace Tests\Feature;

use App\Models\User;
use App\Models\Role;
use App\Models\StaffRecord;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class AdminStaffControllerTest extends TestCase
{
    use RefreshDatabase;

    private User $admin;
    private Role $staffRole;

    protected function setUp(): void
    {
        parent::setUp();

        $adminRole = Role::firstOrCreate(['name' => 'admin']);
        $this->staffRole = Role::firstOrCreate(['name' => 'staff']);
        
        $this->admin = User::create([
            'first_name' => 'Admin',
            'last_name' => 'User',
            'email' => 'admin@test.com',
            'username' => 'admin',
            'password' => bcrypt('password'),
            'role_id' => $adminRole->id,
            'is_active' => true,
        ]);
    }

    public function test_admin_can_create_staff_account(): void
    {
        $payload = [
            'first_name' => 'Jane',
            'last_name' => 'Smith',
            'gender' => 'female',
            'address' => '123 Test St',
            'contact_number' => '09123456789',
            'role' => 'staff',
            'username' => 'janesmith',
            'password' => 'password123',
            'password_confirmation' => 'password123',
        ];

        $response = $this->actingAs($this->admin)->postJson('/api/v1/admin/staff', $payload);

        $response->assertStatus(201)
            ->assertJson(['message' => 'Staff account successfully created.']);

        $this->assertDatabaseHas('users', [
            'username' => 'janesmith',
            'first_name' => 'Jane',
            'last_name' => 'Smith',
            'role_id' => $this->staffRole->id,
            'email' => 'janesmith@system.staff',
            'is_active' => 1,
        ]);

        $user = User::where('username', 'janesmith')->first();

        $this->assertDatabaseHas('staff_records', [
            'user_id' => $user->id,
            'first_name' => 'Jane',
            'last_name' => 'Smith',
            'contact_number' => '09123456789',
        ]);
    }

    public function test_staff_creation_fails_with_invalid_data(): void
    {
        $payload = [
            // Missing required fields
            'username' => 'testuser',
        ];

        $response = $this->actingAs($this->admin)->postJson('/api/v1/admin/staff', $payload);

        $response->assertStatus(422)
            ->assertJsonValidationErrors(['first_name', 'last_name', 'gender', 'role', 'password']);
    }

    public function test_staff_creation_fails_with_mismatched_passwords(): void
    {
        $payload = [
            'first_name' => 'Jane',
            'last_name' => 'Smith',
            'gender' => 'female',
            'contact_number' => '09123456789',
            'role' => 'staff',
            'username' => 'janesmith2',
            'password' => 'password123',
            'password_confirmation' => 'differentpassword',
        ];

        $response = $this->actingAs($this->admin)->postJson('/api/v1/admin/staff', $payload);

        $response->assertStatus(422)
            ->assertJsonValidationErrors(['password']);
    }

    public function test_staff_creation_fails_with_duplicate_username(): void
    {
        User::create([
            'first_name' => 'Existing',
            'last_name' => 'User',
            'email' => 'existing@test.com',
            'password' => bcrypt('password'),
            'username' => 'existinguser',
            'role_id' => $this->staffRole->id,
            'is_active' => true,
        ]);

        $payload = [
            'first_name' => 'Jane',
            'last_name' => 'Smith',
            'gender' => 'female',
            'contact_number' => '09123456789',
            'role' => 'staff',
            'username' => 'existinguser',
            'password' => 'password123',
            'password_confirmation' => 'password123',
        ];

        $response = $this->actingAs($this->admin)->postJson('/api/v1/admin/staff', $payload);

        $response->assertStatus(422)
            ->assertJsonValidationErrors(['username']);
    }

    public function test_admin_can_fetch_paginated_staff_listing(): void
    {
        $internRole = Role::firstOrCreate(['name' => 'intern']);

        $staffOne = User::create([
            'first_name' => 'Staff',
            'last_name' => 'One',
            'email' => 'staff-one@test.com',
            'username' => 'staffone',
            'password' => bcrypt('password'),
            'role_id' => $this->staffRole->id,
            'phone_number' => '09123456780',
            'gender' => 'female',
            'is_active' => true,
        ]);
        $staffTwo = User::create([
            'first_name' => 'Staff',
            'last_name' => 'Two',
            'email' => 'staff-two@test.com',
            'username' => 'stafftwo',
            'password' => bcrypt('password'),
            'role_id' => $this->staffRole->id,
            'phone_number' => '09123456781',
            'gender' => 'male',
            'is_active' => true,
        ]);
        $intern = User::create([
            'first_name' => 'Intern',
            'last_name' => 'User',
            'email' => 'intern@test.com',
            'username' => 'internuser',
            'password' => bcrypt('password'),
            'role_id' => $internRole->id,
            'phone_number' => '09123456782',
            'gender' => 'other',
            'is_active' => true,
        ]);
        $inactiveStaff = User::create([
            'first_name' => 'Inactive',
            'last_name' => 'Staff',
            'email' => 'inactive-staff@test.com',
            'username' => 'inactivestaff',
            'password' => bcrypt('password'),
            'role_id' => $this->staffRole->id,
            'phone_number' => '09123456783',
            'gender' => 'female',
            'is_active' => false,
        ]);

        StaffRecord::syncFromUser($staffOne);
        StaffRecord::syncFromUser($staffTwo);
        StaffRecord::syncFromUser($intern);
        StaffRecord::syncFromUser($inactiveStaff);

        $response = $this->actingAs($this->admin)->getJson('/api/v1/admin/staff?page=1&per_page=2');

        $response->assertOk()
            ->assertJsonCount(2, 'data')
            ->assertJsonPath('meta.current_page', 1)
            ->assertJsonPath('meta.per_page', 2)
            ->assertJsonPath('meta.total', 3)
            ->assertJsonPath('meta.has_more_pages', true);
    }
}
