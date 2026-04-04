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

class AdminReportsCsvExportTest extends TestCase
{
    use RefreshDatabase;

    public function test_admin_can_export_report_records_as_csv(): void
    {
        $admin = $this->createReportFixture();
        Sanctum::actingAs($admin);

        $response = $this->get('/api/v1/admin/reports/export');

        $response->assertOk();
        $response->assertHeader('content-type', 'text/csv; charset=UTF-8');
        $this->assertStringContainsString(
            'attachment; filename=report-records-',
            (string) $response->headers->get('content-disposition'),
        );

        $csv = $response->streamedContent();
        $rows = array_map('str_getcsv', preg_split("/\r\n|\n|\r/", trim($csv)));

        $this->assertSame([
            'Appointment ID',
            'Patient Name',
            'Service Type',
            'Appointment Date',
            'Appointment Time',
            'Status',
            'Booking Type',
            'Queue Number',
            'Created At',
        ], $rows[0]);

        $this->assertSame('1', $rows[1][0]);
        $this->assertSame('Patient User', $rows[1][1]);
        $this->assertSame('Dental Cleaning', $rows[1][2]);
        $this->assertSame('2026-04-03', $rows[1][3]);
        $this->assertSame('9:30 AM', $rows[1][4]);
        $this->assertSame('Approved', $rows[1][5]);
        $this->assertSame('Online Booking', $rows[1][6]);
        $this->assertSame('03', $rows[1][7]);
        $this->assertSame('2026-04-01 07:45:00', $rows[1][8]);

        $this->assertSame('2', $rows[2][0]);
        $this->assertSame('Walk In', $rows[2][1]);
        $this->assertSame('Root Canal', $rows[2][2]);
        $this->assertSame('2026-04-07', $rows[2][3]);
        $this->assertSame('11:15 AM', $rows[2][4]);
        $this->assertSame('Cancelled', $rows[2][5]);
        $this->assertSame('Walk-In Booking', $rows[2][6]);
        $this->assertSame('08', $rows[2][7]);
        $this->assertSame('2026-04-02 08:00:00', $rows[2][8]);
    }

    public function test_admin_can_export_report_records_as_excel(): void
    {
        $admin = $this->createReportFixture();
        Sanctum::actingAs($admin);

        $response = $this->get('/api/v1/admin/reports/export?format=excel');

        $response->assertOk();
        $response->assertHeader('content-type', 'application/vnd.ms-excel; charset=UTF-8');
        $this->assertStringContainsString(
            'attachment; filename="report-records-',
            (string) $response->headers->get('content-disposition'),
        );

        $content = $response->getContent();

        $this->assertIsString($content);
        $this->assertStringContainsString('<?xml version="1.0" encoding="UTF-8"?>', $content);
        $this->assertStringContainsString('<Worksheet ss:Name="Reports">', $content);
        $this->assertStringContainsString('<Data ss:Type="String">Patient User</Data>', $content);
        $this->assertStringContainsString('<Data ss:Type="String">Walk In</Data>', $content);
    }

    public function test_admin_can_export_report_records_as_pdf(): void
    {
        $admin = $this->createReportFixture();
        Sanctum::actingAs($admin);

        $response = $this->get('/api/v1/admin/reports/export?format=pdf');

        $response->assertOk();
        $response->assertHeader('content-type', 'application/pdf');
        $this->assertStringContainsString(
            'attachment; filename="report-records-',
            (string) $response->headers->get('content-disposition'),
        );

        $content = $response->getContent();

        $this->assertIsString($content);
        $this->assertStringStartsWith('%PDF-1.4', $content);
        $this->assertStringContainsString('/Type /Catalog', $content);
        $this->assertStringContainsString('Detailed Reports Export', $content);
    }

    public function test_export_respects_active_report_filters(): void
    {
        $admin = $this->createReportFixture();
        Sanctum::actingAs($admin);

        $response = $this->get(
            '/api/v1/admin/reports/export?'.http_build_query([
                'status' => 'Approved',
                'booking_type' => 'Online Booking',
            ]),
        );

        $rows = array_map(
            'str_getcsv',
            preg_split("/\r\n|\n|\r/", trim($response->streamedContent())),
        );

        $this->assertCount(2, $rows);
        $this->assertSame('1', $rows[1][0]);
        $this->assertSame('Approved', $rows[1][5]);
        $this->assertSame('Online Booking', $rows[1][6]);
    }

