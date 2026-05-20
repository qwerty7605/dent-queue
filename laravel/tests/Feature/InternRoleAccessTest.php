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
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class InternRoleAccessTest extends TestCase
{
    use RefreshDatabase;

    public function test_role_seeder_creates_intern_role(): void
    {
        $this->seed(\Database\Seeders\RoleSeeder::class);

        $this->assertDatabaseHas('roles', [
            'name' => 'Intern',
        ]);
    }

    public function test_intern_can_log_in_and_role_is_returned(): void
    {
        $intern = $this->createUserWithRole('Intern');

        $response = $this->postJson('/api/v1/auth/login', [
            'username' => $intern->username,
            'password' => 'password123',
        ]);

        $response->assertOk()
            ->assertJsonPath('user.id', $intern->id)
            ->assertJsonPath('user.role.name', 'Intern');
    }

    public function test_authenticated_intern_user_endpoint_returns_intern_role(): void
    {
        $intern = $this->createUserWithRole('Intern');

        Sanctum::actingAs($intern);

        $this->getJson('/api/v1/user')
            ->assertOk()
            ->assertJsonPath('id', $intern->id)
            ->assertJsonPath('role.name', 'Intern');
    }

    public function test_intern_is_forbidden_from_existing_patient_staff_and_admin_route_groups(): void
    {
        $intern = $this->createUserWithRole('Intern');

        Sanctum::actingAs($intern);

        $endpoints = [
            ['method' => 'getJson', 'uri' => '/api/v1/admin/patients'],
            ['method' => 'postJson', 'uri' => '/api/v1/admin/appointments', 'payload' => []],
            ['method' => 'postJson', 'uri' => '/api/v1/patient/appointments', 'payload' => []],
            ['method' => 'patchJson', 'uri' => '/api/v1/staff/profile/999', 'payload' => []],
        ];

        foreach ($endpoints as $endpoint) {
            $method = $endpoint['method'];
            $response = $this->{$method}($endpoint['uri'], $endpoint['payload'] ?? []);

            $response->assertForbidden()
                ->assertJsonPath('message', 'You do not have permission to perform this action.');
        }
    }

    public function test_intern_can_access_allowed_read_only_modules(): void
    {
        $intern = $this->createUserWithRole('Intern');
        Sanctum::actingAs($intern);

        $date = now()->format('Y-m-d');

        $allowedEndpoints = [
            ['uri' => '/api/v1/admin/dashboard/stats'],
            ['uri' => '/api/v1/admin/appointments?date=' . $date],
            ['uri' => '/api/v1/admin/appointments/master-list'],
            ['uri' => '/api/v1/admin/calendar/appointments?date=' . $date],
            ['uri' => '/api/v1/admin/queues/today?date=' . $date],
            ['uri' => '/api/v1/admin/reports/summary'],
            ['uri' => '/api/v1/admin/reports/trends?trend_type=daily'],
            ['uri' => '/api/v1/admin/reports/status-distribution'],
        ];

        foreach ($allowedEndpoints as $endpoint) {
            $this->getJson($endpoint['uri'])->assertOk();
        }
    }

    public function test_staff_and_intern_cannot_access_detailed_report_records(): void
    {
        foreach (['Staff', 'Intern'] as $roleName) {
            Sanctum::actingAs($this->createUserWithRole($roleName));

            $this->getJson('/api/v1/admin/reports')
                ->assertForbidden()
                ->assertJsonPath('message', 'You do not have permission to perform this action.');
        }
    }

    public function test_intern_read_only_appointment_modules_redact_sensitive_patient_details(): void
    {
        $intern = $this->createUserWithRole('Intern');
        $patient = $this->createUserWithRole('Patient');
        $patientRecord = PatientRecord::syncFromUser($patient);
        $patientRecord->update([
            'first_name' => 'Maria',
            'middle_name' => 'Santos',
            'last_name' => 'Reyes',
            'gender' => 'female',
            'address' => '123 Sensitive Street',
            'contact_number' => '09129998888',
            'birthdate' => '1990-05-15',
        ]);
        $service = Service::create([
            'name' => 'Dental Cleaning',
            'description' => 'Routine cleaning.',
            'is_active' => true,
        ]);
        $appointment = Appointment::create([
            'patient_id' => $patientRecord->id,
            'service_id' => $service->id,
            'appointment_date' => '2026-06-01',
            'time_slot' => '09:00',
            'status' => 'confirmed',
            'notes' => 'Patient disclosed private medical details.',
        ]);
        Queue::create([
            'appointment_id' => $appointment->id,
            'queue_date' => '2026-06-01',
            'queue_number' => 1,
            'is_called' => false,
        ]);

        Sanctum::actingAs($intern);

        $endpoints = [
            '/api/v1/admin/dashboard/stats',
            '/api/v1/admin/appointments?date=2026-06-01',
            '/api/v1/admin/appointments/master-list',
            '/api/v1/admin/calendar/appointments?date=2026-06-01',
            '/api/v1/admin/calendar/appointments/' . $appointment->id,
            '/api/v1/admin/queues/today?date=2026-06-01',
        ];

        foreach ($endpoints as $endpoint) {
            $response = $this->getJson($endpoint);

            $response->assertOk();
            $payload = $response->json();
            $encoded = json_encode($payload, JSON_THROW_ON_ERROR);

            $this->assertStringNotContainsString('Maria', $encoded);
            $this->assertStringNotContainsString('Santos', $encoded);
            $this->assertStringNotContainsString('Reyes', $encoded);
            $this->assertStringNotContainsString('09129998888', $encoded);
            $this->assertStringNotContainsString('123 Sensitive Street', $encoded);
            $this->assertStringNotContainsString('1990-05-15', $encoded);
            $this->assertStringNotContainsString('Patient disclosed private medical details.', $encoded);
            $this->assertFalse($this->payloadContainsKey($payload, 'patient_id'));
            $this->assertFalse($this->payloadContainsKey($payload, 'contact'));
            $this->assertFalse($this->payloadContainsKey($payload, 'contact_number'));
            $this->assertFalse($this->payloadContainsKey($payload, 'notes'));
            $this->assertFalse($this->payloadContainsKey($payload, 'logs'));
        }
    }

    public function test_intern_cannot_perform_write_actions_on_admin_modules(): void
    {
        $intern = $this->createUserWithRole('Intern');
        Sanctum::actingAs($intern);

        $writeEndpoints = [
            ['method' => 'postJson', 'uri' => '/api/v1/admin/appointments', 'payload' => []],
            ['method' => 'postJson', 'uri' => '/api/v1/admin/appointments/walk-in', 'payload' => []],
            ['method' => 'postJson', 'uri' => '/api/v1/admin/appointments/follow-up', 'payload' => []],
            ['method' => 'patchJson', 'uri' => '/api/v1/admin/appointments/1/restore', 'payload' => []],
            ['method' => 'postJson', 'uri' => '/api/v1/admin/queues/call-next', 'payload' => []],
            ['method' => 'postJson', 'uri' => '/api/v1/admin/staff', 'payload' => []],
            ['method' => 'putJson', 'uri' => '/api/v1/admin/settings/clinic', 'payload' => []],
        ];

        foreach ($writeEndpoints as $endpoint) {
            $method = $endpoint['method'];

            $response = $this->{$method}($endpoint['uri'], $endpoint['payload']);

            $response->assertForbidden();
            $this->assertContains(
                data_get($response->json(), 'message'),
                [
                    'Intern accounts have read-only access.',
                    'You do not have permission to perform this action.',
                ],
            );
        }
    }

    private function createUserWithRole(string $roleName): User
    {
        $role = Role::firstOrCreate(['name' => $roleName]);

        return User::create([
            'first_name' => $roleName,
            'last_name' => 'User',
            'username' => strtolower($roleName) . '_tester',
            'email' => strtolower($roleName) . '@example.com',
            'password' => Hash::make('password123'),
            'role_id' => $role->id,
            'is_active' => true,
        ]);
    }

    private function payloadContainsKey(mixed $payload, string $needle): bool
    {
        if (!is_array($payload)) {
            return false;
        }

        foreach ($payload as $key => $value) {
            if ($key === $needle) {
                return true;
            }

            if ($this->payloadContainsKey($value, $needle)) {
                return true;
            }
        }

        return false;
    }
}
