<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('clinic_settings', function (Blueprint $table) {
            $table->string('clinic_title')->nullable()->after('id');
            $table->string('practice_license_id')->nullable()->after('clinic_title');
            $table->string('operational_hotline')->nullable()->after('practice_license_id');
            $table->text('clinic_headquarters')->nullable()->after('operational_hotline');
        });
    }

    public function down(): void
    {
        Schema::table('clinic_settings', function (Blueprint $table) {
            $table->dropColumn([
                'clinic_title',
                'practice_license_id',
                'operational_hotline',
                'clinic_headquarters',
            ]);
        });
    }
};