    public function test_export_respects_date_range_status_and_booking_type_filters(): void
    {
        $admin = $this->createReportFixture();
        Sanctum::actingAs($admin);

        $response = $this->get(
            '/api/v1/admin/reports/export?'.http_build_query([
                'start_date' => '2026-04-02',
                'end_date' => '2026-04-04',
                'status' => 'Approved',
                'booking_type' => 'Online Booking',
            ]),
        );

        $rows = array_map(
            'str_getcsv',
            preg_split("/\r\n|\n|\r/", trim($response->streamedContent())),
        );

        $this->assertCount(2, $rows);
        $this->assertSame('1', $rows[1][0]);
        $this->assertSame('2026-04-03', $rows[1][3]);
        $this->assertSame('Approved', $rows[1][5]);
        $this->assertSame('Online Booking', $rows[1][6]);
    }

    public function test_export_with_no_matching_rows_returns_header_only_csv(): void
    {
        $admin = $this->createReportFixture();
        Sanctum::actingAs($admin);

        $response = $this->get(
            '/api/v1/admin/reports/export?'.http_build_query([
                'status' => 'Completed',
                'booking_type' => 'Online Booking',
            ]),
        );

        $lines = array_filter(
            preg_split("/\r\n|\n|\r/", $response->streamedContent()),
            static fn (?string $line): bool => $line !== null && $line !== '',
        );

        $this->assertCount(1, $lines);
        $this->assertSame([
            'Appointment ID',
            'Patient Name',
            'Service Type',
            'Appointment Date',
            'Appointment Time',
            'Status',
            'Booking Type',
            'Queue Number',
            'Created At',
        ], str_getcsv(array_values($lines)[0]));
    }

    public function test_non_admin_roles_cannot_export_report_csv(): void
    {
        $roles = ['Patient', 'Staff', 'Intern'];

        foreach ($roles as $roleName) {
            $user = $this->createUserWithRole($roleName);
            Sanctum::actingAs($user);

            $response = $this->getJson('/api/v1/admin/reports/export');

            $response->assertForbidden();
        }
    }

    private function createReportFixture(): User
    {
        $admin = $this->createUserWithRole('Admin');
        $patientUser = $this->createUserWithRole('Patient');
        $walkInPatient = PatientRecord::create([
            'first_name' => 'Walk',
            'middle_name' => null,
            'last_name' => "In\n",
            'gender' => 'other',
            'address' => 'Clinic Street',
            'contact_number' => '09123456780',
            'birthdate' => '1992-01-15',
            'user_id' => null,
        ]);

        $cleaningService = Service::create([
            'name' => 'Dental Cleaning',
            'is_active' => true,
        ]);
        $rootCanalService = Service::create([
            'name' => "Root Canal\t",
            'is_active' => true,
        ]);

        $onlineAppointment = Appointment::create([
            'patient_id' => $patientUser->patientRecord->id,
            'service_id' => $cleaningService->id,
            'appointment_date' => '2026-04-03',
            'time_slot' => '09:30:00',
            'status' => 'confirmed',
            'notes' => null,
        ]);
        $onlineAppointment->forceFill([
            'created_at' => '2026-04-01 07:45:00',
            'updated_at' => '2026-04-01 07:45:00',
        ])->saveQuietly();

        $walkInAppointment = Appointment::create([
            'patient_id' => $walkInPatient->id,
            'service_id' => $rootCanalService->id,
            'appointment_date' => '2026-04-07',
            'time_slot' => '11:15:00',
            'status' => 'cancelled',
            'notes' => "Walk-In Patient\rNeeds follow-up",
        ]);
        $walkInAppointment->forceFill([
            'created_at' => '2026-04-02 08:00:00',
            'updated_at' => '2026-04-02 08:00:00',
        ])->saveQuietly();

        Queue::create([
            'appointment_id' => $onlineAppointment->id,
            'queue_number' => 3,
            'queue_date' => '2026-04-03',
            'status' => 'waiting',
        ]);

        Queue::create([
            'appointment_id' => $walkInAppointment->id,
            'queue_number' => 8,
            'queue_date' => '2026-04-07',
            'status' => 'waiting',
        ]);

        return $admin;
    }

    private function createUserWithRole(string $roleName): User
    {
        $role = Role::firstOrCreate(['name' => $roleName]);

        return User::create([
            'first_name' => $roleName,
            'last_name' => 'User',
            'username' => strtolower($roleName).'_'.str()->random(6),
            'email' => strtolower($roleName).'_'.str()->random(6).'@example.com',
            'password' => Hash::make('password123'),
            'role_id' => $role->id,
            'is_active' => true,
        ]);
    }
}
