<?php

namespace Tests\Feature;

use App\Models\Appointment;
use App\Models\Role;
use App\Models\Service;
use App\Models\User;
use App\Services\AppointmentService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Str;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class CancelledAppointmentRecycleBinTest extends TestCase
{
    use RefreshDatabase;

    public function test_cancelled_appointment_details_are_retained_in_recycle_bin(): void
    {
        $patient = $this->createUserWithRole('Patient');
        $appointment = $this->createAppointment(
            $patient->id,
            'pending',
            '2026-04-21',
            '14:30',
            'Follow-up consultation',
        );

        Sanctum::actingAs($patient);

        $this->patchJson('/api/v1/patient/appointments/' . $appointment->id . '/cancel')
            ->assertOk();

        $recycledAppointment = app(AppointmentService::class)->findRecycleBinAppointment(
            (int) $appointment->id,
        );

        $this->assertNotNull($recycledAppointment);
        $this->assertSame('cancelled', $recycledAppointment->status);
        $this->assertSame('2026-04-21', (string) $recycledAppointment->appointment_date);
        $this->assertSame('14:30', (string) $recycledAppointment->time_slot);
        $this->assertSame('Follow-up consultation', (string) $recycledAppointment->notes);
        $this->assertNotNull($recycledAppointment->deleted_at);
    }

    public function test_recycle_bin_query_returns_only_soft_deleted_cancelled_appointments(): void
    {
        $patient = $this->createUserWithRole('Patient');
        $cancelledAppointment = $this->createAppointment($patient->id, 'cancelled');
        $activePendingAppointment = $this->createAppointment($patient->id, 'pending', '2026-04-23', '10:30');
        $activeCompletedAppointment = $this->createAppointment($patient->id, 'completed', '2026-04-24', '11:30');

        $cancelledAppointment->delete();

        $recycledAppointments = app(AppointmentService::class)->getRecycleBinAppointments();

        $this->assertCount(1, $recycledAppointments);
        $this->assertSame((int) $cancelledAppointment->id, (int) $recycledAppointments->first()->id);
        $this->assertNotContains($activePendingAppointment->id, $recycledAppointments->pluck('id')->all());
        $this->assertNotContains($activeCompletedAppointment->id, $recycledAppointments->pluck('id')->all());
    }

    public function test_soft_deleted_cancelled_appointments_remain_available_to_reports(): void
    {
        $patient = $this->createUserWithRole('Patient');
        $admin = $this->createUserWithRole('Admin');
        $appointment = $this->createAppointment($patient->id, 'pending', '2026-04-25', '09:15');

        Sanctum::actingAs($patient);

        $this->patchJson('/api/v1/patient/appointments/' . $appointment->id . '/cancel')
            ->assertOk();

        Sanctum::actingAs($admin);

        $this->getJson('/api/v1/admin/reports/summary')
            ->assertOk()
            ->assertJsonPath('data.total_appointments', 1)
            ->assertJsonPath('data.cancelled_count', 1);
    }

    private function createAppointment(
        int $patientId,
        string $status,
        string $date = '2026-04-22',
        string $time = '09:00',
        ?string $notes = null,
    ): Appointment {
        $service = Service::firstOrCreate([
            'name' => 'Recycle Bin Test Service',
        ], [
            'description' => 'Recycle bin test service.',
            'is_active' => true,
        ]);

        return Appointment::create([
            'patient_id' => $patientId,
            'service_id' => $service->id,
            'appointment_date' => $date,
            'time_slot' => $time,
            'status' => $status,
            'notes' => $notes,
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
