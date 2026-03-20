<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Appointment;
use App\Models\PatientRecord;
use App\Models\User;
use Illuminate\Http\JsonResponse;

class AdminDashboardController extends Controller
{
    /**
     * Get real-time stats for the admin dashboard.
     *
     * @return \Illuminate\Http\JsonResponse
     */
    public function stats(): JsonResponse
    {
        $patientsCount = PatientRecord::count();
        
        $staffCount = User::whereHas('role', function ($query) {
            $query->whereRaw('LOWER(name) = ?', ['staff']);
        })->count();
        
        $appointmentsCount = Appointment::count();

        return response()->json([
            'data' => [
                'patients_count' => $patientsCount,
                'staff_count' => $staffCount,
                'appointments_count' => $appointmentsCount,
            ]
        ]);
    }
}
