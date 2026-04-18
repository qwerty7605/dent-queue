<?php

namespace Tests\Feature;

use App\Models\Appointment;
use App\Models\Report;
use App\Services\StressDatasetService;
use Database\Seeders\RoleSeeder;
use Database\Seeders\ServiceSeeder;
use Database\Seeders\UserSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Tests\TestCase;

class StressDatasetServiceTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();

        $this->seed([
            RoleSeeder::class,
            ServiceSeeder::class,
            UserSeeder::class,
        ]);
    }

    public function test_booking_simulation_creates_high_volume_load_without_active_conflicts(): void
    {
        $summary = app(StressDatasetService::class)->seedBookingSimulation(
            patientPoolSize: 36,
            simulationDays: 3,
            bookingsPerDay: 10,
            overlapAttempts: 16,
        );

        $this->assertSame(30, $summary['bookings_created']);
        $this->assertSame(8, $summary['time_slot_conflicts_prevented']);
        $this->assertSame(8, $summary['patient_date_conflicts_prevented']);

        $activeStatuses = ['pending', 'confirmed', 'completed'];

        $duplicateTimeSlots = Appointment::withTrashed()
            ->where('notes', 'like', '[stress-booking]%')
            ->whereIn('status', $activeStatuses)
            ->select('appointment_date', 'time_slot', DB::raw('COUNT(*) as aggregate_count'))
            ->groupBy('appointment_date', 'time_slot')
            ->having('aggregate_count', '>', 1)
            ->get()
            ->count();

        $duplicatePatientDates = Appointment::withTrashed()
            ->where('notes', 'like', '[stress-booking]%')
            ->whereIn('status', $activeStatuses)
            ->select('patient_id', 'appointment_date', DB::raw('COUNT(*) as aggregate_count'))
            ->groupBy('patient_id', 'appointment_date')
            ->having('aggregate_count', '>', 1)
            ->get()
            ->count();

        $maxDailyActiveBookings = Appointment::withTrashed()
            ->where('notes', 'like', '[stress-booking]%')
            ->whereIn('status', $activeStatuses)
            ->select('appointment_date', DB::raw('COUNT(*) as aggregate_count'))
            ->groupBy('appointment_date')
            ->get()
            ->max('aggregate_count');

        $this->assertSame(0, $duplicateTimeSlots);
        $this->assertSame(0, $duplicatePatientDates);
        $this->assertLessThanOrEqual(50, (int) $maxDailyActiveBookings);
    }

    public function test_report_dataset_generation_creates_requested_rows_with_valid_appointments(): void
    {
        $bookingSummary = app(StressDatasetService::class)->seedBookingSimulation(
            patientPoolSize: 28,
            simulationDays: 2,
            bookingsPerDay: 8,
            overlapAttempts: 6,
        );

        $reportSummary = app(StressDatasetService::class)->seedReportDataset(
            targetReportCount: 5000,
            chunkSize: 250,
            appointmentIds: $bookingSummary['appointment_ids'],
        );

        $orphanedReports = Report::query()
            ->leftJoin('appointments', 'appointments.id', '=', 'reports.appointment_id')
            ->whereNull('appointments.id')
            ->count();

        $this->assertSame(5000, $reportSummary['reports_created']);
        $this->assertGreaterThan(0, $reportSummary['appointments_linked']);
        $this->assertSame(5000, Report::query()->count());
        $this->assertSame(0, $orphanedReports);
        $this->assertSame(5000, Report::query()->where('report_type', 'like', 'stress:%')->count());
    }
}
