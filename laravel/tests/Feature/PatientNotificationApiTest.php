<?php

namespace Tests\Feature;

use App\Models\Appointment;
use App\Models\PatientNotification;
use App\Models\Role;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Str;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class PatientNotificationApiTest extends TestCase
{
    use RefreshDatabase;

    public function test_notification_is_created_after_booking_and_linked_to_patient_id(): void
    {
        $patient = $this->createUserWithRole('Patient');
        Sanctum::actingAs($patient);

        $appointmentDate = now()->next('Monday')->format('Y-m-d');

        $response = $this->postJson('/api/v1/patient/appointments', [
            'service_id' => 1,
            'appointment_date' => $appointmentDate,
            'time_slot' => '09:00',
        ]);

        $response->assertCreated()
            ->assertJsonPath('message', 'Online booking created successfully.');

        $appointmentId = (int) data_get($response->json(), 'appointment.id');
        $this->assertGreaterThan(0, $appointmentId);

        $this->assertDatabaseHas('patient_notifications', [
            'patient_id' => $patient->id,
            'appointment_id' => $appointmentId,
            'type' => 'appointment_created',
            'title' => 'Appointment booked',
        ]);
    }

    public function test_only_the_correct_patient_can_access_notification(): void
    {
        $patient = $this->createUserWithRole('Patient');
        $otherPatient = $this->createUserWithRole('Patient');

        $ownAppointment = $this->createAppointment($patient->id, '2026-03-09', '09:00');
        $otherAppointment = $this->createAppointment($otherPatient->id, '2026-03-10', '10:00');

        $ownNotification = PatientNotification::create([
            'patient_id' => $patient->id,
            'appointment_id' => $ownAppointment->id,
            'type' => 'appointment_created',
            'title' => 'Appointment booked',
            'message' => 'Own notification',
        ]);

        $otherNotification = PatientNotification::create([
            'patient_id' => $otherPatient->id,
            'appointment_id' => $otherAppointment->id,
            'type' => 'appointment_created',
            'title' => 'Appointment booked',
            'message' => 'Other patient notification',
        ]);

        Sanctum::actingAs($patient);

        $listResponse = $this->getJson('/api/v1/patient/notifications');
        $listResponse->assertOk()
            ->assertJsonCount(1, 'notifications')
            ->assertJsonPath('notifications.0.id', $ownNotification->id)
            ->assertJsonPath('notifications.0.patient_id', $patient->id);

        $ownResponse = $this->getJson('/api/v1/patient/notifications/' . $ownNotification->id);
        $ownResponse->assertOk()
            ->assertJsonPath('notification.id', $ownNotification->id)
            ->assertJsonPath('notification.patient_id', $patient->id);

        $crossUserResponse = $this->getJson('/api/v1/patient/notifications/' . $otherNotification->id);
        $crossUserResponse->assertStatus(403)
            ->assertJsonPath('message', 'Unauthorized. You can only view your own notifications.');
    }

    private function createAppointment(int $patientId, string $date, string $timeSlot): Appointment
    {
        return Appointment::create([
            'patient_id' => $patientId,
            'service_id' => 1,
            'appointment_date' => $date,
            'time_slot' => $timeSlot,
            'status' => 'pending',
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
