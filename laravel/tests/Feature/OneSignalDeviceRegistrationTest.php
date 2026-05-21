<?php

namespace Tests\Feature;

use App\Models\Appointment;
use App\Models\PatientRecord;
use App\Models\PatientNotification;
use App\Models\Role;
use App\Models\Service;
use App\Models\StaffNotification;
use App\Models\User;
use App\Models\UserDevice;
use App\Services\OneSignalNotificationService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Http;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class OneSignalDeviceRegistrationTest extends TestCase
{
    use RefreshDatabase;

    public function test_save_onesignal_id_reassigns_same_token_to_authenticated_user(): void
    {
        $patientRole = Role::create(['name' => 'Patient']);
        $oldUser = $this->createUser($patientRole, 'old@example.com', 'olduser');
        $currentUser = $this->createUser($patientRole, 'current@example.com', 'currentuser');

        UserDevice::create([
            'user_id' => $oldUser->id,
            'provider' => 'onesignal',
            'device_token' => 'same-phone-token',
            'device_name' => 'android',
            'is_active' => true,
            'last_login_at' => now()->subDay(),
        ]);

        Sanctum::actingAs($currentUser);

        $response = $this->postJson('/api/save-onesignal-id', [
            'device_token' => 'same-phone-token',
            'provider' => 'onesignal',
            'device_name' => 'android',
        ]);

        $response->assertOk()
            ->assertJsonPath('user_device.user_id', $currentUser->id)
            ->assertJsonPath('user_device.provider', 'onesignal')
            ->assertJsonPath('user_device.is_active', true);

        $this->assertDatabaseHas('user_devices', [
            'user_id' => $oldUser->id,
            'device_token' => 'same-phone-token',
            'is_active' => false,
        ]);

        $this->assertDatabaseHas('user_devices', [
            'user_id' => $currentUser->id,
            'device_token' => 'same-phone-token',
            'provider' => 'onesignal',
            'device_name' => 'android',
            'is_active' => true,
        ]);
    }

    public function test_appointment_approval_push_uses_active_tokens_for_patient_user(): void
    {
        config([
            'services.onesignal.app_id' => 'test-app-id',
            'services.onesignal.rest_api_key' => 'test-rest-key',
        ]);

        Http::fake([
            'https://api.onesignal.com/notifications' => Http::response([
                'id' => 'notification-id',
            ], 200),
        ]);

        $patientRole = Role::create(['name' => 'Patient']);
        $oldUser = $this->createUser($patientRole, 'old@example.com', 'olduser');
        $currentUser = $this->createUser($patientRole, 'current@example.com', 'currentuser');

        UserDevice::create([
            'user_id' => $oldUser->id,
            'provider' => 'onesignal',
            'device_token' => 'same-phone-token',
            'device_name' => 'android',
            'is_active' => false,
            'last_login_at' => now()->subDay(),
        ]);

        UserDevice::create([
            'user_id' => $currentUser->id,
            'provider' => 'onesignal',
            'device_token' => 'same-phone-token',
            'device_name' => 'android',
            'is_active' => true,
            'last_login_at' => now(),
        ]);

        UserDevice::create([
            'user_id' => $currentUser->id,
            'provider' => 'onesignal',
            'device_token' => 'inactive-current-token',
            'device_name' => 'android',
            'is_active' => false,
            'last_login_at' => now(),
        ]);

        $patientRecord = PatientRecord::resolveForUser($currentUser);

        $service = Service::create([
            'name' => 'Dental Check-up',
            'description' => 'Routine check-up',
            'duration_minutes' => 30,
            'price' => 500,
        ]);

        $appointment = Appointment::create([
            'patient_id' => $patientRecord->id,
            'service_id' => $service->id,
            'appointment_date' => now()->addDay()->format('Y-m-d'),
            'time_slot' => '09:00',
            'status' => 'confirmed',
        ]);

        $sent = app(OneSignalNotificationService::class)
            ->sendAppointmentApproved($appointment);

        $this->assertTrue($sent);

        Http::assertSent(function ($request): bool {
            $payload = $request->data();

            return $request->url() === 'https://api.onesignal.com/notifications'
                && $payload['include_subscription_ids'] === ['same-phone-token'];
        });
    }

    public function test_patient_notification_push_uses_notification_content_and_data(): void
    {
        config([
            'services.onesignal.app_id' => 'test-app-id',
            'services.onesignal.rest_api_key' => 'test-rest-key',
        ]);

        Http::fake([
            'https://api.onesignal.com/notifications' => Http::response([
                'id' => 'notification-id',
            ], 200),
        ]);

        $patientRole = Role::create(['name' => 'Patient']);
        $patient = $this->createUser($patientRole, 'patient@example.com', 'patientuser');
        $patientRecord = PatientRecord::resolveForUser($patient);

        UserDevice::create([
            'user_id' => $patient->id,
            'provider' => 'onesignal',
            'device_token' => 'patient-token',
            'device_name' => 'android',
            'is_active' => true,
            'last_login_at' => now(),
        ]);

        $appointment = $this->createAppointmentForPatientRecord($patientRecord);

        $notification = PatientNotification::withoutEvents(fn () => PatientNotification::create([
            'patient_id' => $patientRecord->id,
            'appointment_id' => $appointment->id,
            'type' => 'appointment_rescheduled',
            'title' => 'Appointment Rescheduled',
            'message' => 'Your appointment has been rescheduled.',
        ]));

        $sent = app(OneSignalNotificationService::class)
            ->sendPatientNotification($notification);

        $this->assertTrue($sent);

        Http::assertSent(function ($request) use ($notification, $appointment): bool {
            $payload = $request->data();

            return $request->url() === 'https://api.onesignal.com/notifications'
                && $payload['include_subscription_ids'] === ['patient-token']
                && $payload['headings']['en'] === 'Appointment Rescheduled'
                && $payload['contents']['en'] === 'Your appointment has been rescheduled.'
                && $payload['data']['type'] === 'appointment_rescheduled'
                && $payload['data']['notification_id'] === $notification->id
                && $payload['data']['appointment_id'] === $appointment->id;
        });
    }

    public function test_staff_notification_push_uses_notification_content_and_data(): void
    {
        config([
            'services.onesignal.app_id' => 'test-app-id',
            'services.onesignal.rest_api_key' => 'test-rest-key',
        ]);

        Http::fake([
            'https://api.onesignal.com/notifications' => Http::response([
                'id' => 'notification-id',
            ], 200),
        ]);

        $staffRole = Role::create(['name' => 'Staff']);
        $staff = $this->createUser($staffRole, 'staff@example.com', 'staffuser');
        $patientRole = Role::create(['name' => 'Patient']);
        $patient = $this->createUser($patientRole, 'staff-push-patient@example.com', 'staffpushpatient');
        $patientRecord = PatientRecord::resolveForUser($patient);
        $appointment = $this->createAppointmentForPatientRecord($patientRecord);

        UserDevice::create([
            'user_id' => $staff->id,
            'provider' => 'onesignal',
            'device_token' => 'staff-token',
            'device_name' => 'android',
            'is_active' => true,
            'last_login_at' => now(),
        ]);

        $notification = StaffNotification::withoutEvents(fn () => StaffNotification::create([
            'user_id' => $staff->id,
            'appointment_id' => $appointment->id,
            'type' => 'staff_appointment_cancelled',
            'title' => 'Appointment cancelled by patient',
            'message' => 'A patient cancelled an appointment.',
        ]));

        $sent = app(OneSignalNotificationService::class)
            ->sendStaffNotification($notification);

        $this->assertTrue($sent);

        Http::assertSent(function ($request) use ($notification, $appointment): bool {
            $payload = $request->data();

            return $request->url() === 'https://api.onesignal.com/notifications'
                && $payload['include_subscription_ids'] === ['staff-token']
                && $payload['headings']['en'] === 'Appointment cancelled by patient'
                && $payload['contents']['en'] === 'A patient cancelled an appointment.'
                && $payload['data']['type'] === 'staff_appointment_cancelled'
                && $payload['data']['notification_id'] === $notification->id
                && $payload['data']['appointment_id'] === $appointment->id;
        });
    }

    private function createAppointmentForPatientRecord(PatientRecord $patientRecord): Appointment
    {
        $service = Service::create([
            'name' => 'Dental Check-up',
            'description' => 'Routine check-up',
            'duration_minutes' => 30,
            'price' => 500,
        ]);

        return Appointment::create([
            'patient_id' => $patientRecord->id,
            'service_id' => $service->id,
            'appointment_date' => now()->addDay()->format('Y-m-d'),
            'time_slot' => '09:00',
            'status' => 'pending',
        ]);
    }

    private function createUser(Role $role, string $email, string $username): User
    {
        return User::create([
            'first_name' => 'Test',
            'last_name' => 'User',
            'email' => $email,
            'username' => $username,
            'password' => bcrypt('password123'),
            'role_id' => $role->id,
            'is_active' => true,
        ]);
    }
}
