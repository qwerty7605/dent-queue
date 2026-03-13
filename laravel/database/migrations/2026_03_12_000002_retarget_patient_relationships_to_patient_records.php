<?php

use App\Models\PatientRecord;
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
        $this->backfillPatientRecords();

        Schema::table('appointments', function (Blueprint $table) {
            $table->dropForeign(['patient_id']);
        });

        Schema::table('patient_notifications', function (Blueprint $table) {
            $table->dropForeign(['patient_id']);
        });

        Schema::table('appointments', function (Blueprint $table) {
            $table->foreign('patient_id')
                ->references('id')
                ->on('patient_records')
                ->cascadeOnDelete();
        });

        Schema::table('patient_notifications', function (Blueprint $table) {
            $table->foreign('patient_id')
                ->references('id')
                ->on('patient_records')
                ->cascadeOnDelete();
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::table('patient_notifications', function (Blueprint $table) {
            $table->dropForeign(['patient_id']);
        });

        Schema::table('appointments', function (Blueprint $table) {
            $table->dropForeign(['patient_id']);
        });

        Schema::table('patient_notifications', function (Blueprint $table) {
            $table->foreign('patient_id')
                ->references('id')
                ->on('users')
                ->cascadeOnDelete();
        });

        Schema::table('appointments', function (Blueprint $table) {
            $table->foreign('patient_id')
                ->references('id')
                ->on('users')
                ->cascadeOnDelete();
        });
    }

    private function backfillPatientRecords(): void
    {
        $users = DB::table('users')
            ->leftJoin('roles', 'roles.id', '=', 'users.role_id')
            ->leftJoin('appointments as booked_appointments', 'booked_appointments.patient_id', '=', 'users.id')
            ->leftJoin('patient_notifications as patient_alerts', 'patient_alerts.patient_id', '=', 'users.id')
            ->select([
                'users.id',
                'users.first_name',
                'users.middle_name',
                'users.last_name',
                'users.gender',
                'users.location',
                'users.phone_number',
                'users.birthdate',
                'roles.name as role_name',
                DB::raw('MAX(booked_appointments.id) as has_appointment'),
                DB::raw('MAX(patient_alerts.id) as has_notification'),
            ])
            ->groupBy([
                'users.id',
                'users.first_name',
                'users.middle_name',
                'users.last_name',
                'users.gender',
                'users.location',
                'users.phone_number',
                'users.birthdate',
                'roles.name',
            ])
            ->get();

        foreach ($users as $user) {
            $isPatientRole = mb_strtolower((string) ($user->role_name ?? '')) === 'patient';
            $hasPatientData = $user->has_appointment !== null || $user->has_notification !== null;

            if (!$isPatientRole && !$hasPatientData) {
                continue;
            }

            $existingRecord = DB::table('patient_records')
                ->where('user_id', (int) $user->id)
                ->orWhere('id', (int) $user->id)
                ->exists();

            if ($existingRecord) {
                continue;
            }

            DB::table('patient_records')->insert([
                'id' => (int) $user->id,
                'patient_id' => PatientRecord::formatPatientIdentifier((int) $user->id),
                'user_id' => (int) $user->id,
                'first_name' => $user->first_name,
                'middle_name' => $user->middle_name,
                'last_name' => $user->last_name,
                'gender' => $user->gender,
                'address' => $user->location,
                'contact_number' => $user->phone_number,
                'birthdate' => $user->birthdate,
                'created_at' => now(),
                'updated_at' => now(),
            ]);
        }
    }
};
