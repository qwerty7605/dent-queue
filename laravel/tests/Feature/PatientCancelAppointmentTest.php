<?php

namespace Tests\Feature;

use App\Models\Appointment;
use App\Models\PatientRecord;
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
        $this->assertSoftDeleted('appointments', [
            'id' => $appointment->id,
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
        $this->assertSoftDeleted('appointments', [
            'id' => $appointment->id,
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

    public function test_patient_can_cancel_appointment_when_patient_record_id_differs_from_user_id(): void
    {
        $patient = $this->createUserWithRole('Patient');
        $patientRecord = $this->reassignPatientRecord($patient, 9000000004321);
        $appointment = $this->createAppointment((int) $patientRecord->id, 'pending');
        Log::spy();
        Sanctum::actingAs($patient->fresh());

        $response = $this->patchJson('/api/v1/patient/appointments/' . $appointment->id . '/cancel');

        $response->assertOk()
            ->assertJsonPath('message', 'Appointment cancelled successfully.')
            ->assertJsonPath('appointment.patient_id', (int) $patientRecord->id)
            ->assertJsonPath('appointment.status', 'Cancelled');

        $this->assertDatabaseHas('appointments', [
            'id' => $appointment->id,
            'patient_id' => (int) $patientRecord->id,
            'status' => 'cancelled',
        ]);
        $this->assertSoftDeleted('appointments', [
            'id' => $appointment->id,
        ]);

        Log::shouldHaveReceived('info')
            ->once()
            ->withArgs(function (string $message, array $context) use ($appointment, $patientRecord): bool {
                return $message === 'appointment.cancelled.by_patient'
                    && (int) ($context['appointment_id'] ?? 0) === (int) $appointment->id
                    && (int) ($context['patient_id'] ?? 0) === (int) $patientRecord->id
                    && ($context['previous_status'] ?? null) === 'pending'
                    && ($context['new_status'] ?? null) === 'cancelled'
                    && is_string($context['occurred_at'] ?? null);
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

    public function test_cancelled_appointment_is_removed_from_patient_active_appointments_list(): void
    {
        $patient = $this->createUserWithRole('Patient');
        $appointment = $this->createAppointment($patient->id, 'pending');
        Sanctum::actingAs($patient);

        $this->patchJson('/api/v1/patient/appointments/' . $appointment->id . '/cancel')
            ->assertOk();

        $this->getJson('/api/v1/patient/appointments')
            ->assertOk()
            ->assertJsonCount(0, 'appointments');
    }

    public function test_patient_can_fetch_cancelled_appointment_details_after_cancelling(): void
    {
        $patient = $this->createUserWithRole('Patient');
        $appointment = $this->createAppointment($patient->id, 'pending');
        Sanctum::actingAs($patient);

        $this->patchJson('/api/v1/patient/appointments/' . $appointment->id . '/cancel')
            ->assertOk();

        $this->getJson('/api/v1/patient/appointments/' . $appointment->id)
            ->assertOk()
            ->assertJsonPath('appointment.id', (int) $appointment->id)
            ->assertJsonPath('appointment.status', 'Cancelled')
            ->assertJsonPath('appointment.recycle_bin.is_restorable', true);
    }

    public function test_patient_can_fetch_appointment_details_with_current_status_labels(): void
    {
        $patient = $this->createUserWithRole('Patient');
        $confirmedAppointment = $this->createAppointment($patient->id, 'confirmed');
        $completedAppointment = Appointment::create([
            'patient_id' => $patient->id,
            'service_id' => 1,
            'appointment_date' => now()->next('Tuesday')->format('Y-m-d'),
            'time_slot' => '10:00',
            'status' => 'completed',
        ]);
        Sanctum::actingAs($patient);

        $this->getJson('/api/v1/patient/appointments/' . $confirmedAppointment->id)
            ->assertOk()
            ->assertJsonPath('appointment.status', 'Approved');

        $this->getJson('/api/v1/patient/appointments/' . $completedAppointment->id)
            ->assertOk()
            ->assertJsonPath('appointment.status', 'Completed');
    }

    public function test_patient_can_reschedule_pending_appointment(): void
    {
        $patient = $this->createUserWithRole('Patient');
        $appointment = $this->createAppointment($patient->id, 'pending');
        Sanctum::actingAs($patient);

        $newDate = now()->next('Tuesday')->format('Y-m-d');

        $this->putJson('/api/v1/patient/appointments/' . $appointment->id, [
            'appointment_date' => $newDate,
            'time_slot' => '10:30',
            'notes' => 'Needs a later slot',
        ])->assertOk()
            ->assertJsonPath('message', 'Appointment rescheduled successfully.')
            ->assertJsonPath('appointment.appointment_date', $newDate)
            ->assertJsonPath('appointment.appointment_time', '10:30')
            ->assertJsonPath('appointment.notes', 'Needs a later slot');

        $this->assertDatabaseHas('appointments', [
            'id' => $appointment->id,
            'appointment_date' => $newDate,
            'time_slot' => '10:30',
            'notes' => 'Needs a later slot',
            'status' => 'pending',
        ]);
    }

    public function test_patient_cannot_reschedule_to_booked_time_slot(): void
    {
        $patient = $this->createUserWithRole('Patient');
        $otherPatient = $this->createUserWithRole('Patient');
        $date = now()->next('Tuesday')->format('Y-m-d');
        $appointment = $this->createAppointment($patient->id, 'pending');
        $this->createAppointment($otherPatient->id, 'confirmed')->update([
            'appointment_date' => $date,
            'time_slot' => '11:00',
        ]);
        Sanctum::actingAs($patient);

        $this->putJson('/api/v1/patient/appointments/' . $appointment->id, [
            'appointment_date' => $date,
            'time_slot' => '11:00',
        ])->assertStatus(422)
            ->assertJsonValidationErrors(['time_slot']);
    }

    public function test_patient_cannot_reschedule_completed_appointment(): void
    {
        $patient = $this->createUserWithRole('Patient');
        $appointment = $this->createAppointment($patient->id, 'completed');
        Sanctum::actingAs($patient);

        $this->putJson('/api/v1/patient/appointments/' . $appointment->id, [
            'appointment_date' => now()->next('Tuesday')->format('Y-m-d'),
            'time_slot' => '11:00',
        ])->assertStatus(422)
            ->assertJsonValidationErrors(['status'])
            ->assertJsonPath('errors.status.0', 'Only pending, approved, cancelled by doctor, or reschedule required appointments can be rescheduled.');
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

    private function reassignPatientRecord(User $patient, int $recordId): PatientRecord
    {
        $patient->patientRecord()->forceDelete();
        $patient->unsetRelation('patientRecord');

        return PatientRecord::create([
            'id' => $recordId,
            'user_id' => (int) $patient->id,
            'first_name' => (string) $patient->first_name,
            'middle_name' => $patient->middle_name,
            'last_name' => (string) $patient->last_name,
            'gender' => $patient->gender,
            'address' => $patient->location,
            'contact_number' => $patient->phone_number,
            'birthdate' => $patient->birthdate,
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
