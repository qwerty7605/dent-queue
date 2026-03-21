<?php

namespace App\Console\Commands;

use App\Models\Appointment;
use App\Models\ClinicSetting;
use App\Models\PatientRecord;
use App\Models\Role;
use App\Models\StaffRecord;
use App\Models\User;
use Illuminate\Console\Command;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Str;

class DatabaseIntegrityCheck extends Command
{
    /**
     * The name and signature of the console command.
     *
     * @var string
     */
    protected $signature = 'db:integrity-check';

    /**
     * The description of the console command.
     *
     * @var string
     */
    protected $description = 'Perform final integrity checks on database relationships and consistency';

    /**
     * Execute the console command.
     */
    public function handle()
    {
        $this->info('Starting Database Integrity Checks...');
        $errors = 0;

        $errors += $this->checkRelationalIntegrity();
        $errors += $this->checkIdentityRules();
        $errors += $this->checkRoleConsistency();
        $errors += $this->checkSecurity();
        $errors += $this->checkSettingsPersistence();

        if ($errors === 0) {
            $this->info('✅ All database integrity checks passed!');
            return Command::SUCCESS;
        }

        $this->error("❌ Integrity checks failed with {$errors} error(s).");
        return Command::FAILURE;
    }

    private function checkRelationalIntegrity(): int
    {
        $this->comment('Checking Relational Integrity...');
        $errors = 0;

        // 1. PatientRecord to User (for non-walk-ins)
        $invalidPatientUsers = DB::table('patient_records')
            ->leftJoin('users', 'users.id', '=', 'patient_records.user_id')
            ->whereNotNull('patient_records.user_id')
            ->whereNull('users.id')
            ->select('patient_records.id', 'patient_records.user_id')
            ->get();

        foreach ($invalidPatientUsers as $record) {
            $this->warn("PatientRecord ID {$record->id} references non-existent User ID {$record->user_id}.");
            $errors++;
        }

        // 2. Appointment to PatientRecord
        $invalidAppointments = DB::table('appointments')
            ->leftJoin('patient_records', 'patient_records.id', '=', 'appointments.patient_id')
            ->whereNull('patient_records.id')
            ->select('appointments.id', 'appointments.patient_id')
            ->get();

        foreach ($invalidAppointments as $appointment) {
            $this->warn("Appointment ID {$appointment->id} references non-existent PatientRecord ID {$appointment->patient_id}.");
            $errors++;
        }

        // 3. StaffRecord to User
        $invalidStaffUsers = DB::table('staff_records')
            ->leftJoin('users', 'users.id', '=', 'staff_records.user_id')
            ->whereNull('users.id')
            ->select('staff_records.id', 'staff_records.user_id')
            ->get();

        foreach ($invalidStaffUsers as $record) {
            $this->warn("StaffRecord ID {$record->id} references non-existent User ID {$record->user_id}.");
            $errors++;
        }

        return $errors;
    }

    private function checkIdentityRules(): int
    {
        $this->comment('Checking Identity Rules...');
        $errors = 0;

        // Duplicate Usernames
        $duplicateUsernames = DB::table('users')
            ->select('username', DB::raw('count(*) as count'))
            ->groupBy('username')
            ->having('count', '>', 1)
            ->get();

        foreach ($duplicateUsernames as $duplicate) {
            $this->warn("Duplicate username found: {$duplicate->username} ({$duplicate->count} occurrences).");
            $errors++;
        }

        return $errors;
    }

    private function checkRoleConsistency(): int
    {
        $this->comment('Checking Role Consistency...');
        $errors = 0;

        $patientRole = Role::whereRaw('LOWER(name) = ?', ['patient'])->first();
        $staffRole = Role::whereRaw('LOWER(name) = ?', ['staff'])->first();
        $adminRole = Role::whereRaw('LOWER(name) = ?', ['admin'])->first();

        // Users with PatientRecord should have Patient role
        if ($patientRole) {
            $mismatchedPatients = User::query()
                ->whereHas('patientRecord')
                ->where('role_id', '!=', $patientRole->id)
                ->get();

            foreach ($mismatchedPatients as $user) {
                $this->warn("User ID {$user->id} ({$user->username}) has a PatientRecord but is not assigned the Patient role.");
                $errors++;
            }
        }

        // Users with StaffRecord should have Staff or Admin role
        if ($staffRole && $adminRole) {
            $mismatchedStaff = User::query()
                ->whereHas('staffRecord')
                ->whereNotIn('role_id', [$staffRole->id, $adminRole->id])
                ->get();

            foreach ($mismatchedStaff as $user) {
                $this->warn("User ID {$user->id} ({$user->username}) has a StaffRecord but is not assigned Staff or Admin role.");
                $errors++;
            }
        }

        return $errors;
    }

    private function checkSecurity(): int
    {
        $this->comment('Checking Security...');
        $errors = 0;

        $users = User::all();
        foreach ($users as $user) {
            // Very basic check: bcrypt/argon2 hashes are usually > 30 chars and have a specific format
            if (!Str::startsWith($user->password, ['$2y$', '$2a$', '$argon2i$', '$argon2id$'])) {
                $this->warn("User ID {$user->id} ({$user->username}) appears to have an UNHASHED password.");
                $errors++;
            }
        }

        return $errors;
    }

    private function checkSettingsPersistence(): int
    {
        $this->comment('Checking Settings Persistence...');
        $errors = 0;

        if (ClinicSetting::count() === 0) {
            $this->warn('No ClinicSettings found in the database.');
            // This might not be a hard error depending on deployment stage, but for final check it should exist.
            $errors++;
        }

        return $errors;
    }
}
