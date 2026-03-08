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

class AuditTrailTest extends TestCase
{
    use RefreshDatabase;

    public function test_staff_actions_are_logged_to_audit_channel(): void
    {
        Log::shouldReceive('channel')
            ->with('audit')
            ->andReturnSelf();

        Log::shouldReceive('info')
            ->once()
            ->with('appointment.status_updated', \Mockery::on(function ($data) {
                return $data['action'] === 'Approved' 
                    && isset($data['appointment_id'])
                    && isset($data['changed_by_user_id']);
            }));

        $staff = $this->createUserWithRole('Staff');
        $patient = $this->createUserWithRole('Patient');
        $appointment = $this->createAppointment($patient->id, 'pending');
        Sanctum::actingAs($staff);

        $this->patchJson('/api/v1/admin/appointments/' . $appointment->id . '/status', [
            'status' => 'approved',
        ]);
    }

    public function test_staff_cancellation_is_logged_to_audit_channel(): void
    {
        Log::shouldReceive('channel')
            ->with('audit')
            ->andReturnSelf();

        Log::shouldReceive('info')
            ->once()
            ->with('appointment.status_updated', \Mockery::on(function ($data) {
                return $data['action'] === 'Cancelled'
                    && isset($data['appointment_id'])
                    && isset($data['changed_by_user_id']);
            }));

        $staff = $this->createUserWithRole('Staff');
        $patient = $this->createUserWithRole('Patient');
        $appointment = $this->createAppointment($patient->id, 'confirmed');
        Sanctum::actingAs($staff);

        $this->patchJson('/api/v1/admin/appointments/' . $appointment->id . '/status', [
            'status' => 'cancelled',
        ]);
    }

    public function test_staff_completion_is_logged_to_audit_channel(): void
    {
        Log::shouldReceive('channel')
            ->with('audit')
            ->andReturnSelf();

        Log::shouldReceive('info')
            ->once()
            ->with('appointment.status_updated', \Mockery::on(function ($data) {
                return $data['action'] === 'Completed'
                    && isset($data['appointment_id'])
                    && isset($data['changed_by_user_id']);
            }));

        $staff = $this->createUserWithRole('Staff');
        $patient = $this->createUserWithRole('Patient');
        $appointment = $this->createAppointment($patient->id, 'confirmed');
        Sanctum::actingAs($staff);

        $this->patchJson('/api/v1/admin/appointments/' . $appointment->id . '/status', [
            'status' => 'completed',
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
