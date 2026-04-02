<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Run the migrations.
     */
    public function up(): void
    {
        if (!Schema::hasColumn('staff_records', 'middle_name')) {
            Schema::table('staff_records', function (Blueprint $table) {
                $table->string('middle_name', 100)->nullable()->after('first_name');
            });
        }
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        if (Schema::hasColumn('staff_records', 'middle_name')) {
            Schema::table('staff_records', function (Blueprint $table) {
                $table->dropColumn('middle_name');
            });
        }
    }
};
