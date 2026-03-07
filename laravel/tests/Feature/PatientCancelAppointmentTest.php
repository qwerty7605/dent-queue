<?php

namespace Tests\Feature;

use App\Models\Appointment;
use App\Models\Role;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Str;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class PatientCancelAppointmentTest extends TestCase
{
    use RefreshDatabase;

    public function test_patient_can_cancel_pending_appointment_and_audit_log_is_recorded(): void
    {
        $patient = $this->createUserWithRole('Patient');
        $appointment = $this->createAppointment($patient->id, 'pending');
        Log::spy();
        Sanctum::actingAs($patient);

        $response = $this->patchJson('/api/v1/patient/appointments/' . $appointment->id . '/cancel');

        $response->assertOk()
            ->assertJsonPath('message', 'Appointment cancelled successfully.')
            ->assertJsonPath('appointment.status', 'Cancelled');

        $this->assertDatabaseHas('appointments', [
            'id' => $appointment->id,
            'status' => 'cancelled',
        ]);

        Log::shouldHaveReceived('info')
            ->once()
            ->withArgs(function (string $message, array $context) use ($appointment, $patient): bool {
                return $message === 'appointment.cancelled.by_patient'
                    && (int) ($context['appointment_id'] ?? 0) === (int) $appointment->id
                    && (int) ($context['patient_id'] ?? 0) === (int) $patient->id
                    && ($context['previous_status'] ?? null) === 'pending'
                    && ($context['new_status'] ?? null) === 'cancelled'
                    && is_string($context['occurred_at'] ?? null);
            });
    }

    public function test_patient_can_cancel_approved_appointment_and_audit_log_is_recorded(): void
    {
        $patient = $this->createUserWithRole('Patient');
        $appointment = $this->createAppointment($patient->id, 'confirmed');
        Log::spy();
        Sanctum::actingAs($patient);

        $response = $this->patchJson('/api/v1/patient/appointments/' . $appointment->id . '/cancel');

        $response->assertOk()
            ->assertJsonPath('appointment.status', 'Cancelled');

        $this->assertDatabaseHas('appointments', [
            'id' => $appointment->id,
            'status' => 'cancelled',
        ]);

        Log::shouldHaveReceived('info')
            ->once()
            ->withArgs(function (string $message, array $context) use ($appointment, $patient): bool {
                return $message === 'appointment.cancelled.by_patient'
                    && (int) ($context['appointment_id'] ?? 0) === (int) $appointment->id
                    && (int) ($context['patient_id'] ?? 0) === (int) $patient->id
                    && ($context['previous_status'] ?? null) === 'confirmed'
                    && ($context['new_status'] ?? null) === 'cancelled';
            });
    }

    public function test_patient_cannot_cancel_completed_appointment(): void
    {
        $patient = $this->createUserWithRole('Patient');
        $appointment = $this->createAppointment($patient->id, 'completed');
        Sanctum::actingAs($patient);

        $response = $this->patchJson('/api/v1/patient/appointments/' . $appointment->id . '/cancel');

        $response->assertStatus(422)
            ->assertJsonValidationErrors(['status'])
            ->assertJsonPath('errors.status.0', 'Only pending or approved appointments can be cancelled.');

        $this->assertDatabaseHas('appointments', [
            'id' => $appointment->id,
            'status' => 'completed',
        ]);
    }

    public function test_patient_cannot_cancel_appointment_owned_by_another_patient(): void
    {
        $patient = $this->createUserWithRole('Patient');
        $otherPatient = $this->createUserWithRole('Patient');
        $appointment = $this->createAppointment($otherPatient->id, 'pending');
        Sanctum::actingAs($patient);

        $response = $this->patchJson('/api/v1/patient/appointments/' . $appointment->id . '/cancel');

        $response->assertStatus(403)
            ->assertJsonPath('message', 'Unauthorized. You can only cancel your own appointments.');

        $this->assertDatabaseHas('appointments', [
            'id' => $appointment->id,
            'status' => 'pending',
        ]);
    }

    public function test_patient_cannot_cancel_appointment_that_is_already_cancelled(): void
    {
        $patient = $this->createUserWithRole('Patient');
        $appointment = $this->createAppointment($patient->id, 'cancelled');
        Sanctum::actingAs($patient);

        $response = $this->patchJson('/api/v1/patient/appointments/' . $appointment->id . '/cancel');

        $response->assertStatus(422)
            ->assertJsonValidationErrors(['status'])
            ->assertJsonPath('errors.status.0', 'Only pending or approved appointments can be cancelled.');

        $this->assertDatabaseHas('appointments', [
            'id' => $appointment->id,
            'status' => 'cancelled',
        ]);
    }

    private function createAppointment(int $patientId, string $status): Appointment
    {
        return Appointment::create([
            'patient_id' => $patientId,
            'service_id' => 1,
            'appointment_date' => now()->next('Monday')->format('Y-m-d'),
            'time_slot' => '09:00',
            'status' => $status,
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
