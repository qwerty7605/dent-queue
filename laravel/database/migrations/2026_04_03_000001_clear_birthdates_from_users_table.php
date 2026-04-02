<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;

return new class extends Migration
{
    public function up(): void
    {
        DB::table('users')->update([
            'birthdate' => null,
        ]);
    }

    public function down(): void
    {
        // User birthdates were intentionally removed and cannot be restored.
    }
};
