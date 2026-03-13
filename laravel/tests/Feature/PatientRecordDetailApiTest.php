<?php

namespace Tests\Feature;

use App\Models\Appointment;
use App\Models\PatientRecord;
use App\Models\Role;
use App\Models\Service;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Str;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class PatientRecordDetailApiTest extends TestCase
{
    use RefreshDatabase;

    public function test_staff_can_fetch_patient_detail_with_profile_upcoming_and_completed_history(): void
    {
        $staff = $this->createUserWithRole('Staff');
        $patient = $this->createUserWithRole('Patient');
        $patientRecord = PatientRecord::resolveForUser($patient);

        $checkup = $this->createService('Dental Check-up');
        $rootCanal = $this->createService('Root Canal');
        $xray = $this->createService('Dental Panoramic X-ray');
        $cleaning = $this->createService('Teeth Cleaning');
        $whitening = $this->createService('Teeth Whitening');

        $today = Carbon::today((string) config('app.timezone', 'UTC'));

        $todayPending = $this->createAppointment(
            patientId: (int) $patientRecord->id,
            serviceId: (int) $checkup->id,
            date: $today->toDateString(),
            timeSlot: '08:00',
            status: 'pending',
        );
        $futureApproved = $this->createAppointment(
            patientId: (int) $patientRecord->id,
            serviceId: (int) $rootCanal->id,
            date: $today->copy()->addDays(2)->toDateString(),
            timeSlot: '09:30',
            status: 'confirmed',
        );
        $this->createAppointment(
            patientId: (int) $patientRecord->id,
            serviceId: (int) $xray->id,
            date: $today->copy()->subDay()->toDateString(),
            timeSlot: '10:00',
            status: 'pending',
        );
        $this->createAppointment(
            patientId: (int) $patientRecord->id,
            serviceId: (int) $cleaning->id,
            date: $today->copy()->addDay()->toDateString(),
            timeSlot: '11:00',
            status: 'cancelled',
        );
        $recentCompleted = $this->createAppointment(
            patientId: (int) $patientRecord->id,
            serviceId: (int) $whitening->id,
            date: $today->copy()->subDays(3)->toDateString(),
            timeSlot: '13:00',
            status: 'completed',
        );
        $olderCompleted = $this->createAppointment(
            patientId: (int) $patientRecord->id,
            serviceId: (int) $checkup->id,
            date: $today->copy()->subDays(20)->toDateString(),
            timeSlot: '15:30',
            status: 'completed',
        );

        $otherPatient = $this->createUserWithRole('Patient');
        $otherPatientRecord = PatientRecord::resolveForUser($otherPatient);
        $this->createAppointment(
            patientId: (int) $otherPatientRecord->id,
            serviceId: (int) $checkup->id,
            date: $today->copy()->addDay()->toDateString(),
            timeSlot: '12:30',
            status: 'confirmed',
        );

        Sanctum::actingAs($staff);

        $response = $this->getJson('/api/v1/admin/patients/' . $patientRecord->patient_id);

        $response->assertOk()
            ->assertJsonPath('patient.id', (int) $patientRecord->id)
            ->assertJsonPath('patient.patient_id', (string) $patientRecord->patient_id)
            ->assertJsonPath('patient.full_name', trim($patient->first_name . ' ' . $patient->last_name))
            ->assertJsonPath('patient.gender', ucfirst((string) $patientRecord->gender))
            ->assertJsonPath('patient.birthdate', optional($patientRecord->birthdate)?->toDateString())
            ->assertJsonPath('patient.address', $patientRecord->address)
            ->assertJsonPath('patient.contact_number', $patientRecord->contact_number)
            ->assertJsonCount(2, 'upcoming_appointments')
            ->assertJsonCount(2, 'clinical_history')
            ->assertJsonPath('upcoming_appointments.0.id', (int) $todayPending->id)
            ->assertJsonPath('upcoming_appointments.0.service_type', $checkup->name)
            ->assertJsonPath('upcoming_appointments.0.status', 'Pending')
            ->assertJsonPath('upcoming_appointments.1.id', (int) $futureApproved->id)
            ->assertJsonPath('upcoming_appointments.1.service_type', $rootCanal->name)
            ->assertJsonPath('upcoming_appointments.1.status', 'Approved')
            ->assertJsonPath('clinical_history.0.id', (int) $recentCompleted->id)
            ->assertJsonPath('clinical_history.0.service_type', $whitening->name)
            ->assertJsonPath('clinical_history.0.status', 'Completed')
            ->assertJsonPath('clinical_history.1.id', (int) $olderCompleted->id)
            ->assertJsonPath('clinical_history.1.service_type', $checkup->name)
            ->assertJsonPath('clinical_history.1.status', 'Completed');
    }

    public function test_patient_detail_returns_not_found_for_unknown_patient_id(): void
    {
        $staff = $this->createUserWithRole('Staff');
        Sanctum::actingAs($staff);

        $response = $this->getJson('/api/v1/admin/patients/SDQ-9999');

        $response->assertNotFound();
    }

    private function createAppointment(
        int $patientId,
        int $serviceId,
        string $date,
        string $timeSlot,
        string $status,
    ): Appointment {
        return Appointment::create([
            'patient_id' => $patientId,
            'service_id' => $serviceId,
            'appointment_date' => $date,
            'time_slot' => $timeSlot,
            'status' => $status,
        ]);
    }

    private function createService(string $name): Service
    {
        return Service::create([
            'name' => $name,
            'description' => 'Patient detail API test service.',
            'is_active' => true,
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
            'birthdate' => '1995-05-15',
            'role_id' => $role->id,
            'is_active' => true,
        ]);
    }
}
