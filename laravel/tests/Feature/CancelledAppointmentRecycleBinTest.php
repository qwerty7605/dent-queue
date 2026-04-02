<?php

namespace Tests\Feature;

use App\Models\Appointment;
use App\Models\Role;
use App\Models\Service;
use App\Models\User;
use App\Services\AppointmentService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Str;
use Illuminate\Validation\ValidationException;
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

    public function test_patient_recycle_bin_endpoint_returns_cancelled_soft_deleted_appointments(): void
    {
        $patient = $this->createUserWithRole('Patient');
        $otherPatient = $this->createUserWithRole('Patient');
        $cancelledAppointment = $this->createAppointment(
            $patient->id,
            'pending',
            '2026-04-23',
            '10:30',
            'Needs reschedule',
        );
        $activeAppointment = $this->createAppointment($patient->id, 'pending', '2026-04-24', '11:30');
        $otherPatientCancelledAppointment = $this->createAppointment(
            $otherPatient->id,
            'pending',
            '2026-04-25',
            '09:00',
            'Other patient cancelled booking',
        );

        Sanctum::actingAs($patient);

        $this->patchJson('/api/v1/patient/appointments/' . $cancelledAppointment->id . '/cancel')
            ->assertOk();

        Sanctum::actingAs($otherPatient);
        $this->patchJson('/api/v1/patient/appointments/' . $otherPatientCancelledAppointment->id . '/cancel')
            ->assertOk();

        Sanctum::actingAs($patient);

        $response = $this->getJson('/api/v1/patient/appointments/recycle-bin')
            ->assertOk()
            ->assertJsonCount(1, 'recycle_bin')
            ->assertJsonPath('recycle_bin.0.id', (int) $cancelledAppointment->id)
            ->assertJsonPath('recycle_bin.0.status', 'Cancelled')
            ->assertJsonPath('recycle_bin.0.notes', 'Needs reschedule');

        $recycleBinIds = array_map(
            fn (array $appointment): int => (int) ($appointment['id'] ?? 0),
            $response->json('recycle_bin', []),
        );

        $this->assertNotContains((int) $otherPatientCancelledAppointment->id, $recycleBinIds);

        $this->assertDatabaseHas('appointments', [
            'id' => $activeAppointment->id,
            'status' => 'pending',
            'deleted_at' => null,
        ]);
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

    public function test_cancel_response_exposes_recycle_bin_expiration_state(): void
    {
        $patient = $this->createUserWithRole('Patient');
        $appointment = $this->createAppointment($patient->id, 'pending', '2026-04-26', '10:00');
        $frozenNow = Carbon::parse('2026-03-30 09:10:00', 'UTC');

        Carbon::setTestNow($frozenNow);

        try {
            Sanctum::actingAs($patient);

            $response = $this->patchJson('/api/v1/patient/appointments/' . $appointment->id . '/cancel')
                ->assertOk()
                ->assertJsonPath('appointment.recycle_bin.deleted_at', $frozenNow->toIso8601String())
                ->assertJsonPath(
                    'appointment.recycle_bin.expires_at',
                    $frozenNow->copy()->addDays(7)->toIso8601String(),
                )
                ->assertJsonPath('appointment.recycle_bin.is_expired', false)
                ->assertJsonPath('appointment.recycle_bin.is_restorable', true)
                ->assertJsonPath('appointment.recycle_bin.restore_window_days', 7);

            $this->assertNotNull(data_get($response->json(), 'appointment.recycle_bin'));
        } finally {
            Carbon::setTestNow();
        }
    }

    public function test_expired_recycle_bin_appointments_are_detected_and_cannot_be_restored(): void
    {
        $patient = $this->createUserWithRole('Patient');
        $appointment = $this->createAppointment($patient->id, 'cancelled', '2026-04-27', '13:00');
        $expiredNow = Carbon::parse('2026-03-30 12:00:00', 'UTC');

        $appointment->delete();

        Appointment::withTrashed()
            ->whereKey($appointment->id)
            ->update([
                'deleted_at' => $expiredNow->copy()->subDays(8),
            ]);

        $recycledAppointment = app(AppointmentService::class)->findRecycleBinAppointment((int) $appointment->id);

        $this->assertNotNull($recycledAppointment);
        $this->assertTrue(
            app(AppointmentService::class)->isRecycleBinAppointmentExpired($recycledAppointment, $expiredNow),
        );
        $this->assertFalse(
            app(AppointmentService::class)->canRestoreRecycleBinAppointment($recycledAppointment, $expiredNow),
        );
        $this->assertSame(
            $expiredNow->copy()->subDay()->toIso8601String(),
            data_get(
                app(AppointmentService::class)->buildRecycleBinState($recycledAppointment, $expiredNow),
                'expires_at',
            ),
        );

        $this->expectException(ValidationException::class);
        $this->expectExceptionMessage('This cancelled appointment is no longer eligible for restore.');

        app(AppointmentService::class)->assertRecycleBinAppointmentCanBeRestored(
            $recycledAppointment,
            $expiredNow,
        );
    }

    public function test_recent_recycle_bin_appointments_remain_restorable_inside_the_restore_window(): void
    {
        $patient = $this->createUserWithRole('Patient');
        $appointment = $this->createAppointment($patient->id, 'cancelled', '2026-04-28', '15:00');
        $referenceTime = Carbon::parse('2026-03-30 12:00:00', 'UTC');

        $appointment->delete();

        Appointment::withTrashed()
            ->whereKey($appointment->id)
            ->update([
                'deleted_at' => $referenceTime->copy()->subDays(2),
            ]);

        $recycledAppointment = app(AppointmentService::class)->findRecycleBinAppointment((int) $appointment->id);

        $this->assertNotNull($recycledAppointment);
        $this->assertFalse(
            app(AppointmentService::class)->isRecycleBinAppointmentExpired($recycledAppointment, $referenceTime),
        );
        $this->assertTrue(
            app(AppointmentService::class)->canRestoreRecycleBinAppointment($recycledAppointment, $referenceTime),
        );

        app(AppointmentService::class)->assertRecycleBinAppointmentCanBeRestored(
            $recycledAppointment,
            $referenceTime,
        );

        $this->assertTrue(
            data_get(
                app(AppointmentService::class)->buildRecycleBinState($recycledAppointment, $referenceTime),
                'is_restorable',
            ),
        );
    }

    public function test_past_date_recycle_bin_appointments_cannot_be_restored_even_inside_window(): void
    {
        $patient = $this->createUserWithRole('Patient');
        $appointment = $this->createAppointment($patient->id, 'cancelled', '2026-04-28', '15:00');
        $referenceTime = Carbon::parse('2026-04-30 12:00:00', 'UTC');

        $appointment->delete();

        Appointment::withTrashed()
            ->whereKey($appointment->id)
            ->update([
                'deleted_at' => $referenceTime->copy()->subDay(),
            ]);

        $recycledAppointment = app(AppointmentService::class)->findRecycleBinAppointment((int) $appointment->id);

        $this->assertNotNull($recycledAppointment);
        $this->assertFalse(
            app(AppointmentService::class)->canRestoreRecycleBinAppointment($recycledAppointment, $referenceTime),
        );
        $this->assertFalse(
            data_get(
                app(AppointmentService::class)->buildRecycleBinState($recycledAppointment, $referenceTime),
                'is_restorable',
            ),
        );

        $this->expectException(ValidationException::class);
        $this->expectExceptionMessage('Cannot restore appointments from past dates.');

        app(AppointmentService::class)->assertRecycleBinAppointmentCanBeRestored(
            $recycledAppointment,
            $referenceTime,
        );
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
