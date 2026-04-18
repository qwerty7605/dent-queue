<?php

namespace Database\Seeders;

use App\Services\StressDatasetService;
use Illuminate\Database\Seeder;

class HighVolumeBookingSeeder extends Seeder
{
    public function run(): void
    {
        $this->call([
            RoleSeeder::class,
            ServiceSeeder::class,
            UserSeeder::class,
        ]);

        $summary = app(StressDatasetService::class)->seedBookingSimulation();

        $this->command?->info(sprintf(
            'Seeded %d stress-test bookings across %d dates for %d patients.',
            $summary['bookings_created'],
            $summary['dates_simulated'],
            $summary['patients_seeded'],
        ));
        $this->command?->info(sprintf(
            'Prevented %d time-slot conflicts and %d same-patient/day conflicts.',
            $summary['time_slot_conflicts_prevented'],
            $summary['patient_date_conflicts_prevented'],
        ));
    }
}
