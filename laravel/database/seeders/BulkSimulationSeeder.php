<?php

namespace Database\Seeders;

use Illuminate\Database\Seeder;

class BulkSimulationSeeder extends Seeder
{
    public function run(): void
    {
        $this->call([
            RoleSeeder::class,
            ServiceSeeder::class,
            UserSeeder::class,
            BulkUserSeeder::class,
            BulkAppointmentSeeder::class,
            BulkNotificationSeeder::class,
            BulkReportSeeder::class,
        ]);
    }
}
