<?php

namespace Tests\Feature;

use App\Models\Appointment;
use App\Models\Role;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Str;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class AppointmentStatusTransitionTest extends TestCase
{
    use RefreshDatabase;

    public function test_pending_can_transition_to_approved(): void
    {
        $staff = $this->createUserWithRole('Staff');
        $patient = $this->createUserWithRole('Patient');
        $appointment = $this->createAppointment($patient->id, 'pending');
        Sanctum::actingAs($staff);

        $response = $this->patchJson('/api/v1/admin/appointments/' . $appointment->id . '/status', [
            'status' => 'approved',
        ]);

        $response->assertOk()
            ->assertJsonPath('message', 'Appointment status updated successfully.')
            ->assertJsonPath('appointment.status', 'Approved');

        $this->assertDatabaseHas('appointments', [
            'id' => $appointment->id,
            'status' => 'confirmed',
        ]);
    }

    public function test_pending_can_transition_to_cancelled(): void
    {
        $staff = $this->createUserWithRole('Staff');
        $patient = $this->createUserWithRole('Patient');
        $appointment = $this->createAppointment($patient->id, 'pending');
        Sanctum::actingAs($staff);

        $response = $this->patchJson('/api/v1/admin/appointments/' . $appointment->id . '/status', [
            'status' => 'cancelled',
        ]);

        $response->assertOk()
            ->assertJsonPath('appointment.status', 'Cancelled');

        $this->assertDatabaseHas('appointments', [
            'id' => $appointment->id,
            'status' => 'cancelled',
        ]);
        $this->assertSoftDeleted('appointments', [
            'id' => $appointment->id,
        ]);
    }

    public function test_pending_to_completed_transition_is_rejected(): void
    {
        $staff = $this->createUserWithRole('Staff');
        $patient = $this->createUserWithRole('Patient');
        $appointment = $this->createAppointment($patient->id, 'pending');
        Sanctum::actingAs($staff);

        $response = $this->patchJson('/api/v1/admin/appointments/' . $appointment->id . '/status', [
            'status' => 'completed',
        ]);

        $response->assertStatus(422)
            ->assertJsonValidationErrors(['status'])
            ->assertJsonPath('errors.status.0', 'Invalid status transition: pending -> completed.');

        $this->assertDatabaseHas('appointments', [
            'id' => $appointment->id,
            'status' => 'pending',
        ]);
    }

    public function test_approved_can_transition_to_completed(): void
    {
        $staff = $this->createUserWithRole('Staff');
        $patient = $this->createUserWithRole('Patient');
        $appointment = $this->createAppointment($patient->id, 'confirmed');
        Sanctum::actingAs($staff);

        $response = $this->patchJson('/api/v1/admin/appointments/' . $appointment->id . '/status', [
            'status' => 'completed',
        ]);

        $response->assertOk()
            ->assertJsonPath('appointment.status', 'Completed');

        $this->assertDatabaseHas('appointments', [
            'id' => $appointment->id,
            'status' => 'completed',
        ]);
    }

    public function test_approved_can_transition_to_cancelled(): void
    {
        $staff = $this->createUserWithRole('Staff');
        $patient = $this->createUserWithRole('Patient');
        $appointment = $this->createAppointment($patient->id, 'confirmed');
        Sanctum::actingAs($staff);

        $response = $this->patchJson('/api/v1/admin/appointments/' . $appointment->id . '/status', [
            'status' => 'cancelled',
        ]);

        $response->assertOk()
            ->assertJsonPath('appointment.status', 'Cancelled');

        $this->assertDatabaseHas('appointments', [
            'id' => $appointment->id,
            'status' => 'cancelled',
        ]);
        $this->assertSoftDeleted('appointments', [
            'id' => $appointment->id,
        ]);
    }

    public function test_completed_cannot_be_changed(): void
    {
        $staff = $this->createUserWithRole('Staff');
        $patient = $this->createUserWithRole('Patient');
        $appointment = $this->createAppointment($patient->id, 'completed');
        Sanctum::actingAs($staff);

        $response = $this->patchJson('/api/v1/admin/appointments/' . $appointment->id . '/status', [
            'status' => 'cancelled',
        ]);

        $response->assertStatus(422)
            ->assertJsonValidationErrors(['status'])
            ->assertJsonPath('errors.status.0', 'Invalid status transition: completed -> cancelled.');

        $this->assertDatabaseHas('appointments', [
            'id' => $appointment->id,
            'status' => 'completed',
        ]);
    }

    public function test_cancelled_cannot_be_changed(): void
    {
        $staff = $this->createUserWithRole('Staff');
        $patient = $this->createUserWithRole('Patient');
        $appointment = $this->createAppointment($patient->id, 'cancelled');
        Sanctum::actingAs($staff);

        $response = $this->patchJson('/api/v1/admin/appointments/' . $appointment->id . '/status', [
            'status' => 'approved',
        ]);

        $response->assertStatus(422)
            ->assertJsonValidationErrors(['status'])
            ->assertJsonPath('errors.status.0', 'Invalid status transition: cancelled -> approved.');

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
