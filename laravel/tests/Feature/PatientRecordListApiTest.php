<?php

namespace Tests\Feature;

use App\Models\PatientRecord;
use App\Models\Role;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Str;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class PatientRecordListApiTest extends TestCase
{
    use RefreshDatabase;

    public function test_staff_can_fetch_paginated_patient_records(): void
    {
        $staff = $this->createUserWithRole('Staff');
        $firstPatient = $this->createUserWithRole('Patient');
        $secondPatient = $this->createUserWithRole('Patient');

        PatientRecord::resolveForUser($firstPatient);
        PatientRecord::resolveForUser($secondPatient);

        Sanctum::actingAs($staff);

        $response = $this->getJson('/api/v1/admin/patients?page=1&per_page=1');

        $response->assertOk()
            ->assertJsonCount(1, 'data')
            ->assertJsonPath('meta.current_page', 1)
            ->assertJsonPath('meta.per_page', 1)
            ->assertJsonPath('meta.total', 2)
            ->assertJsonPath('meta.has_more_pages', true);

        $this->assertNotEmpty($response->json('data.0.patient_id'));
        $this->assertNotEmpty($response->json('data.0.full_name'));
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
