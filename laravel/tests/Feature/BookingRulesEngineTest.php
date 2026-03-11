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

class BookingRulesEngineTest extends TestCase
{
    use RefreshDatabase;

    public function test_online_booking_rejects_sunday_booking(): void
    {
        $patient = $this->createUserWithRole('Patient');
        $service = $this->createService();
        Sanctum::actingAs($patient);

        $response = $this->postJson('/api/v1/patient/appointments', [
            'service_id' => $service->id,
            'appointment_date' => now()->next('Sunday')->format('Y-m-d'),
            'time_slot' => '09:00',
        ]);

        $response->assertStatus(422)
            ->assertJsonValidationErrors(['appointment_date'])
            ->assertJsonPath('errors.appointment_date.0', 'Sunday bookings are not allowed.');
    }

    public function test_walk_in_booking_rejects_past_date(): void
    {
        $staff = $this->createUserWithRole('Staff');
        $patient = $this->createUserWithRole('Patient');
        $service = $this->createService();
        Sanctum::actingAs($staff);

        $response = $this->postJson('/api/v1/admin/appointments', [
            'patient_id' => $patient->id,
            'service_type' => $service->name,
            'appointment_date' => now()->subDay()->format('Y-m-d'),
            'appointment_time' => '09:00',
        ]);

        $response->assertStatus(422)
            ->assertJsonValidationErrors(['appointment_date'])
            ->assertJsonPath('errors.appointment_date.0', 'Past dates are not allowed for bookings.');
    }

    public function test_follow_up_booking_rejects_invalid_time_window(): void
    {
        $staff = $this->createUserWithRole('Staff');
        $patient = $this->createUserWithRole('Patient');
        $service = $this->createService();
        Sanctum::actingAs($staff);

        $response = $this->postJson('/api/v1/admin/appointments/follow-up', [
            'patient_id' => $patient->id,
            'service_id' => $service->id,
            'appointment_date' => now()->next('Monday')->format('Y-m-d'),
            'time_slot' => '07:00',
        ]);

        $response->assertStatus(422)
            ->assertJsonValidationErrors(['time_slot'])
            ->assertJsonPath('errors.time_slot.0', 'Booking time must be between 07:30 AM and 6:00 PM.');
    }

    public function test_online_booking_accepts_valid_payload(): void
    {
        $patient = $this->createUserWithRole('Patient');
        $service = $this->createService();
        Sanctum::actingAs($patient);

        $response = $this->postJson('/api/v1/patient/appointments', [
            'service_id' => $service->id,
            'appointment_date' => now()->next('Monday')->format('Y-m-d'),
            'time_slot' => '09:30',
        ]);

        $response->assertCreated()
            ->assertJsonPath('message', 'Online booking created successfully.')
            ->assertJsonPath('appointment.patient_id', $patient->id)
            ->assertJsonStructure(['appointment' => ['service_type']]);
    }

    public function test_walk_in_booking_accepts_valid_payload(): void
    {
        $staff = $this->createUserWithRole('Staff');
        $patient = $this->createUserWithRole('Patient');
        $service = $this->createService();
        Sanctum::actingAs($staff);

        $response = $this->postJson('/api/v1/admin/appointments', [
            'patient_id' => $patient->id,
            'service_type' => $service->name,
            'appointment_date' => now()->next('Tuesday')->format('Y-m-d'),
            'appointment_time' => '10:00',
        ]);

        $response->assertCreated()
            ->assertJsonPath('message', 'Appointment created successfully.')
            ->assertJsonPath('appointment.patient_id', $patient->id)
            ->assertJsonStructure(['appointment' => ['service_type']]);
    }

    public function test_follow_up_booking_accepts_valid_payload(): void
    {
        $staff = $this->createUserWithRole('Staff');
        $patient = $this->createUserWithRole('Patient');
        $service = $this->createService();
        Sanctum::actingAs($staff);

        $response = $this->postJson('/api/v1/admin/appointments/follow-up', [
            'patient_id' => $patient->id,
            'service_id' => $service->id,
            'appointment_date' => now()->next('Wednesday')->format('Y-m-d'),
            'time_slot' => '10:30',
        ]);

        $response->assertCreated()
            ->assertJsonPath('message', 'Follow-up booking created successfully.')
            ->assertJsonPath('appointment.patient_id', $patient->id)
            ->assertJsonStructure(['appointment' => ['service_type']]);
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
            'name' => 'Test Service',
            'description' => 'Booking rules test service.',
            'is_active' => true,
        ]);
    }
}
