<?php

namespace Tests\Feature;

use App\Models\Appointment;
use App\Models\PatientRecord;
use App\Models\Role;
use App\Models\Service;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Str;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class AdminReportFilteringApiTest extends TestCase
{
    use RefreshDatabase;

    public function test_reports_summary_supports_date_range_filtering(): void
    {
        $admin = $this->createFilteringFixture();
        Sanctum::actingAs($admin);

        $response = $this->getJson(
            '/api/v1/admin/reports/summary?' . http_build_query([
                'start_date' => '2026-04-02',
                'end_date' => '2026-04-07',
            ]),
        );

        $response->assertOk()->assertExactJson([
            'data' => [
                'total_appointments' => 3,
                'pending_count' => 0,
                'approved_count' => 1,
                'completed_count' => 1,
                'cancelled_count' => 1,
            ],
        ]);
    }

    public function test_reports_trends_support_status_filtering(): void
    {
        $admin = $this->createFilteringFixture();
        Sanctum::actingAs($admin);

        $response = $this->getJson(
            '/api/v1/admin/reports/trends?' . http_build_query([
                'trend_type' => 'daily',
                'status' => 'Pending',
            ]),
        );

        $response->assertOk()->assertExactJson([
            'data' => [
                ['trend_type' => 'daily', 'label' => '2026-04-01', 'count' => 1],
                ['trend_type' => 'daily', 'label' => '2026-04-09', 'count' => 1],
            ],
        ]);
    }

    public function test_master_list_supports_booking_type_filtering(): void
    {
        $admin = $this->createFilteringFixture();
        Sanctum::actingAs($admin);

        $response = $this->getJson(
            '/api/v1/admin/appointments/master-list?' . http_build_query([
                'booking_type' => 'Walk-In Booking',
            ]),
        );

        $response->assertOk()->assertJsonCount(2, 'data');

        $data = $response->json('data');

        $this->assertSame('2026-04-07', $data[0]['date']);
        $this->assertSame('2026-04-05', $data[1]['date']);
        $this->assertSame('Walk-In Booking', $data[0]['booking_type']);
        $this->assertSame('Walk-In Booking', $data[1]['booking_type']);
        $this->assertSame('Cancelled', $data[0]['status']);
        $this->assertSame('Completed', $data[1]['status']);
    }

    public function test_combined_filters_apply_consistently_across_report_endpoints(): void
    {
        $admin = $this->createFilteringFixture();
        Sanctum::actingAs($admin);

        $filters = http_build_query([
            'start_date' => '2026-04-04',
            'end_date' => '2026-04-06',
            'status' => 'Completed',
            'booking_type' => 'Walk-In Booking',
        ]);

        $summaryResponse = $this->getJson('/api/v1/admin/reports/summary?' . $filters);
        $summaryResponse->assertOk()->assertExactJson([
            'data' => [
                'total_appointments' => 1,
                'pending_count' => 0,
                'approved_count' => 0,
                'completed_count' => 1,
                'cancelled_count' => 0,
            ],
        ]);

        $distributionResponse = $this->getJson(
            '/api/v1/admin/reports/status-distribution?' . $filters,
        );
        $distributionResponse->assertOk()->assertExactJson([
            'data' => [
                ['status' => 'pending', 'count' => 0],
                ['status' => 'approved', 'count' => 0],
                ['status' => 'completed', 'count' => 1],
                ['status' => 'cancelled', 'count' => 0],
            ],
        ]);

        $trendResponse = $this->getJson(
            '/api/v1/admin/reports/trends?' . $filters . '&trend_type=daily',
        );
        $trendResponse->assertOk()->assertExactJson([
            'data' => [
                ['trend_type' => 'daily', 'label' => '2026-04-05', 'count' => 1],
            ],
        ]);

        $masterListResponse = $this->getJson(
            '/api/v1/admin/appointments/master-list?' . $filters,
        );
        $masterListResponse->assertOk()->assertJsonCount(1, 'data');

        $record = $masterListResponse->json('data.0');
        $this->assertSame('2026-04-05', $record['date']);
        $this->assertSame('Completed', $record['status']);
        $this->assertSame('Walk-In Booking', $record['booking_type']);
    }

    public function test_filtered_report_endpoints_handle_empty_results_safely(): void
    {
        $admin = $this->createFilteringFixture();
        Sanctum::actingAs($admin);

        $filters = http_build_query([
            'start_date' => '2026-04-01',
            'end_date' => '2026-04-02',
            'status' => 'Cancelled',
            'booking_type' => 'Online Booking',
        ]);

        $summaryResponse = $this->getJson('/api/v1/admin/reports/summary?' . $filters);
        $summaryResponse->assertOk()->assertExactJson([
            'data' => [
                'total_appointments' => 0,
                'pending_count' => 0,
                'approved_count' => 0,
                'completed_count' => 0,
                'cancelled_count' => 0,
            ],
        ]);

        $distributionResponse = $this->getJson(
            '/api/v1/admin/reports/status-distribution?' . $filters,
        );
        $distributionResponse->assertOk()->assertExactJson([
            'data' => [
                ['status' => 'pending', 'count' => 0],
                ['status' => 'approved', 'count' => 0],
                ['status' => 'completed', 'count' => 0],
                ['status' => 'cancelled', 'count' => 0],
            ],
        ]);

        $trendResponse = $this->getJson(
            '/api/v1/admin/reports/trends?' . $filters . '&trend_type=daily',
        );
        $trendResponse->assertOk()->assertExactJson([
            'data' => [],
        ]);

        $masterListResponse = $this->getJson(
            '/api/v1/admin/appointments/master-list?' . $filters,
        );
        $masterListResponse->assertOk()->assertExactJson([
            'data' => [],
        ]);
    }

    private function createFilteringFixture(): User
    {
        $admin = $this->createUserWithRole('Admin');
        $onlinePatient = $this->createUserWithRole('Patient');
        $walkInPatient = PatientRecord::create([
            'first_name' => 'Walk',
            'middle_name' => null,
            'last_name' => 'In',
            'gender' => 'other',
            'address' => 'Clinic Street',
            'contact_number' => '09123456780',
            'birthdate' => '1992-01-15',
            'user_id' => null,
        ]);
        $service = Service::create([
            'name' => 'General Checkup',
            'is_active' => true,
        ]);

        $this->createAppointment(
            $onlinePatient->patientRecord,
            $service,
            '2026-04-01',
            '08:00',
            'pending',
        );
        $this->createAppointment(
            $onlinePatient->patientRecord,
            $service,
            '2026-04-03',
            '09:00',
            'confirmed',
        );
        $this->createAppointment(
            $walkInPatient,
            $service,
            '2026-04-05',
            '10:00',
            'completed',
            'Walk-In Patient',
        );
        $this->createAppointment(
            $walkInPatient,
            $service,
            '2026-04-07',
            '11:00',
            'cancelled',
            'Walk-In Patient',
        );
        $this->createAppointment(
            $onlinePatient->patientRecord,
            $service,
            '2026-04-09',
            '12:00',
            'pending',
        );

        return $admin;
    }

    private function createAppointment(
        PatientRecord $patientRecord,
        Service $service,
        string $date,
        string $time,
        string $status,
        ?string $notes = null,
    ): Appointment {
        return Appointment::create([
            'patient_id' => (int) $patientRecord->id,
            'service_id' => (int) $service->id,
            'appointment_date' => $date,
            'time_slot' => $time,
            'status' => $status,
            'notes' => $notes,
        ]);
    }

    private function createUserWithRole(string $roleName): User
    {
        $role = Role::firstOrCreate(['name' => $roleName]);
        $suffix = Str::lower($roleName) . '_' . Str::lower(Str::random(8));

        $user = User::create([
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

        if ($roleName === 'Patient') {
            PatientRecord::syncFromUser($user);
            $user->load('patientRecord');
        }

        return $user;
    }
}
