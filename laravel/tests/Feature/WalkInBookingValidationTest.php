<?php

namespace Tests\Feature;

use App\Models\Role;
use App\Models\Service;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Str;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class WalkInBookingValidationTest extends TestCase
{
    use RefreshDatabase;

    public function test_walk_in_booking_rejects_sunday(): void
    {
        $staff = $this->createUserWithRole('Staff');
        $patientRole = Role::firstOrCreate(['name' => 'Patient']);
        $service = $this->createService();
        Sanctum::actingAs($staff);

        $response = $this->postJson('/api/v1/admin/appointments/walk-in', [
            'first_name' => 'John',
            'surname' => 'Doe',
            'address' => '123 Walkin St.',
            'gender' => 'Male',
            'contact_number' => '09123456789',
            'service_type' => $service->name,
            'appointment_date' => now()->next('Sunday')->format('Y-m-d'),
            'appointment_time' => '10:00',
        ]);

        $response->assertStatus(422)
            ->assertJsonValidationErrors(['appointment_date'])
            ->assertJsonPath('errors.appointment_date.0', 'Sunday bookings are not allowed.');
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

    private function createService(): Service
    {
        return Service::create([
            'name' => 'Dental Check-up',
            'description' => 'Booking rules test service.',
            'is_active' => true,
        ]);
    }
}
