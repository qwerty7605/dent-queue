<?php

namespace Tests\Feature;

use App\Models\Role;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Str;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class PatientProfileUpdateApiTest extends TestCase
{
    use RefreshDatabase;

    public function test_patient_can_update_own_profile(): void
    {
        $patient = $this->createUserWithRole('Patient');
        Sanctum::actingAs($patient);

        $response = $this->patchJson('/api/v1/patient/profile/' . $patient->id, [
            'first_name' => 'Aldritch',
            'middle_name' => 'Sandal',
            'last_name' => 'Delapena',
            'birthdate' => '2020-08-13',
            'address' => 'Tabango',
            'gender' => 'Male',
            'contact_number' => '09169014483',
        ]);

        $response->assertOk()
            ->assertJsonPath('message', 'Profile updated successfully.')
            ->assertJsonPath('user.id', $patient->id)
            ->assertJsonPath('user.first_name', 'Aldritch')
            ->assertJsonPath('user.middle_name', 'Sandal')
            ->assertJsonPath('user.last_name', 'Delapena')
            ->assertJsonPath('user.location', 'Tabango')
            ->assertJsonPath('user.gender', 'male')
            ->assertJsonPath('user.phone_number', '09169014483');

        $this->assertStringStartsWith(
            '2020-08-13',
            (string) data_get($response->json(), 'user.birthdate')
        );

        $this->assertDatabaseHas('users', [
            'id' => $patient->id,
            'first_name' => 'Aldritch',
            'middle_name' => 'Sandal',
            'last_name' => 'Delapena',
            'location' => 'Tabango',
            'gender' => 'male',
            'phone_number' => '09169014483',
        ]);

        $patient->refresh();
        $this->assertStringStartsWith('2020-08-13', (string) $patient->birthdate);
    }

    public function test_profile_update_rejects_future_birthdate(): void
    {
        $patient = $this->createUserWithRole('Patient');
        Sanctum::actingAs($patient);

        $response = $this->patchJson('/api/v1/patient/profile/' . $patient->id, [
            'birthdate' => now()->addDay()->format('Y-m-d'),
        ]);

        $response->assertStatus(422)
            ->assertJsonValidationErrors(['birthdate'])
            ->assertJsonPath('errors.birthdate.0', 'Birthdate cannot be in the future.');
    }

    public function test_profile_update_rejects_invalid_contact_number_format(): void
    {
        $patient = $this->createUserWithRole('Patient');
        Sanctum::actingAs($patient);

        $response = $this->patchJson('/api/v1/patient/profile/' . $patient->id, [
            'contact_number' => '0912345678',
        ]);

        $response->assertStatus(422)
            ->assertJsonValidationErrors(['contact_number'])
            ->assertJsonPath('errors.contact_number.0', 'Contact number must be a valid 11-digit mobile number starting with 09.');
    }

    public function test_patient_cannot_update_another_patients_profile(): void
    {
        $actingPatient = $this->createUserWithRole('Patient');
        $otherPatient = $this->createUserWithRole('Patient');
        Sanctum::actingAs($actingPatient);

        $response = $this->patchJson('/api/v1/patient/profile/' . $otherPatient->id, [
            'first_name' => 'Hacker',
        ]);

        $response->assertForbidden()
            ->assertJsonPath('message', 'Unauthorized to update this profile.');

        $this->assertDatabaseMissing('users', [
            'id' => $otherPatient->id,
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
