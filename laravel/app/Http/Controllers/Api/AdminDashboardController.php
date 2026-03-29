<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Api\Concerns\InteractsWithReportFilters;
use App\Http\Controllers\Controller;
use App\Models\Appointment;
use App\Models\PatientRecord;
use App\Models\User;
use App\Services\ReportService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
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
        $patientsCount = PatientRecord::query()
            ->where(function ($query) {
                $query->whereNull('user_id')
                    ->orWhereHas('user', function ($userQuery) {
                        $userQuery->where('is_active', true);
                    });
            })
            ->count();
        
        $staffCount = User::whereHas('role', function ($query) {
            $query->whereRaw('LOWER(name) = ?', ['staff']);
        })
            ->where('is_active', true)
            ->count();
        
        $appointmentsCount = Appointment::count();

        return response()->json([
            'data' => [
                'patients_count' => $patientsCount,
                'staff_count' => $staffCount,
                'appointments_count' => $appointmentsCount,
            ]
        ]);
    }

    /**
     * Get summary counts for the reports dashboard.
     *
     * @return \Illuminate\Http\JsonResponse
     */
    public function reportSummary(Request $request, ReportService $reportService): JsonResponse
    {
        $filters = $this->validateReportFilters($request);
        $summary = $reportService->getReportSummary($filters);

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
            'data' => $reportService->getStatusDistribution($filters),
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
            'data' => $reportService->getAppointmentTrends($trendType, $filters),
        ]);
    }
}
