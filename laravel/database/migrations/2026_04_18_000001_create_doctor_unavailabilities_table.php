<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('doctor_unavailabilities', function (Blueprint $table) {
            $table->id();
            $table->date('unavailable_date');
            $table->time('start_time');
            $table->time('end_time');
            $table->string('reason', 255)->nullable();
            $table->foreignId('created_by_user_id')
                ->nullable()
                ->constrained('users')
                ->nullOnDelete();
            $table->timestamps();

            $table->index(['unavailable_date', 'start_time']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('doctor_unavailabilities');
    }
};
