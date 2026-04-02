<?php

namespace Tests\Feature;

use App\Models\Role;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Hash;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class InternRoleAccessTest extends TestCase
{
    use RefreshDatabase;

    public function test_role_seeder_creates_intern_role(): void
    {
        $this->seed(\Database\Seeders\RoleSeeder::class);

        $this->assertDatabaseHas('roles', [
            'name' => 'Intern',
        ]);
    }

    public function test_intern_can_log_in_and_role_is_returned(): void
    {
        $intern = $this->createUserWithRole('Intern');

        $response = $this->postJson('/api/v1/auth/login', [
            'username' => $intern->username,
            'password' => 'password123',
        ]);

        $response->assertOk()
            ->assertJsonPath('user.id', $intern->id)
            ->assertJsonPath('user.role.name', 'Intern');
    }

    public function test_authenticated_intern_user_endpoint_returns_intern_role(): void
    {
        $intern = $this->createUserWithRole('Intern');

        Sanctum::actingAs($intern);

        $this->getJson('/api/v1/user')
            ->assertOk()
            ->assertJsonPath('id', $intern->id)
            ->assertJsonPath('role.name', 'Intern');
    }

    public function test_intern_is_forbidden_from_existing_patient_staff_and_admin_route_groups(): void
    {
        $intern = $this->createUserWithRole('Intern');

        Sanctum::actingAs($intern);

        $endpoints = [
            ['method' => 'getJson', 'uri' => '/api/v1/admin/patients'],
            ['method' => 'postJson', 'uri' => '/api/v1/admin/appointments', 'payload' => []],
            ['method' => 'postJson', 'uri' => '/api/v1/patient/appointments', 'payload' => []],
            ['method' => 'patchJson', 'uri' => '/api/v1/staff/profile/999', 'payload' => []],
        ];

        foreach ($endpoints as $endpoint) {
            $method = $endpoint['method'];
            $response = $this->{$method}($endpoint['uri'], $endpoint['payload'] ?? []);

            $response->assertForbidden()
                ->assertJsonPath('message', 'You do not have permission to perform this action.');
        }
    }

    private function createUserWithRole(string $roleName): User
    {
        $role = Role::firstOrCreate(['name' => $roleName]);

        return User::create([
            'first_name' => $roleName,
            'last_name' => 'User',
            'username' => strtolower($roleName) . '_tester',
            'email' => strtolower($roleName) . '@example.com',
            'password' => Hash::make('password123'),
            'role_id' => $role->id,
            'is_active' => true,
        ]);
    }
}
