<?php

namespace Tests\Feature;

use App\Models\DoctorUnavailability;
use App\Models\Role;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Str;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class DoctorAvailabilityApiTest extends TestCase
{
    use RefreshDatabase;

    public function test_admin_can_manage_doctor_unavailability_ranges(): void
    {
        $admin = $this->createUserWithRole('Admin');
        Sanctum::actingAs($admin);

        $create = $this->postJson('/api/v1/admin/settings/doctor-unavailability', [
            'unavailable_date' => '2026-05-12',
            'start_time' => '12:00',
            'end_time' => '17:00',
            'reason' => 'Afternoon only unavailable',
        ]);

        $create->assertCreated();

        $schedule = DoctorUnavailability::query()->firstOrFail();

        $this->getJson('/api/v1/admin/settings/doctor-unavailability')
            ->assertOk()
            ->assertJsonPath('data.0.unavailable_date', '2026-05-12')
            ->assertJsonPath('data.0.start_time', '12:00')
            ->assertJsonPath('data.0.end_time', '17:00')
            ->assertJsonPath('data.0.reason', 'Afternoon only unavailable');

        $this->deleteJson('/api/v1/admin/settings/doctor-unavailability/' . $schedule->id)
            ->assertOk()
            ->assertJsonPath('message', 'Doctor unavailability removed successfully.');

        $this->assertDatabaseCount('doctor_unavailabilities', 0);
    }

    public function test_slot_availability_api_marks_doctor_unavailable_and_available_ranges(): void
    {
        $patient = $this->createUserWithRole('Patient');
        $date = now()->addDays(30)->format('Y-m-d');
        Sanctum::actingAs($patient);

        DoctorUnavailability::create([
            'unavailable_date' => $date,
            'start_time' => '07:30',
            'end_time' => '12:00',
            'reason' => 'Morning only availability starts after lunch',
        ]);

        $response = $this->getJson('/api/v1/availability/slots?date=' . $date);

        $response->assertOk()
            ->assertJsonPath('data.date', $date)
            ->assertJsonPath('data.unavailable_ranges.0.reason', 'Morning only availability starts after lunch');

        $slots = $response->json('data.slots', []);

        $this->assertIsArray($slots);
        $this->assertSame(30, $response->json('data.slot_duration_minutes'));
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
