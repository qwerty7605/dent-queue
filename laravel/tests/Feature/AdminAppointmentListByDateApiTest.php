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

class AdminAppointmentListByDateApiTest extends TestCase
{
    use RefreshDatabase;

    public function test_admin_appointments_endpoint_filters_by_date_and_orders_by_queue_number(): void
    {
        $staff = $this->createUserWithRole('Staff');
        $serviceA = $this->createService('Dental Check-up');
        $serviceB = $this->createService('Root Canal');

        $patientA = $this->createUserWithRole('Patient');
        $patientB = $this->createUserWithRole('Patient');
        $patientC = $this->createUserWithRole('Patient');
        $otherDatePatient = $this->createUserWithRole('Patient');

        $date = '2026-03-17';
        $otherDate = '2026-03-18';

        $appointmentQueue3 = $this->createAppointment($patientA->id, $serviceA->id, $date, '10:00', 'pending');
        $appointmentQueue1 = $this->createAppointment($patientB->id, $serviceB->id, $date, '09:00', 'confirmed');
        $appointmentQueue2 = $this->createAppointment($patientC->id, $serviceA->id, $date, '11:00', 'cancelled');
        $otherDateAppointment = $this->createAppointment($otherDatePatient->id, $serviceA->id, $otherDate, '08:00', 'pending');
        $appointmentQueue2->delete();

        $this->createQueue($appointmentQueue3->id, $date, 3);
        $this->createQueue($appointmentQueue1->id, $date, 1);
        $this->createQueue($appointmentQueue2->id, $date, 2);
        $this->createQueue($otherDateAppointment->id, $otherDate, 1);

        Sanctum::actingAs($staff);

        $response = $this->getJson('/api/v1/admin/appointments?date=' . $date);

        $response->assertOk()
            ->assertJsonPath('date', $date)
            ->assertJsonCount(2, 'appointments')
            ->assertJsonPath('appointments.0.id', $appointmentQueue1->id)
            ->assertJsonPath('appointments.0.patient_name', trim($patientB->first_name . ' ' . $patientB->last_name))
            ->assertJsonPath('appointments.0.service_type', $serviceB->name)
            ->assertJsonPath('appointments.0.time', '09:00')
            ->assertJsonPath('appointments.0.status', 'Confirmed')
            ->assertJsonPath('appointments.0.queue_number', 1)
            ->assertJsonPath('appointments.1.id', $appointmentQueue3->id)
            ->assertJsonPath('appointments.1.queue_number', 3);

        $appointmentIds = array_map(
            fn (array $appointment): int => (int) ($appointment['id'] ?? 0),
            $response->json('appointments', []),
        );

        $this->assertNotContains($appointmentQueue2->id, $appointmentIds);

        $appointmentDates = array_map(
            fn (array $appointment): string => (string) ($appointment['appointment_date'] ?? ''),
            $response->json('appointments', []),
        );

        $this->assertSame([$date, $date], $appointmentDates);
    }

    public function test_admin_appointments_endpoint_requires_date_parameter(): void
    {
        $staff = $this->createUserWithRole('Staff');
        Sanctum::actingAs($staff);

        $response = $this->getJson('/api/v1/admin/appointments');

        $response->assertStatus(422)
            ->assertJsonValidationErrors(['date']);
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
            'description' => 'Staff appointment list API test service.',
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
