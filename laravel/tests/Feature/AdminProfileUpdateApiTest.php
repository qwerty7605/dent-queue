<?php

namespace Tests\Feature;

use App\Models\Role;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Str;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class AdminProfileUpdateApiTest extends TestCase
{
    use RefreshDatabase;

    public function test_admin_can_update_own_profile(): void
    {
        $admin = $this->createUserWithRole('Admin');
        Sanctum::actingAs($admin);

        $response = $this->putJson('/api/v1/admin/profile', [
            'first_name' => 'Wayne',
            'last_name' => 'Admin',
            'email' => 'wayne@example.com',
        ]);

        $response->assertOk()
            ->assertJsonPath('message', 'Profile updated successfully.')
            ->assertJsonPath('user.first_name', 'Wayne')
            ->assertJsonPath('user.last_name', 'Admin')
            ->assertJsonPath('user.username', $admin->username)
            ->assertJsonPath('user.email', 'wayne@example.com');

        $this->assertDatabaseHas('users', [
            'id' => $admin->id,
            'first_name' => 'Wayne',
            'last_name' => 'Admin',
            'username' => $admin->username,
        ]);
    }

    public function test_admin_username_change_requires_current_password(): void
    {
        $admin = $this->createUserWithRole('Admin');
        Sanctum::actingAs($admin);

        $response = $this->putJson('/api/v1/admin/profile', [
            'username' => 'secureadmin',
        ]);

        $response->assertStatus(422)
            ->assertJsonValidationErrors(['current_password']);

        $this->assertDatabaseHas('users', [
            'id' => $admin->id,
            'username' => $admin->username,
        ]);
    }

    public function test_admin_username_change_rejects_wrong_current_password(): void
    {
        $admin = $this->createUserWithRole('Admin');
        Sanctum::actingAs($admin);

        $response = $this->putJson('/api/v1/admin/profile', [
            'username' => 'secureadmin',
            'current_password' => 'wrong-password',
        ]);

        $response->assertStatus(422)
            ->assertJsonValidationErrors(['current_password']);

        $this->assertDatabaseHas('users', [
            'id' => $admin->id,
            'username' => $admin->username,
        ]);
    }

    public function test_admin_can_change_username_with_current_password_only(): void
    {
        $admin = $this->createUserWithRole('Admin');
        Sanctum::actingAs($admin);

        $response = $this->putJson('/api/v1/admin/profile', [
            'username' => 'secureadmin',
            'current_password' => 'password123',
        ]);

        $response->assertOk()
            ->assertJsonPath('message', 'Profile updated successfully.')
            ->assertJsonPath('user.username', 'secureadmin')
            ->assertJsonPath('user.first_name', 'Admin')
            ->assertJsonPath('user.last_name', 'User');

        $this->assertDatabaseHas('users', [
            'id' => $admin->id,
            'username' => 'secureadmin',
            'first_name' => 'Admin',
            'last_name' => 'User',
        ]);
    }

    public function test_admin_username_change_rejects_duplicate_username(): void
    {
        $admin = $this->createUserWithRole('Admin');
        $existingUser = $this->createUserWithRole('Admin');
        Sanctum::actingAs($admin);

        $response = $this->putJson('/api/v1/admin/profile', [
            'username' => $existingUser->username,
            'current_password' => 'password123',
        ]);

        $response->assertStatus(422)
            ->assertJsonValidationErrors(['username']);

        $this->assertDatabaseHas('users', [
            'id' => $admin->id,
            'username' => $admin->username,
        ]);
    }

    public function test_admin_can_update_password(): void
    {
        $admin = $this->createUserWithRole('Admin');
        Sanctum::actingAs($admin);

        $response = $this->putJson('/api/v1/admin/profile', [
            'password' => 'newpassword123',
            'password_confirmation' => 'newpassword123',
        ]);

        $response->assertOk()
            ->assertJsonPath('message', 'Profile updated successfully.');

        $admin->refresh();
        $this->assertTrue(Hash::check('newpassword123', $admin->password));
    }

    private function createUserWithRole(string $roleName): User
    {
        $role = Role::firstOrCreate(['name' => $roleName]);
        $suffix = Str::lower($roleName) . '_' . Str::lower(Str::random(8));

        return User::create([
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
    }
}
