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
        if (!Schema::hasTable('users') || Schema::hasColumn('users', 'profile_picture')) {
            return;
        }

        $hasGender = Schema::hasColumn('users', 'gender');

        Schema::table('users', function (Blueprint $table) use ($hasGender) {
            $column = $table->string('profile_picture')->nullable();

            if ($hasGender) {
                $column->after('gender');
            }
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        if (!Schema::hasTable('users') || !Schema::hasColumn('users', 'profile_picture')) {
            return;
        }

        Schema::table('users', function (Blueprint $table) {
            $table->dropColumn('profile_picture');
        });
    }
};
