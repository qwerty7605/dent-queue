<?php

namespace Tests\Feature;

use App\Models\Appointment;
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

    public function test_walk_in_booking_creates_patient_record_without_creating_a_user_account(): void
    {
        $staff = $this->createUserWithRole('Staff');
        $service = $this->createService();
        Sanctum::actingAs($staff);

        $usersBefore = User::count();
        $appointmentDate = now()->next('Monday')->format('Y-m-d');

        $response = $this->postJson('/api/v1/admin/appointments/walk-in', [
            'first_name' => 'Jane',
            'middle_name' => 'Quinn',
            'surname' => 'Doe',
            'address' => '123 Walkin St.',
            'gender' => 'Female',
            'contact_number' => '09123456789',
            'service_type' => $service->name,
            'appointment_date' => $appointmentDate,
            'appointment_time' => '10:00',
        ]);

        $response->assertCreated()
            ->assertJsonPath('message', 'Walk-in booking created successfully.')
            ->assertJsonPath('patient_record.user_id', null)
            ->assertJsonPath('patient_record.first_name', 'Jane')
            ->assertJsonPath('patient_record.middle_name', 'Quinn')
            ->assertJsonPath('patient_record.last_name', 'Doe')
            ->assertJsonPath('patient_record.birthdate', null)
            ->assertJsonPath('appointment.appointment_date', $appointmentDate)
            ->assertJsonPath('appointment.appointment_time', '10:00');

        $patientRecordId = (int) data_get($response->json(), 'patient_record.id');
        $generatedPatientId = data_get($response->json(), 'patient_record.patient_id');

        $this->assertGreaterThan(0, $patientRecordId);
        $this->assertNotEmpty($generatedPatientId);
        $this->assertSame($usersBefore, User::count());

        $this->assertDatabaseHas('patient_records', [
            'id' => $patientRecordId,
            'patient_id' => $generatedPatientId,
            'user_id' => null,
            'first_name' => 'Jane',
            'middle_name' => 'Quinn',
            'last_name' => 'Doe',
            'gender' => 'female',
            'address' => '123 Walkin St.',
            'contact_number' => '09123456789',
            'birthdate' => null,
        ]);

        $this->assertDatabaseHas('appointments', [
            'patient_id' => $patientRecordId,
            'service_id' => $service->id,
            'appointment_date' => $appointmentDate,
            'time_slot' => '10:00',
            'status' => 'pending',
        ]);

        $appointment = Appointment::query()->where('patient_id', $patientRecordId)->first();
        $this->assertNotNull($appointment);
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
