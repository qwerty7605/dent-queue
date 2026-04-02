<?php

namespace Tests\Feature;

use App\Models\ClinicSetting;
use App\Models\Role;
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
            ->assertJsonPath('data.opening_time', null)
            ->assertJsonPath('data.closing_time', null)
            ->assertJsonPath('data.working_days', [])
            ->assertJsonPath('data.updated_by_user_id', null)
            ->assertJsonPath('data.updated_at', null);
    }

    public function test_admin_can_save_and_retrieve_clinic_settings(): void
    {
        $admin = $this->createUserWithRole('Admin');
        Sanctum::actingAs($admin);

        $payload = [
            'opening_time' => '08:30',
            'closing_time' => '17:00',
            'working_days' => ['Saturday', 'Tuesday', 'Sunday'],
        ];

        $saveResponse = $this->putJson('/api/v1/admin/settings/clinic', $payload);

        $saveResponse->assertOk()
            ->assertJsonPath('message', 'Clinic settings saved successfully.')
            ->assertJsonPath('data.opening_time', '08:30')
            ->assertJsonPath('data.closing_time', '17:00')
            ->assertJsonPath('data.working_days', ['Sunday', 'Tuesday', 'Saturday'])
            ->assertJsonPath('data.updated_by_user_id', $admin->id);

        $this->assertDatabaseCount('clinic_settings', 1);

        $clinicSetting = ClinicSetting::query()->first();

        $this->assertNotNull($clinicSetting);
        $this->assertSame('08:30', (string) $clinicSetting->opening_time);
        $this->assertSame('17:00', (string) $clinicSetting->closing_time);
        $this->assertSame(['Sunday', 'Tuesday', 'Saturday'], $clinicSetting->working_days);

        $getResponse = $this->getJson('/api/v1/admin/settings/clinic');

        $getResponse->assertOk()
            ->assertJsonPath('data.opening_time', '08:30')
            ->assertJsonPath('data.closing_time', '17:00')
            ->assertJsonPath('data.working_days', ['Sunday', 'Tuesday', 'Saturday'])
            ->assertJsonPath('data.updated_by_user_id', $admin->id);
    }

    public function test_invalid_time_combination_is_rejected(): void
    {
        $admin = $this->createUserWithRole('Admin');
        Sanctum::actingAs($admin);

        $response = $this->putJson('/api/v1/admin/settings/clinic', [
            'opening_time' => '10:00',
            'closing_time' => '09:00',
            'working_days' => ['Monday'],
        ]);

        $response->assertStatus(422)
            ->assertJsonPath(
                'errors.closing_time.0',
                'Closing time must be later than opening time.',
            );
    }

    public function test_at_least_one_working_day_must_be_selected(): void
    {
        $admin = $this->createUserWithRole('Admin');
        Sanctum::actingAs($admin);

        $response = $this->putJson('/api/v1/admin/settings/clinic', [
            'opening_time' => '08:00',
            'closing_time' => '17:00',
            'working_days' => [],
        ]);

        $response->assertStatus(422)
            ->assertJsonPath(
                'errors.working_days.0',
                'At least one working day must be selected.',
            );
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
}
