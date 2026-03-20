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
            'username' => 'wayneadmin',
            'email' => 'wayne@example.com',
        ]);

        $response->assertOk()
            ->assertJsonPath('message', 'Profile updated successfully.')
            ->assertJsonPath('user.first_name', 'Wayne')
            ->assertJsonPath('user.last_name', 'Admin')
            ->assertJsonPath('user.username', 'wayneadmin')
            ->assertJsonPath('user.email', 'wayne@example.com');

        $this->assertDatabaseHas('users', [
            'id' => $admin->id,
            'first_name' => 'Wayne',
            'last_name' => 'Admin',
            'username' => 'wayneadmin',
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
