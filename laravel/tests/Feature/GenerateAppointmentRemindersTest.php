<?php

namespace Tests\Feature;

use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;
use App\Models\Appointment;
use App\Models\PatientRecord;
use Illuminate\Support\Str;
use App\Models\User;
use App\Models\Service;
use App\Models\PatientNotification;
use Carbon\Carbon;
use Illuminate\Support\Facades\Hash;
use App\Models\Role;

class GenerateAppointmentRemindersTest extends TestCase
{
    use RefreshDatabase;

    private function createPatient(): PatientRecord
    {
        $role = Role::firstOrCreate(['name' => 'Patient']);
        $user = User::create([
            'first_name' => 'Patient',
            'last_name' => 'User',
            'username' => 'pat_' . Str::random(8),
            'email' => 'pat_' . Str::random(8) . '@example.com',
            'password' => Hash::make('password123'),
            'role_id' => $role->id,
            'gender' => 'other',
            'location' => 'Test City',
            'phone_number' => '09123456789',
        ]);

        return PatientRecord::syncFromUser($user);
    }

    private function createService(): Service
    {
        return Service::create([
            'name' => 'Dental Checkup',
            'description' => 'Test service',
            'is_active' => true,
        ]);
    }

    public function test_it_generates_reminders_for_eligible_appointments()
    {
        $patient = $this->createPatient();
        $service = $this->createService();

        // Eligible appointment (tomorrow, approved)
        $appointment = Appointment::create([
            'patient_id' => $patient->id,
            'service_id' => $service->id,
            'appointment_date' => Carbon::tomorrow()->toDateString(),
            'time_slot' => '10:00:00',
            'status' => 'approved',
        ]);

        $this->artisan('appointments:generate-reminders')
            ->expectsOutput("Generated 1 reminder notifications for " . Carbon::tomorrow()->toDateString() . ".")
            ->assertExitCode(0);

        $this->assertDatabaseHas('patient_notifications', [
            'patient_id' => $patient->id,
            'appointment_id' => $appointment->id,
            'type' => 'reminder',
        ]);
        
        $notification = PatientNotification::where('appointment_id', $appointment->id)->first();
        $this->assertStringContainsString('Dental Checkup', $notification->message);
        $this->assertStringContainsString('10:00 AM', $notification->message);
    }

    public function test_it_does_not_generate_reminders_for_cancelled_or_pending_appointments()
    {
        $patient = $this->createPatient();
        $service = $this->createService();

        Appointment::create([
            'patient_id' => $patient->id,
            'service_id' => $service->id,
            'appointment_date' => Carbon::tomorrow()->toDateString(),
            'status' => 'cancelled',
            'time_slot' => '10:00:00',
        ]);

        Appointment::create([
            'patient_id' => $patient->id,
            'service_id' => $service->id,
            'appointment_date' => Carbon::tomorrow()->toDateString(),
            'status' => 'pending',
            'time_slot' => '11:00:00',
        ]);

        $this->artisan('appointments:generate-reminders')
            ->expectsOutput("Generated 0 reminder notifications for " . Carbon::tomorrow()->toDateString() . ".")
            ->assertExitCode(0);

        $this->assertDatabaseCount('patient_notifications', 0);
    }

    public function test_it_prevents_duplicate_reminders()
    {
        $patient = $this->createPatient();
        $service = $this->createService();

        $appointment = Appointment::create([
            'patient_id' => $patient->id,
            'service_id' => $service->id,
            'appointment_date' => Carbon::tomorrow()->toDateString(),
            'status' => 'approved',
            'time_slot' => '10:00:00',
        ]);

        // First run
        $this->artisan('appointments:generate-reminders')->assertExitCode(0);
        $this->assertDatabaseCount('patient_notifications', 1);

        // Second run
        $this->artisan('appointments:generate-reminders')
            ->expectsOutput("Generated 0 reminder notifications for " . Carbon::tomorrow()->toDateString() . ".")
            ->assertExitCode(0);
            
        $this->assertDatabaseCount('patient_notifications', 1);
    }
}
