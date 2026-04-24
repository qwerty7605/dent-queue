<?php

namespace Tests\Feature;

use App\Models\Appointment;
use App\Models\ClinicSetting;
use App\Models\PatientNotification;
use App\Models\PatientRecord;
use App\Models\Role;
use App\Models\Service;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Str;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class AdminClinicSettingsApiTest extends TestCase
{
    use RefreshDatabase;

    public function test_admin_can_fetch_current_settings_when_none_are_configured(): void
    {
        $admin = $this->createUserWithRole('Admin');
        Sanctum::actingAs($admin);

        $response = $this->getJson('/api/v1/admin/settings/clinic');

        $response->assertOk()
            ->assertJsonPath('data.clinic_title', null)
            ->assertJsonPath('data.practice_license_id', null)
            ->assertJsonPath('data.operational_hotline', null)
            ->assertJsonPath('data.clinic_headquarters', null)
            ->assertJsonPath('data.opening_time', null)
            ->assertJsonPath('data.closing_time', null)
            ->assertJsonPath('data.working_days', [])
            ->assertJsonPath('data.daily_operating_hours', [])
            ->assertJsonPath('data.updated_by_user_id', null)
            ->assertJsonPath('data.updated_at', null);
    }

    public function test_admin_can_save_and_retrieve_per_day_clinic_settings(): void
    {
        $admin = $this->createUserWithRole('Admin');
        Sanctum::actingAs($admin);

        $payload = [
            'clinic_title' => 'SmartDentQueue Dental Center',
            'practice_license_id' => 'SDQ-M-10294',
            'operational_hotline' => '+1 (555) 890-0123',
            'clinic_headquarters' => '1204 Dental Plaza, Medical District, Suite 405, Metro City, 10042',
            'daily_operating_hours' => [
                'Sunday' => ['opening_time' => '10:00', 'closing_time' => '15:00'],
                'Tuesday' => ['opening_time' => '09:00', 'closing_time' => '16:00'],
                'Saturday' => ['opening_time' => '08:30', 'closing_time' => '17:00'],
            ],
        ];

        $saveResponse = $this->putJson('/api/v1/admin/settings/clinic', $payload);

        $saveResponse->assertOk()
            ->assertJsonPath('message', 'Clinic settings saved successfully.')
            ->assertJsonPath('data.clinic_title', 'SmartDentQueue Dental Center')
            ->assertJsonPath('data.practice_license_id', 'SDQ-M-10294')
            ->assertJsonPath('data.operational_hotline', '+1 (555) 890-0123')
            ->assertJsonPath('data.clinic_headquarters', '1204 Dental Plaza, Medical District, Suite 405, Metro City, 10042')
            ->assertJsonPath('data.opening_time', '10:00')
            ->assertJsonPath('data.closing_time', '15:00')
            ->assertJsonPath('data.working_days', ['Sunday', 'Tuesday', 'Saturday'])
            ->assertJsonPath('data.daily_operating_hours.Saturday.opening_time', '08:30')
            ->assertJsonPath('data.daily_operating_hours.Tuesday.closing_time', '16:00')
            ->assertJsonPath('data.updated_by_user_id', $admin->id);

        $this->assertDatabaseCount('clinic_settings', 1);

        $clinicSetting = ClinicSetting::query()->first();

        $this->assertNotNull($clinicSetting);
        $this->assertSame(['Sunday', 'Tuesday', 'Saturday'], $clinicSetting->working_days);
        $this->assertSame('10:00', (string) $clinicSetting->opening_time);
        $this->assertSame('15:00', (string) $clinicSetting->closing_time);
        $this->assertSame('08:30', $clinicSetting->daily_operating_hours['Saturday']['opening_time']);
        $this->assertSame('09:00', $clinicSetting->daily_operating_hours['Tuesday']['opening_time']);

        $getResponse = $this->getJson('/api/v1/admin/settings/clinic');

        $getResponse->assertOk()
            ->assertJsonPath('data.daily_operating_hours.Sunday.opening_time', '10:00')
            ->assertJsonPath('data.daily_operating_hours.Sunday.closing_time', '15:00')
            ->assertJsonPath('data.daily_operating_hours.Tuesday.opening_time', '09:00')
            ->assertJsonPath('data.daily_operating_hours.Tuesday.closing_time', '16:00')
            ->assertJsonPath('data.daily_operating_hours.Saturday.opening_time', '08:30')
            ->assertJsonPath('data.daily_operating_hours.Saturday.closing_time', '17:00');
    }

    public function test_invalid_per_day_time_combination_is_rejected(): void
    {
        $admin = $this->createUserWithRole('Admin');
        Sanctum::actingAs($admin);

        $response = $this->putJson('/api/v1/admin/settings/clinic', [
            'daily_operating_hours' => [
                'Monday' => [
                    'opening_time' => '10:00',
                    'closing_time' => '09:00',
                ],
            ],
        ]);

        $response->assertStatus(422)
            ->assertJsonValidationErrors(['daily_operating_hours.Monday.closing_time']);
    }

    public function test_at_least_one_working_day_must_be_selected(): void
    {
        $admin = $this->createUserWithRole('Admin');
        Sanctum::actingAs($admin);

        $response = $this->putJson('/api/v1/admin/settings/clinic', [
            'daily_operating_hours' => [],
        ]);

        $response->assertStatus(422)
            ->assertJsonPath(
                'errors.daily_operating_hours.0',
                'At least one working day must be selected.',
            );
    }

    public function test_saving_settings_updates_the_latest_clinic_settings_record(): void
    {
        $admin = $this->createUserWithRole('Admin');
        Sanctum::actingAs($admin);

        $olderSetting = ClinicSetting::query()->create([
            'clinic_title' => 'Old Clinic',
            'practice_license_id' => 'OLD-001',
            'operational_hotline' => '09170000000',
            'clinic_headquarters' => 'Old Headquarters',
            'opening_time' => '08:00',
            'closing_time' => '12:00',
            'working_days' => ['Monday'],
            'daily_operating_hours' => [
                'Monday' => ['opening_time' => '08:00', 'closing_time' => '12:00'],
            ],
            'updated_by_user_id' => null,
        ]);
        $latestSetting = ClinicSetting::query()->create([
            'clinic_title' => 'Latest Clinic',
            'practice_license_id' => 'LATEST-002',
            'operational_hotline' => '09171111111',
            'clinic_headquarters' => 'Latest Headquarters',
            'opening_time' => '09:00',
            'closing_time' => '15:00',
            'working_days' => ['Tuesday'],
            'daily_operating_hours' => [
                'Tuesday' => ['opening_time' => '09:00', 'closing_time' => '15:00'],
            ],
            'updated_by_user_id' => null,
        ]);

        $response = $this->putJson('/api/v1/admin/settings/clinic', [
            'clinic_title' => 'Updated Clinic',
            'practice_license_id' => 'UPDATED-003',
            'operational_hotline' => '09172222222',
            'clinic_headquarters' => 'Updated Headquarters',
            'daily_operating_hours' => [
                'Wednesday' => ['opening_time' => '10:00', 'closing_time' => '16:30'],
                'Friday' => ['opening_time' => '13:00', 'closing_time' => '17:00'],
            ],
        ]);

        $response->assertOk()
            ->assertJsonPath('data.clinic_title', 'Updated Clinic')
            ->assertJsonPath('data.opening_time', '10:00')
            ->assertJsonPath('data.closing_time', '16:30')
            ->assertJsonPath('data.working_days', ['Wednesday', 'Friday'])
            ->assertJsonPath('data.daily_operating_hours.Friday.opening_time', '13:00');

        $this->assertDatabaseCount('clinic_settings', 2);
        $this->assertDatabaseHas('clinic_settings', [
            'id' => (int) $olderSetting->id,
            'clinic_title' => 'Old Clinic',
        ]);
        $this->assertDatabaseHas('clinic_settings', [
            'id' => (int) $latestSetting->id,
            'clinic_title' => 'Updated Clinic',
            'opening_time' => '10:00',
            'closing_time' => '16:30',
        ]);

        $this->assertSame('Updated Clinic', $latestSetting->fresh()->clinic_title);
        $this->assertSame(['Wednesday', 'Friday'], $latestSetting->fresh()->working_days);
        $this->assertSame('13:00', $latestSetting->fresh()->daily_operating_hours['Friday']['opening_time']);
    }

    public function test_changing_day_hours_notifies_affected_patients(): void
    {
        $admin = $this->createUserWithRole('Admin');
        $pendingPatient = $this->createUserWithRole('Patient');
        $confirmedPatient = $this->createUserWithRole('Patient');
        $service = $this->createService();
        Sanctum::actingAs($admin);

        $targetDate = now()->next('Friday');
        $date = $targetDate->format('Y-m-d');

        ClinicSetting::query()->create([
            'opening_time' => '08:00',
            'closing_time' => '17:00',
            'working_days' => ['Friday'],
            'daily_operating_hours' => [
                'Friday' => ['opening_time' => '08:00', 'closing_time' => '17:00'],
            ],
        ]);

        $pendingAppointment = $this->createAppointment(
            PatientRecord::resolveForUser($pendingPatient)->id,
            $service->id,
            $date,
            '10:00',
            'pending',
        );
        $confirmedAppointment = $this->createAppointment(
            PatientRecord::resolveForUser($confirmedPatient)->id,
            $service->id,
            $date,
            '16:00',
            'confirmed',
        );

        $response = $this->putJson('/api/v1/admin/settings/clinic', [
            'daily_operating_hours' => [
                'Friday' => ['opening_time' => '13:00', 'closing_time' => '15:00'],
            ],
        ]);

        $response->assertOk()
            ->assertJsonPath('data.daily_operating_hours.Friday.opening_time', '13:00');

        $this->assertDatabaseHas('appointments', [
            'id' => (int) $pendingAppointment->id,
            'status' => 'reschedule_required',
        ]);
        $this->assertDatabaseHas('appointments', [
            'id' => (int) $confirmedAppointment->id,
            'status' => 'cancelled_by_doctor',
        ]);
        $this->assertDatabaseHas('patient_notifications', [
            'appointment_id' => (int) $pendingAppointment->id,
            'type' => 'appointment_reschedule_required',
            'title' => 'Appointment Needs Reschedule',
        ]);
        $this->assertDatabaseHas('patient_notifications', [
            'appointment_id' => (int) $confirmedAppointment->id,
            'type' => 'appointment_cancelled_by_doctor',
            'title' => 'Appointment Cancelled by Doctor',
        ]);

        $pendingNotification = PatientNotification::query()
            ->where('appointment_id', (int) $pendingAppointment->id)
            ->firstOrFail();
        $this->assertStringContainsString('clinic schedule changed', (string) $pendingNotification->message);
        $this->assertStringContainsString('Please contact the clinic to reschedule.', (string) $pendingNotification->message);

        $confirmedNotification = PatientNotification::query()
            ->where('appointment_id', (int) $confirmedAppointment->id)
            ->firstOrFail();
        $this->assertStringContainsString('follow-up on the cancellation', (string) $confirmedNotification->message);
    }

    public function test_staff_cannot_access_clinic_settings_api(): void
    {
        $staff = $this->createUserWithRole('Staff');
        Sanctum::actingAs($staff);

        $response = $this->getJson('/api/v1/admin/settings/clinic');

        $response->assertForbidden()
            ->assertJsonPath('message', 'You do not have permission to perform this action.');
    }

    private function createUserWithRole(string $roleName): User
    {
        $role = Role::firstOrCreate(['name' => $roleName]);
        $suffix = Str::lower($roleName) . '_' . Str::lower(Str::random(8));

        return User::create([
            'first_name' => $roleName,
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
            'description' => 'Clinic settings test service.',
            'is_active' => true,
        ]);
    }

    private function createAppointment(
        int $patientId,
        int $serviceId,
        string $date,
        string $timeSlot,
        string $status = 'pending',
    ): Appointment {
        return Appointment::create([
            'patient_id' => $patientId,
            'service_id' => $serviceId,
            'appointment_date' => $date,
            'time_slot' => $timeSlot,
            'status' => $status,
        ]);
    }
}
