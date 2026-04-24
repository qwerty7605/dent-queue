<?php

namespace Database\Seeders;

use Illuminate\Database\Seeder;

class HighVolumeAppointmentSimulationSeeder extends Seeder
{
    public function run(): void
    {
        config()->set('bulk_seed.admins', (int) env('BULK_SEED_ADMIN_COUNT', 3));
        config()->set('bulk_seed.staff', (int) env('BULK_SEED_STAFF_COUNT', 15));
        config()->set('bulk_seed.patients', (int) env('BULK_SEED_PATIENT_COUNT', 220));
        config()->set('bulk_seed.walk_in_patients', (int) env('BULK_SEED_WALK_IN_PATIENT_COUNT', 40));
        config()->set('bulk_seed.appointments', (int) env('BULK_SEED_APPOINTMENT_COUNT', 200000));
        config()->set('bulk_seed.appointments_per_day', (int) env('BULK_SEED_APPOINTMENTS_PER_DAY', 40));
        config()->set('bulk_seed.patient_notifications', (int) env('BULK_SEED_PATIENT_NOTIFICATION_COUNT', 0));
        config()->set('bulk_seed.staff_notifications', (int) env('BULK_SEED_STAFF_NOTIFICATION_COUNT', 0));
        config()->set('bulk_seed.reports', (int) env('BULK_SEED_REPORT_COUNT', 0));
        config()->set('bulk_seed.past_days', (int) env('BULK_SEED_PAST_DAYS', 365));
        config()->set('bulk_seed.future_days', (int) env('BULK_SEED_FUTURE_DAYS', 180));

        $this->call([
            RoleSeeder::class,
            ServiceSeeder::class,
            UserSeeder::class,
            BulkUserSeeder::class,
            BulkAppointmentSeeder::class,
        ]);

        $this->command?->info(sprintf(
            'High-volume appointment dataset ready: %d appointments, %d patients, %d walk-ins.',
            (int) config('bulk_seed.appointments'),
            (int) config('bulk_seed.patients'),
            (int) config('bulk_seed.walk_in_patients'),
        ));
    }
}
