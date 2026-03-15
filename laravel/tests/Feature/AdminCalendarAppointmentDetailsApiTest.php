<?php

namespace Tests\Feature;

use App\Models\Appointment;
use App\Models\Queue;
use App\Models\Role;
use App\Models\Service;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Str;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class AdminCalendarAppointmentDetailsApiTest extends TestCase
{
    use RefreshDatabase;

    public function test_admin_calendar_appointments_endpoint_returns_approved_summary_fields(): void
    {
        $staff = $this->createUserWithRole('Staff');
        $service = $this->createService('Teeth Cleaning');
        $patient = $this->createUserWithRole('Patient');
        $date = '2026-03-21';

        $approvedAppointment = $this->createAppointment(
            $patient->id,
            $service->id,
            $date,
            '15:00',
            'confirmed',
            'Bring previous x-ray.',
        );
        $pendingAppointment = $this->createAppointment(
            $patient->id,
            $service->id,
            $date,
            '16:00',
            'pending',
            'Should not appear.',
        );

        $this->createQueue($approvedAppointment->id, $date, 5);
        $this->createQueue($pendingAppointment->id, $date, 6);

        Sanctum::actingAs($staff);

        $response = $this->getJson('/api/v1/admin/calendar/appointments?date=' . $date);

        $response->assertOk()
            ->assertJsonPath('date', $date)
            ->assertJsonCount(1, 'appointments')
            ->assertJsonPath('appointments.0.id', $approvedAppointment->id)
            ->assertJsonPath('appointments.0.service_type', 'Teeth Cleaning')
            ->assertJsonPath('appointments.0.appointment_date', $date)
            ->assertJsonPath('appointments.0.appointment_time', '15:00')
            ->assertJsonPath('appointments.0.queue_number', 5)
            ->assertJsonPath('appointments.0.notes', 'Bring previous x-ray.')
            ->assertJsonPath('appointments.0.status', 'Approved');
    }

    public function test_admin_calendar_appointment_details_returns_complete_fields_for_selected_appointment(): void
    {
        $staff = $this->createUserWithRole('Staff');
        $service = $this->createService('Root Canal');
        $patient = $this->createUserWithRole('Patient');
        $appointment = $this->createAppointment(
            $patient->id,
            $service->id,
            '2026-03-22',
            '09:15',
            'confirmed',
            'Requires anesthesia review.',
        );
        $this->createQueue($appointment->id, '2026-03-22', 3);

        Sanctum::actingAs($staff);

        $response = $this->getJson('/api/v1/admin/calendar/appointments/' . $appointment->id);

        $response->assertOk()
            ->assertJsonPath('appointment.id', $appointment->id)
            ->assertJsonPath('appointment.patient_name', trim($patient->first_name . ' ' . $patient->last_name))
            ->assertJsonPath('appointment.service_type', 'Root Canal')
            ->assertJsonPath('appointment.appointment_date', '2026-03-22')
            ->assertJsonPath('appointment.appointment_time', '09:15')
            ->assertJsonPath('appointment.queue_number', 3)
            ->assertJsonPath('appointment.notes', 'Requires anesthesia review.')
            ->assertJsonPath('appointment.status', 'Approved');
    }

    public function test_admin_calendar_appointment_details_returns_not_found_for_non_approved_appointment(): void
    {
        $staff = $this->createUserWithRole('Staff');
        $service = $this->createService('Dental Check-up');
        $patient = $this->createUserWithRole('Patient');
        $appointment = $this->createAppointment(
            $patient->id,
            $service->id,
            '2026-03-22',
            '11:00',
            'pending',
            'Pending review.',
        );
        $this->createQueue($appointment->id, '2026-03-22', 7);

        Sanctum::actingAs($staff);

        $response = $this->getJson('/api/v1/admin/calendar/appointments/' . $appointment->id);

        $response->assertNotFound()
            ->assertJsonPath('message', 'Appointment not found.');
    }

    private function createQueue(int $appointmentId, string $date, int $queueNumber): Queue
    {
        return Queue::create([
            'appointment_id' => $appointmentId,
            'queue_date' => $date,
            'queue_number' => $queueNumber,
            'is_called' => false,
        ]);
    }

    private function createAppointment(
        int $patientId,
        int $serviceId,
        string $date,
        string $timeSlot,
        string $status,
        string $notes,
    ): Appointment {
        return Appointment::create([
            'patient_id' => $patientId,
            'service_id' => $serviceId,
            'appointment_date' => $date,
            'time_slot' => $timeSlot,
            'status' => $status,
            'notes' => $notes,
        ]);
    }

    private function createService(string $name): Service
    {
        return Service::create([
            'name' => $name,
            'description' => 'Calendar appointment details API test service.',
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
            'role_id' => $role->id,
            'is_active' => true,
        ]);
    }
}
