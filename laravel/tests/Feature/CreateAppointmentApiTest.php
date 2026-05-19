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

class CreateAppointmentApiTest extends TestCase
{
    use RefreshDatabase;

    public function test_create_appointment_validates_required_fields(): void
    {
        $staff = $this->createUserWithRole('Staff');
        Sanctum::actingAs($staff);

        $response = $this->postJson('/api/v1/admin/appointments', []);

        $response->assertStatus(422)
            ->assertJsonValidationErrors([
                'patient_id',
                'service_type',
                'appointment_date',
                'appointment_time',
            ]);
    }

    public function test_create_appointment_stores_pending_status_and_timestamp(): void
    {
        $staff = $this->createUserWithRole('Staff');
        $patient = $this->createUserWithRole('Patient');
        $service = $this->createService('Dental Check-up');
        Sanctum::actingAs($staff);

        $appointmentDate = now()->next('Monday')->format('Y-m-d');

        $response = $this->postJson('/api/v1/admin/appointments', [
            'patient_id' => $patient->id,
            'service_type' => $service->name,
            'appointment_date' => $appointmentDate,
            'appointment_time' => '09:30',
        ]);

        $response->assertCreated()
            ->assertJsonPath('message', 'Appointment created successfully.')
            ->assertJsonPath('appointment.patient_id', $patient->id)
            ->assertJsonPath('appointment.service_type', $service->name)
            ->assertJsonPath('appointment.appointment_date', $appointmentDate)
            ->assertJsonPath('appointment.appointment_time', '09:30')
            ->assertJsonPath('appointment.status', 'Approved')
            ->assertJsonStructure([
                'appointment' => ['timestamp_created'],
            ]);

        $this->assertNotNull(data_get($response->json(), 'appointment.timestamp_created'));

        $this->assertDatabaseHas('appointments', [
            'patient_id' => $patient->id,
            'service_id' => $service->id,
            'appointment_date' => $appointmentDate,
            'time_slot' => '09:30',
            'status' => 'confirmed',
        ]);

        $appointment = Appointment::query()->first();
        $this->assertNotNull($appointment?->created_at);
    }

    public function test_create_appointment_accepts_and_persists_multiple_services(): void
    {
        $staff = $this->createUserWithRole('Staff');
        $patient = $this->createUserWithRole('Patient');
        $checkup = $this->createService('Dental Check-up');
        $cleaning = $this->createService('Teeth Cleaning');
        Sanctum::actingAs($staff);

        $appointmentDate = now()->next('Tuesday')->format('Y-m-d');

        $response = $this->postJson('/api/v1/admin/appointments', [
            'patient_id' => $patient->patientRecord->id,
            'services' => [$checkup->id, $cleaning->id],
            'appointment_date' => $appointmentDate,
            'appointment_time' => '10:30',
        ]);

        $response->assertCreated()
            ->assertJsonPath('appointment.service_id', $checkup->id)
            ->assertJsonPath('appointment.service_ids', [$checkup->id, $cleaning->id])
            ->assertJsonPath('appointment.service_type', 'Dental Check-up, Teeth Cleaning')
            ->assertJsonPath('appointment.services.0.name', 'Dental Check-up')
            ->assertJsonPath('appointment.services.1.name', 'Teeth Cleaning');

        $appointment = Appointment::query()->firstOrFail();

        $this->assertDatabaseHas('appointments', [
            'id' => $appointment->id,
            'service_id' => $checkup->id,
        ]);
        $this->assertDatabaseHas('appointment_service', [
            'appointment_id' => $appointment->id,
            'service_id' => $checkup->id,
        ]);
        $this->assertDatabaseHas('appointment_service', [
            'appointment_id' => $appointment->id,
            'service_id' => $cleaning->id,
        ]);
    }

    public function test_patient_can_validate_available_booking_before_confirming(): void
    {
        $patient = $this->createUserWithRole('Patient');
        $service = $this->createService('Dental Check-up');
        Sanctum::actingAs($patient);

        $response = $this->postJson('/api/v1/patient/appointments/validate-booking', [
            'service_ids' => [$service->id],
            'appointment_date' => now()->next('Monday')->format('Y-m-d'),
            'appointment_time' => '09:30',
        ]);

        $response->assertOk()
            ->assertJsonPath('valid', true)
            ->assertJsonPath('message', 'Schedule is available.');
    }

    public function test_patient_booking_validation_blocks_duplicate_time_slot(): void
    {
        $patient = $this->createUserWithRole('Patient');
        $otherPatient = $this->createUserWithRole('Patient');
        $service = $this->createService('Dental Check-up');
        $appointmentDate = now()->next('Monday')->format('Y-m-d');

        Appointment::create([
            'patient_id' => $otherPatient->patientRecord->id,
            'service_id' => $service->id,
            'appointment_date' => $appointmentDate,
            'time_slot' => '09:30',
            'status' => 'pending',
        ]);

        Sanctum::actingAs($patient);

        $response = $this->postJson('/api/v1/patient/appointments/validate-booking', [
            'service_ids' => [$service->id],
            'appointment_date' => $appointmentDate,
            'appointment_time' => '09:30',
        ]);

        $response->assertOk()
            ->assertJsonPath('valid', false)
            ->assertJsonPath('message', 'This time slot is already booked. Please choose another time.');
    }

    public function test_patient_booking_validation_blocks_same_day_booking(): void
    {
        $patient = $this->createUserWithRole('Patient');
        $service = $this->createService('Dental Check-up');
        $appointmentDate = now()->next('Monday')->format('Y-m-d');

        Appointment::create([
            'patient_id' => $patient->patientRecord->id,
            'service_id' => $service->id,
            'appointment_date' => $appointmentDate,
            'time_slot' => '09:30',
            'status' => 'confirmed',
        ]);

        Sanctum::actingAs($patient);

        $response = $this->postJson('/api/v1/patient/appointments/validate-booking', [
            'service_ids' => [$service->id],
            'appointment_date' => $appointmentDate,
            'appointment_time' => '10:30',
        ]);

        $response->assertOk()
            ->assertJsonPath('valid', false)
            ->assertJsonPath('message', 'You already have an appointment scheduled on this day.');
    }

    public function test_patient_booking_validation_ignores_cancelled_appointments(): void
    {
        $patient = $this->createUserWithRole('Patient');
        $service = $this->createService('Dental Check-up');
        $appointmentDate = now()->next('Monday')->format('Y-m-d');

        Appointment::create([
            'patient_id' => $patient->patientRecord->id,
            'service_id' => $service->id,
            'appointment_date' => $appointmentDate,
            'time_slot' => '09:30',
            'status' => 'cancelled',
        ]);

        Sanctum::actingAs($patient);

        $response = $this->postJson('/api/v1/patient/appointments/validate-booking', [
            'service_ids' => [$service->id],
            'appointment_date' => $appointmentDate,
            'appointment_time' => '10:30',
        ]);

        $response->assertOk()
            ->assertJsonPath('valid', true)
            ->assertJsonPath('message', 'Schedule is available.');
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

    private function createService(string $name): Service
    {
        return Service::create([
            'name' => $name,
            'description' => 'Create appointment API test service.',
            'is_active' => true,
        ]);
    }
}
