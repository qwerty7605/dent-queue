<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Run the migrations.
     */
    public function up(): void
    {
        Schema::create('appointment_service', function (Blueprint $table) {
            $table->id();
            $table->foreignId('appointment_id')
                ->constrained('appointments')
                ->cascadeOnDelete();
            $table->foreignId('service_id')
                ->constrained('services')
                ->cascadeOnDelete();
            $table->timestamps();

            $table->unique(['appointment_id', 'service_id']);
        });

        DB::table('appointments')
            ->whereNotNull('service_id')
            ->orderBy('id')
            ->select(['id', 'service_id', 'created_at', 'updated_at'])
            ->chunkById(500, function ($appointments): void {
                $rows = [];

                foreach ($appointments as $appointment) {
                    $rows[] = [
                        'appointment_id' => (int) $appointment->id,
                        'service_id' => (int) $appointment->service_id,
                        'created_at' => $appointment->created_at,
                        'updated_at' => $appointment->updated_at,
                    ];
                }

                if ($rows !== []) {
                    DB::table('appointment_service')->insertOrIgnore($rows);
                }
            });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('appointment_service');
    }
};
