<?php

namespace Tests\Feature;

use App\Models\Appointment;
use App\Models\PatientRecord;
use App\Models\Queue;
use App\Models\Role;
use App\Models\Service;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Str;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class QueueNowServingApiTest extends TestCase
{
    use RefreshDatabase;

    public function test_patient_today_queue_snapshot_includes_now_serving_next_up_and_patient_queue(): void
    {
        $service = $this->createService('Dental Check-up');
        $patientA = $this->createUserWithRole('Patient');
        $patientB = $this->createUserWithRole('Patient');
        $patientC = $this->createUserWithRole('Patient');
        $date = now()->format('Y-m-d');

        $appointmentA = $this->createAppointment($this->patientRecordId($patientA), $service->id, $date, '09:00', 'confirmed');
        $appointmentB = $this->createAppointment($this->patientRecordId($patientB), $service->id, $date, '10:00', 'confirmed');
        $appointmentC = $this->createAppointment($this->patientRecordId($patientC), $service->id, $date, '11:00', 'pending');

        $this->createQueue($appointmentA->id, $date, 1, true);
        $this->createQueue($appointmentB->id, $date, 2, false);
        $this->createQueue($appointmentC->id, $date, 3, false);

        Sanctum::actingAs($patientB);

        $response = $this->getJson('/api/v1/patient/queues/today');

        $response->assertOk()
            ->assertJsonPath('date', $date)
            ->assertJsonPath('now_serving.queue_number', 1)
            ->assertJsonPath('next_up.queue_number', 2)
            ->assertJsonPath('patient_queue.queue_number', 2)
            ->assertJsonPath('patient_queue.is_called', false)
            ->assertJsonPath('patient_queue.is_now_serving', false)
            ->assertJsonPath('patient_queue.people_ahead', 1);
    }

    public function test_patient_can_join_today_queue_for_existing_appointment_without_queue(): void
    {
        $service = $this->createService('Root Canal');
        $patient = $this->createUserWithRole('Patient');
        $date = now()->format('Y-m-d');
        $appointment = $this->createAppointment($this->patientRecordId($patient), $service->id, $date, '13:00', 'confirmed');

        Sanctum::actingAs($patient);

        $response = $this->postJson('/api/v1/patient/queues/join');

        $response->assertCreated()
            ->assertJsonPath('message', 'Queue joined successfully.')
            ->assertJsonPath('queue.appointment_id', $appointment->id)
            ->assertJsonPath('queue.queue_number', 1)
            ->assertJsonPath('patient_queue.queue_number', 1)
            ->assertJsonPath('patient_queue.is_now_serving', false);

        $this->assertDatabaseHas('queues', [
            'appointment_id' => $appointment->id,
            'queue_date' => $date,
            'queue_number' => 1,
            'is_called' => false,
        ]);
    }

    public function test_staff_call_next_skips_non_approved_appointments_and_advances_queue(): void
    {
        $staff = $this->createUserWithRole('Staff');
        $service = $this->createService('Teeth Cleaning');
        $date = '2026-03-23';

        $pendingPatient = $this->createUserWithRole('Patient');
        $approvedPatient = $this->createUserWithRole('Patient');
        $approvedPatient2 = $this->createUserWithRole('Patient');

        $pendingAppointment = $this->createAppointment($this->patientRecordId($pendingPatient), $service->id, $date, '09:00', 'pending');
        $approvedAppointment = $this->createAppointment($this->patientRecordId($approvedPatient), $service->id, $date, '10:00', 'confirmed');
        $approvedAppointment2 = $this->createAppointment($this->patientRecordId($approvedPatient2), $service->id, $date, '11:00', 'confirmed');

        $this->createQueue($pendingAppointment->id, $date, 1, false);
        $this->createQueue($approvedAppointment->id, $date, 2, false);
        $this->createQueue($approvedAppointment2->id, $date, 3, false);

        Sanctum::actingAs($staff);

        $response = $this->postJson('/api/v1/admin/queues/call-next', [
            'date' => $date,
        ]);

        $response->assertOk()
            ->assertJsonPath('message', 'Next patient called successfully.')
            ->assertJsonPath('called_queue.queue_number', 2)
            ->assertJsonPath('now_serving.queue_number', 2)
            ->assertJsonPath('next_up.queue_number', 3);

        $this->assertDatabaseHas('queues', [
            'appointment_id' => $approvedAppointment->id,
            'queue_date' => $date,
            'queue_number' => 2,
            'is_called' => true,
        ]);

        $this->assertDatabaseHas('queues', [
            'appointment_id' => $pendingAppointment->id,
            'queue_date' => $date,
            'queue_number' => 1,
            'is_called' => false,
        ]);
    }

    private function createQueue(int $appointmentId, string $date, int $queueNumber, bool $isCalled): Queue
    {
        return Queue::create([
            'appointment_id' => $appointmentId,
            'queue_date' => $date,
            'queue_number' => $queueNumber,
            'is_called' => $isCalled,
        ]);
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

    private function patientRecordId(User $user): int
    {
        $patientRecord = $user->patientRecord()->first();

        return (int) $patientRecord->id;
    }

    private function createService(string $name): Service
    {
        return Service::create([
            'name' => $name,
            'description' => 'Queue now serving test service.',
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
