<?php

namespace Tests\Feature;

use App\Models\Role;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Str;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class StaffProfileUpdateApiTest extends TestCase
{
    use RefreshDatabase;

    public function test_staff_can_update_own_profile(): void
    {
        $staff = $this->createUserWithRole('Staff');
        Sanctum::actingAs($staff);

        $response = $this->patchJson('/api/v1/staff/profile/' . $staff->id, [
            'first_name' => 'Dela',
            'middle_name' => 'Mae',
            'last_name' => 'Pena',
            'birthdate' => '1998-08-13',
            'address' => 'Ormoc City',
            'gender' => 'Female',
            'contact_number' => '09169014483',
        ]);

        $response->assertOk()
            ->assertJsonPath('message', 'Profile updated successfully.')
            ->assertJsonPath('user.id', $staff->id)
            ->assertJsonPath('user.first_name', 'Dela')
            ->assertJsonPath('user.middle_name', 'Mae')
            ->assertJsonPath('user.last_name', 'Pena')
            ->assertJsonPath('user.location', 'Ormoc City')
            ->assertJsonPath('user.gender', 'female')
            ->assertJsonPath('user.phone_number', '09169014483');

        $this->assertStringStartsWith(
            '1998-08-13',
            (string) data_get($response->json(), 'user.birthdate')
        );

        $this->assertDatabaseHas('users', [
            'id' => $staff->id,
            'first_name' => 'Dela',
            'middle_name' => 'Mae',
            'last_name' => 'Pena',
            'location' => 'Ormoc City',
            'gender' => 'female',
            'phone_number' => '09169014483',
        ]);
    }

    public function test_staff_profile_update_rejects_future_birthdate(): void
    {
        $staff = $this->createUserWithRole('Staff');
        Sanctum::actingAs($staff);

        $response = $this->patchJson('/api/v1/staff/profile/' . $staff->id, [
            'birthdate' => now()->addDay()->format('Y-m-d'),
        ]);

        $response->assertStatus(422)
            ->assertJsonValidationErrors(['birthdate'])
            ->assertJsonPath('errors.birthdate.0', 'Birthdate cannot be in the future.');
    }

    public function test_staff_profile_update_rejects_invalid_contact_number(): void
    {
        $staff = $this->createUserWithRole('Staff');
        Sanctum::actingAs($staff);

        $response = $this->patchJson('/api/v1/staff/profile/' . $staff->id, [
            'contact_number' => '12345',
        ]);

        $response->assertStatus(422)
            ->assertJsonValidationErrors(['contact_number'])
            ->assertJsonPath(
                'errors.contact_number.0',
                'Contact number must be a valid 11-digit mobile number.'
            );
    }

    public function test_staff_cannot_update_another_staff_profile(): void
    {
        $actingStaff = $this->createUserWithRole('Staff');
        $otherStaff = $this->createUserWithRole('Staff');
        Sanctum::actingAs($actingStaff);

        $response = $this->patchJson('/api/v1/staff/profile/' . $otherStaff->id, [
            'first_name' => 'Hacker',
        ]);

        $response->assertForbidden()
            ->assertJsonPath('message', 'Unauthorized to update this profile.');

        $this->assertDatabaseMissing('users', [
            'id' => $otherStaff->id,
            'first_name' => 'Hacker',
        ]);
    }

    private function createUserWithRole(string $roleName): User
    {
        $role = Role::firstOrCreate(['name' => $roleName]);
        $suffix = Str::lower($roleName) . '_' . Str::lower(Str::random(8));

        return User::create([
            'first_name' => $roleName,
            'middle_name' => null,
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
