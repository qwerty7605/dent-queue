<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Api\Concerns\InteractsWithReportFilters;
use App\Http\Controllers\Controller;
use App\Models\Appointment;
use App\Models\PatientRecord;
use App\Models\Report;
use App\Models\StaffRecord;
use App\Models\User;
use App\Services\ReportService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;
use Illuminate\Validation\Rule;

class AdminDashboardController extends Controller
{
    use InteractsWithReportFilters;

    /**
     * Get real-time stats for the admin dashboard.
     *
     * @return \Illuminate\Http\JsonResponse
     */
    public function stats(): JsonResponse
    {
        $stats = $this->resolveDashboardStats();

        return response()->json([
            'data' => $stats,
        ]);
    }

    private function resolveDashboardStats(): array
    {
        $totalUsersCount = User::query()->count();
        $patientUsersCount = $this->activeUsersWithRoles(['patient']);
        $patientRecordsCount = PatientRecord::query()->count();
        $patientAccounts = $patientUsersCount > 0
            ? $patientUsersCount
            : $patientRecordsCount;

        $adminUsersCount = $this->activeUsersWithRoles(['admin']);
        $staffUsersCount = $this->activeUsersWithRoles(['staff']);
        $internUsersCount = $this->activeUsersWithRoles(['intern']);
        $staffRecordsCount = StaffRecord::query()->count();
        $staffRegistry = ($adminUsersCount + $staffUsersCount + $internUsersCount) > 0
            ? $adminUsersCount + $staffUsersCount + $internUsersCount
            : $staffRecordsCount;

        $appointmentsCount = Appointment::withTrashed()->count();
        $reportsCount = Report::query()->count();
        $recentPendingAppointments = $this->recentPendingAppointments();

        Log::info('Admin dashboard stats resolved.', [
            'database_name' => DB::connection()->getDatabaseName(),
            'total_users_count' => $totalUsersCount,
            'patient_users_count' => $patientUsersCount,
            'patient_records_count' => $patientRecordsCount,
            'staff_users_count' => $staffUsersCount,
            'admin_users_count' => $adminUsersCount,
            'intern_users_count' => $internUsersCount,
            'staff_records_count' => $staffRecordsCount,
            'appointments_count' => $appointmentsCount,
            'reports_count' => $reportsCount,
            'recent_pending_appointments_count' => count($recentPendingAppointments),
        ]);

        return [
            'patient_accounts' => $patientAccounts,
            'staff_registry' => $staffRegistry,
            'appointments' => $appointmentsCount,
            'reports' => $reportsCount,
            'recent_pending_appointments' => $recentPendingAppointments,
            'patients_count' => $patientAccounts,
            'staff_count' => $staffUsersCount,
            'admin_count' => $adminUsersCount,
            'intern_count' => $internUsersCount,
            'staff_accounts_count' => $staffRegistry,
            'appointments_count' => $appointmentsCount,
            'reports_count' => $reportsCount,
        ];
    }

    private function activeUsersWithRoles(array $roles): int
    {
        return User::query()
            ->where('is_active', true)
            ->whereHas('role', function ($query) use ($roles): void {
                $query->whereIn(DB::raw('LOWER(name)'), $roles);
            })
            ->count();
    }

    private function recentPendingAppointments(): array
    {
        return Appointment::query()
            ->with(['patient', 'service', 'services', 'queue'])
            ->where('status', 'pending')
            ->latest('created_at')
            ->limit(10)
            ->get()
            ->map(function (Appointment $appointment): array {
                $patient = $appointment->patient;
                $patientName = trim(sprintf(
                    '%s %s',
                    (string) ($patient?->first_name ?? ''),
                    (string) ($patient?->last_name ?? ''),
                ));

                return [
                    'appointment_id' => (int) $appointment->id,
                    'patient_id' => $patient?->patient_id,
                    'patient_name' => $patientName !== '' ? $patientName : 'Unknown Patient',
                    'service' => $appointment->serviceSummary(),
                    'service_type' => $appointment->serviceSummary(),
                    'date' => (string) $appointment->appointment_date,
                    'appointment_date' => (string) $appointment->appointment_date,
                    'appointment_time' => (string) $appointment->time_slot,
                    'contact' => (string) ($patient?->contact_number ?? ''),
                    'status' => 'Pending',
                    'queue_number' => $appointment->queue?->queue_number
                        ? str_pad((string) $appointment->queue->queue_number, 2, '0', STR_PAD_LEFT)
                        : '-',
                    'created_at' => optional($appointment->created_at)->format('Y-m-d H:i:s'),
                ];
            })
            ->values()
            ->all();
    }

    /**
     * Get summary counts for the reports dashboard.
     *
     * @return \Illuminate\Http\JsonResponse
     */
    public function reportSummary(Request $request, ReportService $reportService): JsonResponse
    {
        $filters = $this->validateReportFilters($request);
        $summary = $reportService->getReportSummary(
            $filters,
            $request->boolean('force_refresh'),
        );

        return response()->json([
            'data' => $summary,
        ]);
    }

    /**
     * Get grouped counts by status for the distribution chart.
     *
     * @return \Illuminate\Http\JsonResponse
     */
    public function statusDistribution(Request $request, ReportService $reportService): JsonResponse
    {
        $filters = $this->validateReportFilters($request);

        return response()->json([
            'data' => $reportService->getStatusDistribution(
                $filters,
                $request->boolean('force_refresh'),
            ),
        ]);
    }

    /**
     * Get grouped appointment trend counts for the reports chart.
     */
    public function appointmentTrends(Request $request, ReportService $reportService): JsonResponse
    {
        $trendType = (string) $request->query('trend_type', 'daily');
        $filters = $this->validateReportFilters($request);

        validator(
            ['trend_type' => $trendType],
            [
                'trend_type' => [
                    'required',
                    'string',
                    Rule::in(ReportService::supportedTrendTypes()),
                ],
            ],
        )->validate();

        return response()->json([
            'data' => $reportService->getAppointmentTrends(
                $trendType,
                $filters,
                $request->boolean('force_refresh'),
            ),
        ]);
    }
}
