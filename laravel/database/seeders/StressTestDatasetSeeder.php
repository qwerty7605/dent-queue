<?php

namespace Database\Seeders;

use App\Services\StressDatasetService;
use Illuminate\Database\Seeder;

class StressTestDatasetSeeder extends Seeder
{
    public function run(): void
    {
        $this->call([
            RoleSeeder::class,
            ServiceSeeder::class,
            UserSeeder::class,
        ]);

        $stressDatasetService = app(StressDatasetService::class);
        $bookingSummary = $stressDatasetService->seedBookingSimulation();
        $reportSummary = $stressDatasetService->seedReportDataset(
            appointmentIds: $bookingSummary['appointment_ids'],
        );

        $this->command?->info(sprintf(
            'Stress dataset ready: %d bookings, %d reports, %d prevented conflicts.',
            $bookingSummary['bookings_created'],
            $reportSummary['reports_created'],
            $bookingSummary['time_slot_conflicts_prevented'] + $bookingSummary['patient_date_conflicts_prevented'],
        ));
    }
}
