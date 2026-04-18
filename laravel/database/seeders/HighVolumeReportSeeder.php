<?php

namespace Database\Seeders;

use App\Models\Appointment;
use App\Services\StressDatasetService;
use Illuminate\Database\Seeder;

class HighVolumeReportSeeder extends Seeder
{
    public function run(): void
    {
        $this->call([
            RoleSeeder::class,
            ServiceSeeder::class,
            UserSeeder::class,
        ]);

        $stressDatasetService = app(StressDatasetService::class);

        $appointmentIds = Appointment::withTrashed()
            ->where('notes', 'like', '[stress-booking]%')
            ->pluck('id')
            ->map(static fn (mixed $id): int => (int) $id)
            ->all();

        if ($appointmentIds === []) {
            $bookingSummary = $stressDatasetService->seedBookingSimulation();
            $appointmentIds = $bookingSummary['appointment_ids'];
        }

        $summary = $stressDatasetService->seedReportDataset(
            appointmentIds: $appointmentIds,
        );

        $this->command?->info(sprintf(
            'Seeded %d linked reports across %d appointments.',
            $summary['reports_created'],
            $summary['appointments_linked'],
        ));
    }
}
