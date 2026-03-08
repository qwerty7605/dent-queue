<?php

namespace Tests\Feature;

use App\Models\Appointment;
use App\Models\Role;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Str;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class PatientMedicalHistoryApiTest extends TestCase
{
    use RefreshDatabase;

    public function test_medical_history_returns_only_completed_appointments_sorted_by_date_desc(): void
    {
        $patient = $this->createUserWithRole('Patient');
        $otherPatient = $this->createUserWithRole('Patient');

        $olderCompleted = $this->createAppointment(
            patientId: $patient->id,
            status: 'completed',
            date: '2026-03-01',
            timeSlot: '09:00',
            notes: 'Older completed note',
        );
        $newerCompleted = $this->createAppointment(
            patientId: $patient->id,
            status: 'completed',
            date: '2026-03-10',
            timeSlot: '10:00',
            notes: 'Newer completed note',
        );

        $this->createAppointment(
            patientId: $patient->id,
            status: 'pending',
            date: '2026-03-12',
            timeSlot: '11:00',
            notes: 'Pending note',
        );
        $this->createAppointment(
            patientId: $otherPatient->id,
            status: 'completed',
            date: '2026-03-15',
            timeSlot: '12:00',
            notes: 'Other patient completed note',
        );

        Sanctum::actingAs($patient);

        $response = $this->getJson('/api/v1/patient/appointments/history');

        $response->assertOk()
            ->assertJsonCount(2, 'appointments')
            ->assertJsonPath('appointments.0.date', '2026-03-10')
            ->assertJsonPath('appointments.1.date', '2026-03-01')
            ->assertJsonMissingPath('appointments.0.id')
            ->assertJsonMissingPath('appointments.0.notes');

        $statuses = array_map(
            fn (array $appointment): string => (string) ($appointment['status'] ?? ''),
            $response->json('appointments', []),
        );

        $this->assertSame(['Completed', 'Completed'], $statuses);
    }

    public function test_medical_history_returns_empty_array_when_no_completed_appointments(): void
    {
        $patient = $this->createUserWithRole('Patient');

        $this->createAppointment(
            patientId: $patient->id,
            status: 'pending',
            date: '2026-03-20',
            timeSlot: '08:00',
        );

        Sanctum::actingAs($patient);

        $response = $this->getJson('/api/v1/patient/appointments/history');

        $response->assertOk()
            ->assertJsonPath('appointments', []);
    }

    private function createAppointment(
        int $patientId,
        string $status,
        string $date,
        string $timeSlot,
        ?string $notes = null,
    ): Appointment {
        return Appointment::create([
            'patient_id' => $patientId,
            'service_id' => 1,
            'appointment_date' => $date,
            'time_slot' => $timeSlot,
            'status' => $status,
            'notes' => $notes,
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
}
