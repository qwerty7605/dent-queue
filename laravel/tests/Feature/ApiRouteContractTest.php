<?php

namespace Tests\Feature;

use App\Models\Appointment;
use App\Models\DoctorUnavailability;
use App\Models\PatientNotification;
use App\Models\PatientRecord;
use App\Models\Role;
use App\Models\Service;
use App\Models\StaffNotification;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Routing\Route;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Route as RouteFacade;
use Illuminate\Support\Str;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class ApiRouteContractTest extends TestCase
{
    use RefreshDatabase;

    private array $routeParameterIds = [];

    public function test_protected_api_endpoints_require_authentication(): void
    {
        foreach ($this->protectedRoutes() as $route) {
            [$method, $uri] = $this->routeRequest($route);

            $this->json($method, $uri)->assertUnauthorized();
        }
    }

    public function test_role_protected_api_endpoints_reject_disallowed_roles(): void
    {
        foreach ($this->roleProtectedRoutes() as $route) {
            [$method, $uri, $allowedRoles] = $this->routeRequest($route);
            Sanctum::actingAs($this->createUserWithRole($this->disallowedRoleFor($allowedRoles)));

            $this->json($method, $uri)->assertForbidden();
        }
    }

    public function test_authenticated_api_endpoints_reach_controller_layer(): void
    {
        foreach ($this->protectedRoutes() as $route) {
            [$method, $uri, $allowedRoles] = $this->routeRequest($route);
            Sanctum::actingAs($this->createUserWithRole($allowedRoles[0] ?? 'Patient'));

            $response = $this->json($method, $uri);

            $this->assertNotSame(
                401,
                $response->getStatusCode(),
                sprintf('%s %s did not pass authentication.', $method, $uri),
            );
        }
    }

    private function protectedRoutes()
    {
        return $this->apiRoutes()
            ->filter(fn (Route $route): bool => in_array('auth:sanctum', $route->gatherMiddleware(), true));
    }

    private function roleProtectedRoutes()
    {
        return $this->apiRoutes()
            ->filter(fn (Route $route): bool => self::rolesForRoute($route) !== []);
    }

    private function apiRoutes()
    {
        return collect(RouteFacade::getRoutes())
            ->filter(fn (Route $route): bool => str_starts_with($route->uri(), 'api/v1/'));
    }

    /**
     * @return array{string, string, list<string>}
     */
    private function routeRequest(Route $route): array
    {
        return [
            self::primaryHttpMethod($route),
            $this->concreteUri($route->uri()),
            self::rolesForRoute($route),
        ];
    }

    private static function primaryHttpMethod(Route $route): string
    {
        return collect($route->methods())
            ->reject(fn (string $method): bool => $method === 'HEAD')
            ->first();
    }

    private function concreteUri(string $uri): string
    {
        return '/' . preg_replace_callback(
            '/\{([^}]+)\}/',
            fn (array $matches): string => (string) $this->routeParameterId($uri, $matches[1]),
            $uri,
        );
    }

    private function routeParameterId(string $uri, string $parameter): int
    {
        $parameter = trim($parameter, '?');

        if ($parameter === 'appointment') {
            return $this->routeFixtureIds()['appointment'];
        }

        if ($parameter === 'id' && str_contains($uri, '/appointments/')) {
            return $this->routeFixtureIds()['appointment'];
        }

        if ($parameter === 'id' && str_contains($uri, '/patient/profile/')) {
            return $this->routeFixtureIds()['patient_user'];
        }

        if ($parameter === 'id' && str_contains($uri, '/staff/profile/')) {
            return $this->routeFixtureIds()['staff_user'];
        }

        if ($parameter === 'notification' && str_contains($uri, '/staff/')) {
            return $this->routeFixtureIds()['staff_notification'];
        }

        if ($parameter === 'notification') {
            return $this->routeFixtureIds()['patient_notification'];
        }

        if ($parameter === 'patientId') {
            return $this->routeFixtureIds()['patient_record'];
        }

        if ($parameter === 'service') {
            return $this->routeFixtureIds()['service'];
        }

        if ($parameter === 'staff') {
            return $this->routeFixtureIds()['staff_user'];
        }

        if ($parameter === 'doctorUnavailability') {
            return $this->routeFixtureIds()['doctor_unavailability'];
        }

        return 999999;
    }

    /**
     * @return array<string, int>
     */
    private function routeFixtureIds(): array
    {
        if ($this->routeParameterIds !== []) {
            return $this->routeParameterIds;
        }

        $patient = $this->createUserWithRole('Patient');
        $staff = $this->createUserWithRole('Staff');
        $admin = $this->createUserWithRole('Admin');
        $patientRecord = PatientRecord::resolveForUser($patient);
        $service = Service::create([
            'name' => 'Contract Check-up',
            'description' => 'Contract route fixture',
            'is_active' => true,
        ]);
        $appointment = Appointment::create([
            'patient_id' => $patientRecord->id,
            'service_id' => $service->id,
            'appointment_date' => now()->next('Monday')->format('Y-m-d'),
            'time_slot' => '09:00',
            'status' => 'approved',
        ]);
        $doctorUnavailability = DoctorUnavailability::create([
            'unavailable_date' => now()->next('Tuesday')->format('Y-m-d'),
            'start_time' => '13:00',
            'end_time' => '14:00',
            'reason' => 'Contract fixture',
            'created_by_user_id' => $admin->id,
        ]);
        $patientNotification = PatientNotification::create([
            'patient_id' => $patientRecord->id,
            'appointment_id' => $appointment->id,
            'type' => 'contract',
            'title' => 'Contract fixture',
            'message' => 'Patient notification fixture',
        ]);
        $staffNotification = StaffNotification::create([
            'user_id' => $staff->id,
            'appointment_id' => $appointment->id,
            'type' => 'contract',
            'title' => 'Contract fixture',
            'message' => 'Staff notification fixture',
        ]);

        return $this->routeParameterIds = [
            'appointment' => (int) $appointment->id,
            'doctor_unavailability' => (int) $doctorUnavailability->id,
            'patient_notification' => (int) $patientNotification->id,
            'patient_record' => (int) $patientRecord->id,
            'patient_user' => (int) $patient->id,
            'service' => (int) $service->id,
            'staff_notification' => (int) $staffNotification->id,
            'staff_user' => (int) $staff->id,
        ];
    }

    /**
     * @return list<string>
     */
    private static function rolesForRoute(Route $route): array
    {
        foreach ($route->gatherMiddleware() as $middleware) {
            if (! str_starts_with($middleware, 'role:')) {
                continue;
            }

            return array_values(array_filter(explode(',', substr($middleware, 5))));
        }

        return [];
    }

    /**
     * @param list<string> $allowedRoles
     */
    private function disallowedRoleFor(array $allowedRoles): string
    {
        $normalizedAllowedRoles = array_map('strtolower', $allowedRoles);

        foreach (['Patient', 'Staff', 'Intern', 'Admin'] as $role) {
            if (! in_array(strtolower($role), $normalizedAllowedRoles, true)) {
                return $role;
            }
        }

        return 'Patient';
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
            'role_id' => $role->id,
            'phone_number' => '09171234567',
            'location' => 'Test City',
            'gender' => 'other',
            'is_active' => true,
        ]);
    }
}
