<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Services\ReportService;
use App\Models\Appointment;
use App\Models\PatientRecord;
use App\Models\User;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\Rule;

class AdminDashboardController extends Controller
{
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
    public function reportSummary(): JsonResponse
    {
        $summary = DB::table('appointments')
            ->selectRaw('COUNT(*) as total_appointments')
            ->selectRaw("SUM(CASE WHEN status = 'pending' THEN 1 ELSE 0 END) as pending_count")
            ->selectRaw("SUM(CASE WHEN status = 'confirmed' THEN 1 ELSE 0 END) as approved_count")
            ->selectRaw("SUM(CASE WHEN status = 'completed' THEN 1 ELSE 0 END) as completed_count")
            ->selectRaw("SUM(CASE WHEN status = 'cancelled' THEN 1 ELSE 0 END) as cancelled_count")
            ->first();

        return response()->json([
            'data' => [
                'total_appointments' => (int) ($summary->total_appointments ?? 0),
                'pending_count' => (int) ($summary->pending_count ?? 0),
                'approved_count' => (int) ($summary->approved_count ?? 0),
                'completed_count' => (int) ($summary->completed_count ?? 0),
                'cancelled_count' => (int) ($summary->cancelled_count ?? 0),
            ]
        ]);
    }

    /**
     * Get grouped counts by status for the distribution chart.
     *
     * @return \Illuminate\Http\JsonResponse
     */
    public function statusDistribution(): JsonResponse
    {
        $counts = DB::table('appointments')
            ->select('status', DB::raw('count(*) as count'))
            ->groupBy('status')
            ->pluck('count', 'status')
            ->all();

        $statuses = [
            'pending' => 'pending',
            'confirmed' => 'approved',
            'completed' => 'completed',
            'cancelled' => 'cancelled',
        ];

        $data = [];
        foreach ($statuses as $dbStatus => $label) {
            $data[] = [
                'status' => $label,
                'count' => (int) ($counts[$dbStatus] ?? 0),
            ];
        }

        return response()->json([
            'data' => $data
        ]);
    }

    /**
     * Get grouped appointment trend counts for the reports chart.
     */
    public function appointmentTrends(Request $request, ReportService $reportService): JsonResponse
    {
        $trendType = (string) $request->query('trend_type', 'daily');

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
            'data' => $reportService->getAppointmentTrends($trendType),
        ]);
    }
}
