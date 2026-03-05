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
        $service = $this->createService('General Consultation');
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
            ->assertJsonPath('appointment.status', 'Pending')
            ->assertJsonStructure([
                'appointment' => ['timestamp_created'],
            ]);

        $this->assertNotNull(data_get($response->json(), 'appointment.timestamp_created'));

        $this->assertDatabaseHas('appointments', [
            'patient_id' => $patient->id,
            'service_id' => $service->id,
            'appointment_date' => $appointmentDate,
            'time_slot' => '09:30',
            'status' => 'pending',
        ]);

        $appointment = Appointment::query()->first();
        $this->assertNotNull($appointment?->created_at);
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

