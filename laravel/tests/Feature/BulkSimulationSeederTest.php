<?php

namespace Tests\Feature;

use App\Models\Appointment;
use App\Models\PatientNotification;
use App\Models\PatientRecord;
use App\Models\Report;
use App\Models\StaffNotification;
use App\Models\User;
use Database\Seeders\BulkSimulationSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class BulkSimulationSeederTest extends TestCase
{
    use RefreshDatabase;

    public function test_bulk_simulation_seeder_generates_valid_linked_data_and_can_be_re_run(): void
    {
        config()->set('bulk_seed.admins', 2);
        config()->set('bulk_seed.staff', 4);
        config()->set('bulk_seed.patients', 14);
        config()->set('bulk_seed.walk_in_patients', 4);
        config()->set('bulk_seed.appointments', 36);
        config()->set('bulk_seed.appointments_per_day', 10);
        config()->set('bulk_seed.patient_notifications', 30);
        config()->set('bulk_seed.staff_notifications', 18);
        config()->set('bulk_seed.reports', 24);
        config()->set('bulk_seed.past_days', 30);
        config()->set('bulk_seed.future_days', 15);

        $this->seed(BulkSimulationSeeder::class);
        $this->seed(BulkSimulationSeeder::class);

        $this->assertSame(2, User::query()->where('email', 'like', 'bulk.admin.%@example.com')->count());
        $this->assertSame(4, User::query()->where('email', 'like', 'bulk.staff.%@example.com')->count());
        $this->assertSame(14, User::query()->where('email', 'like', 'bulk.patient.%@example.com')->count());

        $bulkAppointments = Appointment::withTrashed()
            ->with(['patient.user', 'service', 'queue'])
            ->where('notes', 'like', '[bulk-seeded]%')
            ->get();

        $this->assertCount(36, $bulkAppointments);
        $this->assertTrue($bulkAppointments->every(fn (Appointment $appointment): bool => $appointment->patient !== null));
        $this->assertTrue($bulkAppointments->every(fn (Appointment $appointment): bool => $appointment->service !== null));
        $this->assertSame([6, 10, 10, 10], $bulkAppointments
            ->groupBy('appointment_date')
            ->map(fn ($appointments): int => $appointments->count())
            ->sort()
            ->values()
            ->all());

        $walkInRecords = PatientRecord::query()
            ->whereNull('user_id')
            ->where('patient_id', 'like', 'BULK-WALK-%')
            ->get();

        $this->assertCount(4, $walkInRecords);
        $this->assertTrue($walkInRecords->every(
            fn (PatientRecord $record): bool => ! str_starts_with($record->first_name, 'WalkIn') && $record->last_name !== 'Guest',
        ));

        $queueBackedAppointments = $bulkAppointments
            ->whereNull('deleted_at')
            ->whereIn('status', ['pending', 'confirmed', 'completed']);

        $this->assertTrue($queueBackedAppointments->every(fn (Appointment $appointment): bool => $appointment->queue !== null));
        $this->assertSame(
            $queueBackedAppointments->count(),
            $queueBackedAppointments->pluck('queue.id')->filter()->count(),
        );

        $patientNotifications = PatientNotification::query()
            ->whereHas('appointment', function ($query): void {
                $query->where('notes', 'like', '[bulk-seeded]%');
            })
            ->get();

        $staffNotifications = StaffNotification::query()
            ->whereHas('appointment', function ($query): void {
                $query->where('notes', 'like', '[bulk-seeded]%');
            })
            ->get();

        $reports = Report::query()
            ->whereHas('appointment', function ($query): void {
                $query->where('notes', 'like', '[bulk-seeded]%');
            })
            ->get();

        $this->assertCount(30, $patientNotifications);
        $this->assertCount(18, $staffNotifications);
        $this->assertCount(24, $reports);

        $this->assertTrue($patientNotifications->every(
            fn (PatientNotification $notification): bool => $notification->patient !== null && $notification->appointment !== null,
        ));
        $this->assertTrue($staffNotifications->every(
            fn (StaffNotification $notification): bool => $notification->user !== null && $notification->appointment !== null,
        ));
        $this->assertTrue($reports->every(fn (Report $report): bool => $report->appointment !== null && is_array($report->data)));
    }
}
