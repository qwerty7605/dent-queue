<?php

namespace Tests\Feature;

use App\Models\Role;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Hash;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class AuthControllerTest extends TestCase
{
    use RefreshDatabase;

    public function test_user_can_login_with_email(): void
    {
        $role = Role::create(['name' => 'Patient']);
        $user = User::create([
            'first_name' => 'John',
            'last_name' => 'Doe',
            'email' => 'john@example.com',
            'username' => 'johndoe',
            'password' => Hash::make('password123'),
            'role_id' => $role->id,
            'is_active' => true,
        ]);

        $response = $this->postJson('/api/v1/auth/login', [
            'email' => 'john@example.com',
            'password' => 'password123',
        ]);

        $response->assertOk()
            ->assertJsonStructure([
                'access_token',
                'user' => [
                    'id',
                    'email',
                    'role'
                ]
            ]);
    }

    public function test_user_can_login_with_username(): void
    {
        $role = Role::create(['name' => 'Patient']);
        $user = User::create([
            'first_name' => 'John',
            'last_name' => 'Doe',
            'email' => 'john@example.com',
            'username' => 'johndoe',
            'password' => Hash::make('password123'),
            'role_id' => $role->id,
            'is_active' => true,
        ]);

        $response = $this->postJson('/api/v1/auth/login', [
            'username' => 'johndoe',
            'password' => 'password123',
        ]);

        $response->assertOk()
            ->assertJsonPath('user.username', 'johndoe');
    }

    public function test_user_can_register(): void
    {
        Role::create(['name' => 'Patient']);

        $response = $this->postJson('/api/v1/auth/register', [
            'first_name' => 'Jane',
            'last_name' => 'Smith',
            'email' => 'jane@example.com',
            'username' => 'janesmith',
            'password' => 'password123',
            'password_confirmation' => 'password123',
            'phone_number' => '09123456789',
            'birthdate' => '1995-01-01',
            'gender' => 'female',
            'location' => 'Tester City'
        ]);

        $response->assertStatus(201)
            ->assertJsonPath('user.email', 'jane@example.com');

        $this->assertDatabaseHas('users', ['email' => 'jane@example.com']);
    }

    public function test_user_can_logout(): void
    {
        $role = Role::create(['name' => 'Patient']);
        $user = User::create([
            'first_name' => 'John',
            'last_name' => 'Doe',
            'email' => 'john@example.com',
            'username' => 'johndoe',
            'password' => Hash::make('password123'),
            'role_id' => $role->id,
            'is_active' => true,
        ]);

        Sanctum::actingAs($user);

        $response = $this->postJson('/api/v1/auth/logout');

        $response->assertOk()
            ->assertJsonPath('message', 'Successfully logged out');
    }

    public function test_deactivated_user_cannot_login(): void
    {
        $role = Role::create(['name' => 'Patient']);
        $user = User::create([
            'first_name' => 'Inactive',
            'last_name' => 'User',
            'email' => 'inactive@example.com',
            'username' => 'inactiveuser',
            'password' => Hash::make('password123'),
            'role_id' => $role->id,
            'is_active' => false,
        ]);

        $response = $this->postJson('/api/v1/auth/login', [
            'email' => 'inactive@example.com',
            'password' => 'password123',
        ]);

        $response->assertStatus(422)
            ->assertJsonValidationErrors(['is_active'])
            ->assertJsonPath('errors.is_active.0', 'Your account has been deactivated. Please contact administration.');
    }
}
