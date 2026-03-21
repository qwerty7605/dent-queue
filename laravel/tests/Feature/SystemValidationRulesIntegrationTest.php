<?php

namespace Tests\Feature;

use App\Models\ClinicSetting;
use App\Models\PatientRecord;
use App\Models\Role;
use App\Models\Service;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Str;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class SystemValidationRulesIntegrationTest extends TestCase
{
    use RefreshDatabase;

    public function test_booking_is_rejected_outside_configured_clinic_hours(): void
    {
        $patient = $this->createUserWithRole('Patient');
        $service = $this->createService();
        $this->createClinicSetting('09:00', '15:00', ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday']);
        Sanctum::actingAs($patient);

        $response = $this->postJson('/api/v1/patient/appointments', [
            'service_id' => $service->id,
            'appointment_date' => now()->next('Monday')->format('Y-m-d'),
            'time_slot' => '16:00',
        ]);

        $response->assertStatus(422)
            ->assertJsonValidationErrors(['time_slot'])
            ->assertJsonPath('errors.time_slot.0', 'Booking time must be between 9:00 AM and 3:00 PM.');
    }

    public function test_booking_is_rejected_on_non_working_day_from_clinic_settings(): void
    {
        $patient = $this->createUserWithRole('Patient');
        $service = $this->createService();
        $this->createClinicSetting('09:00', '15:00', ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday']);
        Sanctum::actingAs($patient);

        $response = $this->postJson('/api/v1/patient/appointments', [
            'service_id' => $service->id,
            'appointment_date' => now()->next('Saturday')->format('Y-m-d'),
            'time_slot' => '10:00',
        ]);

        $response->assertStatus(422)
            ->assertJsonValidationErrors(['appointment_date'])
            ->assertJsonPath('errors.appointment_date.0', 'Booking date must fall on a selected working day.');
    }

    public function test_booking_rejects_a_conflicting_time_slot_for_the_same_date(): void
    {
        $staff = $this->createUserWithRole('Staff');
        $service = $this->createService();
        $firstPatient = $this->createUserWithRole('Patient');
        $secondPatient = $this->createUserWithRole('Patient');
        $appointmentDate = now()->next('Tuesday')->format('Y-m-d');
        Sanctum::actingAs($staff);

        $this->postJson('/api/v1/admin/appointments', [
            'patient_id' => $firstPatient->id,
            'service_type' => $service->name,
            'appointment_date' => $appointmentDate,
            'appointment_time' => '10:00',
        ])->assertCreated();

        $response = $this->postJson('/api/v1/admin/appointments', [
            'patient_id' => $secondPatient->id,
            'service_type' => $service->name,
            'appointment_date' => $appointmentDate,
            'appointment_time' => '10:00',
        ]);

        $response->assertStatus(422)
            ->assertJsonValidationErrors(['time_slot'])
            ->assertJsonPath('errors.time_slot.0', 'This schedule is already booked. Please choose another date or time.');
    }

    public function test_booking_rejects_missing_patient_record_without_recreating_identity(): void
    {
        $patient = $this->createUserWithRole('Patient');
        $service = $this->createService();
        $patient->patientRecord()->firstOrFail()->delete();
        Sanctum::actingAs($patient->fresh());

        $response = $this->postJson('/api/v1/patient/appointments', [
            'service_id' => $service->id,
            'appointment_date' => now()->next('Wednesday')->format('Y-m-d'),
            'time_slot' => '09:30',
        ]);

        $response->assertStatus(422)
            ->assertJsonValidationErrors(['patient_id'])
            ->assertJsonPath('errors.patient_id.0', 'Authenticated patient must be linked to an existing patient record.');

        $this->assertSame(0, PatientRecord::query()->where('user_id', (int) $patient->id)->count());
        $this->assertSame(1, PatientRecord::withTrashed()->where('user_id', (int) $patient->id)->count());
        $this->assertDatabaseCount('appointments', 0);
    }

    public function test_booking_uses_existing_patient_record_without_creating_duplicate_identity(): void
    {
        $patient = $this->createUserWithRole('Patient');
        $service = $this->createService();
        $patientRecord = $this->reassignPatientRecord($patient, 9000000004321);
        $patientRecordCountBefore = PatientRecord::withTrashed()->count();
        Sanctum::actingAs($patient->fresh());

        $response = $this->postJson('/api/v1/patient/appointments', [
            'service_id' => $service->id,
            'appointment_date' => now()->next('Thursday')->format('Y-m-d'),
            'time_slot' => '11:00',
        ]);

        $response->assertCreated()
            ->assertJsonPath('appointment.patient_id', (int) $patientRecord->id);

        $this->assertSame($patientRecordCountBefore, PatientRecord::withTrashed()->count());
        $this->assertSame(1, PatientRecord::query()->where('user_id', (int) $patient->id)->count());
    }

    private function createClinicSetting(string $openingTime, string $closingTime, array $workingDays): ClinicSetting
    {
        return ClinicSetting::create([
            'opening_time' => $openingTime,
            'closing_time' => $closingTime,
            'working_days' => $workingDays,
            'updated_by_user_id' => null,
        ]);
    }

    private function reassignPatientRecord(User $patient, int $recordId): PatientRecord
    {
        $patient->patientRecord()->forceDelete();
        $patient->unsetRelation('patientRecord');

        return PatientRecord::create([
            'id' => $recordId,
            'user_id' => (int) $patient->id,
            'first_name' => (string) $patient->first_name,
            'middle_name' => $patient->middle_name,
            'last_name' => (string) $patient->last_name,
            'gender' => $patient->gender,
            'address' => $patient->location,
            'contact_number' => $patient->phone_number,
            'birthdate' => $patient->birthdate,
        ]);
    }

    private function createUserWithRole(string $roleName): User
    {
        $role = Role::firstOrCreate(['name' => $roleName]);
        $suffix = Str::lower($roleName) . '_' . Str::lower(Str::random(8));

        return User::create([
            'first_name' => $roleName,
            'middle_name' => null,
            'last_name' => 'User',
            'username' => $suffix,
            'email' => $suffix . '@example.com',
            'password' => Hash::make('password123'),
            'phone_number' => '09123456789',
            'location' => 'Test City',
            'gender' => 'other',
            'role_id' => $role->id,
            'is_active' => true,
        ]);
    }

    private function createService(): Service
    {
        return Service::create([
            'name' => 'Dental Check-up',
            'description' => 'System validation rules integration test service.',
            'is_active' => true,
        ]);
    }
}
