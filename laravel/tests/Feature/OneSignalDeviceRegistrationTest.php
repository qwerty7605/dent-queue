<?php

namespace Tests\Feature;

use App\Models\Appointment;
use App\Models\PatientRecord;
use App\Models\Role;
use App\Models\Service;
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
