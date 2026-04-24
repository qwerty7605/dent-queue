<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;

return new class extends Migration
{
    public function up(): void
    {
        $driver = DB::getDriverName();

        if ($driver !== 'mysql') {
            return;
        }

        DB::statement(
            "ALTER TABLE appointments MODIFY status ENUM(
                'pending',
                'confirmed',
                'cancelled',
                'completed',
                'cancelled_by_doctor',
                'reschedule_required'
            ) NOT NULL DEFAULT 'pending'"
        );
    }

    public function down(): void
    {
        $driver = DB::getDriverName();

        if ($driver !== 'mysql') {
            return;
        }

        DB::table('appointments')
            ->where('status', 'cancelled_by_doctor')
            ->update(['status' => 'cancelled']);

        DB::table('appointments')
            ->where('status', 'reschedule_required')
            ->update(['status' => 'pending']);

        DB::statement(
            "ALTER TABLE appointments MODIFY status ENUM(
                'pending',
                'confirmed',
                'cancelled',
                'completed'
            ) NOT NULL DEFAULT 'pending'"
        );
    }
};
