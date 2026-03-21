<?php

namespace Tests\Feature;

use App\Models\Appointment;
use App\Models\ClinicSetting;
use App\Models\PatientRecord;
use App\Models\Role;
use App\Models\Service;
use App\Models\StaffRecord;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Artisan;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Schema;
use Tests\TestCase;

class DatabaseIntegrityTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();
        
        // Ensure roles exist
        Role::firstOrCreate(['name' => 'Admin']);
        Role::firstOrCreate(['name' => 'Staff']);
        Role::firstOrCreate(['name' => 'Patient']);
    }

    public function test_integrity_check_passes_on_clean_data(): void
    {
        $adminRole = Role::where('name', 'Admin')->first();
        $patientRole = Role::where('name', 'Patient')->first();

        // Create a clean admin
        $admin = User::create([
            'first_name' => 'Admin',
            'last_name' => 'User',
            'username' => 'adminuser',
            'email' => 'admin@example.com',
            'password' => Hash::make('password'),
            'role_id' => $adminRole->id,
        ]);

        // Create a clean patient with record
        $patientUser = User::create([
            'first_name' => 'Patient',
            'last_name' => 'User',
            'username' => 'patientuser',
            'email' => 'patient@example.com',
            'password' => Hash::make('password'),
            'role_id' => $patientRole->id,
        ]);
        
        $patientRecord = PatientRecord::syncFromUser($patientUser);

        // Create a service and an appointment
        $service = Service::create([
            'name' => 'Checkup',
            'description' => 'General checkup',
            'price' => 500,
            'duration_minutes' => 30,
        ]);

        Appointment::create([
            'patient_id' => $patientRecord->id,
            'service_id' => $service->id,
            'appointment_date' => now()->toDateString(),
            'time_slot' => '09:00',
            'status' => 'pending',
        ]);

        // Create clinic settings
        ClinicSetting::create([
            'opening_time' => '08:00',
            'closing_time' => '17:00',
            'working_days' => ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday'],
            'updated_by_user_id' => $admin->id,
        ]);

        Artisan::call('db:integrity-check');
        $output = Artisan::output();

        $this->assertStringContainsString('All database integrity checks passed', $output);
    }

    public function test_integrity_check_fails_on_orphaned_appointment(): void
    {
        if (DB::getDriverName() === 'sqlite') {
            $this->markTestSkipped('SQLite enforces foreign key constraints strictly, preventing the simulation of orphaned records.');
        }

        $patientUser = User::create([
            'first_name' => 'Orphan',
            'last_name' => 'Patient',
            'username' => 'orphan_patient',
            'email' => 'orphan@example.com',
            'password' => Hash::make('password'),
            'role_id' => Role::where('name', 'Patient')->first()->id,
        ]);
        
        $patientRecord = PatientRecord::syncFromUser($patientUser);

        $service = Service::create([
            'name' => 'Temp Service',
            'description' => 'Temp Service',
            'price' => 100,
            'duration_minutes' => 30,
        ]);

        $appointment = Appointment::create([
            'patient_id' => $patientRecord->id,
            'service_id' => $service->id,
            'appointment_date' => now()->toDateString(),
            'time_slot' => '10:00',
            'status' => 'pending',
        ]);

        // We need to bypass foreign key checks to update the record and orphan the appointment
        Schema::withoutForeignKeyConstraints(function () use ($appointment) {
            DB::table('appointments')->where('id', $appointment->id)->update(['patient_id' => 9999]);
        });

        Artisan::call('db:integrity-check');
        $output = Artisan::output();

        $this->assertStringContainsString('Appointment ID', $output);
        $this->assertStringContainsString('references non-existent PatientRecord', $output);
        $this->assertStringContainsString('Integrity checks failed', $output);
    }

    public function test_integrity_check_fails_on_unhashed_password(): void
    {
        $adminRole = Role::where('name', 'Admin')->first();

        // Directly insert to bypass Hash::make in model if any
        DB::table('users')->insert([
            'first_name' => 'Insecure',
            'last_name' => 'User',
            'username' => 'insecure',
            'email' => 'insecure@example.com',
            'password' => 'plaintext_password', 
            'role_id' => $adminRole->id,
            'created_at' => now(),
            'updated_at' => now(),
        ]);

        Artisan::call('db:integrity-check');
        $output = Artisan::output();

        $this->assertStringContainsString('appears to have an UNHASHED password', $output);
    }

    public function test_integrity_check_fails_on_role_mismatch(): void
    {
        $adminRole = Role::where('name', 'Admin')->first();
        $patientRole = Role::where('name', 'Patient')->first();

        // Create a user with admin role
        $admin = User::create([
            'first_name' => 'Mismatched',
            'last_name' => 'User',
            'username' => 'mismatched',
            'email' => 'mismatched@example.com',
            'password' => Hash::make('password'),
            'role_id' => $adminRole->id,
        ]);

        // BUT give them a PatientRecord
        PatientRecord::create([
            'id' => $admin->id,
            'user_id' => $admin->id,
            'first_name' => 'Mismatched',
            'last_name' => 'User',
            'patient_id' => 'PAT-123456789',
        ]);

        Artisan::call('db:integrity-check');
        $output = Artisan::output();

        $this->assertStringContainsString('has a PatientRecord but is not assigned the Patient role', $output);
    }

    public function test_user_deactivation_preserves_history(): void
    {
        $patientRole = Role::where('name', 'Patient')->first();

        $patientUser = User::create([
            'first_name' => 'Active',
            'last_name' => 'Patient',
            'username' => 'activepatient',
            'email' => 'active@example.com',
            'password' => Hash::make('password'),
            'role_id' => $patientRole->id,
            'is_active' => true,
        ]);

        $patientRecord = PatientRecord::syncFromUser($patientUser);

        $service = Service::create([
            'name' => 'Cleanup Service',
            'description' => 'Cleanup',
            'price' => 50,
            'duration_minutes' => 30,
        ]);

        $appointment = Appointment::create([
            'patient_id' => $patientRecord->id,
            'service_id' => $service->id,
            'appointment_date' => now()->toDateString(),
            'time_slot' => '11:00',
            'status' => 'completed',
        ]);

        // Deactivate the user
        $patientUser->update(['is_active' => false]);

        // Assert record and appointment still exist
        $this->assertDatabaseHas('users', ['id' => $patientUser->id, 'is_active' => false]);
        $this->assertDatabaseHas('patient_records', ['user_id' => $patientUser->id]);
        $this->assertDatabaseHas('appointments', ['id' => $appointment->id, 'patient_id' => $patientRecord->id]);

        // Run integrity check to ensure it doesn't see deactivated user as an issue
        ClinicSetting::create([
            'opening_time' => '08:00',
            'closing_time' => '17:00',
            'working_days' => ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday'],
        ]);

        Artisan::call('db:integrity-check');
        $this->assertStringContainsString('All database integrity checks passed', Artisan::output());
    }
}
