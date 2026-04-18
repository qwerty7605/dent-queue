<?php

use App\Http\Controllers\Api\AdminClinicSettingsController;
use App\Http\Controllers\Api\AdminDashboardController;
use App\Http\Controllers\Api\AdminProfileController;
use App\Http\Controllers\Api\AdminStaffController;
use App\Http\Controllers\Api\AppointmentController;
use App\Http\Controllers\Api\AuthController;
use App\Http\Controllers\Api\DoctorAvailabilityController;
use App\Http\Controllers\Api\NotificationController;
use App\Http\Controllers\Api\PatientProfileController;
use App\Http\Controllers\Api\PatientRecordController;
use App\Http\Controllers\Api\QueueController;
use App\Http\Controllers\Api\ReportController;
use App\Http\Controllers\Api\ServiceController;
use App\Http\Controllers\Api\StaffProfileController;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Route;

Route::prefix('v1')->group(function () {
    // Public routes (Auth)
    Route::prefix('auth')->group(function () {
        Route::post('/register', [AuthController::class, 'register']);
        Route::post('/login', [AuthController::class, 'login']);
    });

    // Protected routes
    Route::middleware('auth:sanctum')->group(function () {
        Route::post('/auth/logout', [AuthController::class, 'logout']);
        Route::get('/availability/slots', [DoctorAvailabilityController::class, 'slots']);

        Route::prefix('admin')->group(function () {
            Route::middleware('role:admin,staff,intern')->group(function () {
                Route::get('/dashboard/stats', [AdminDashboardController::class, 'stats']);
                Route::get('/appointments', [AppointmentController::class, 'indexAdmin']);
                Route::get('/appointments/master-list', [AppointmentController::class, 'masterList']);
                Route::get('/calendar/appointments', [AppointmentController::class, 'calendarAppointments']);
                Route::get('/calendar/appointments/{appointment}', [AppointmentController::class, 'calendarAppointmentDetails']);
                Route::get('/queues/today', [QueueController::class, 'index']);
                Route::get('/reports/summary', [AdminDashboardController::class, 'reportSummary']);
                Route::get('/reports/trends', [AdminDashboardController::class, 'appointmentTrends']);
                Route::get('/reports/status-distribution', [AdminDashboardController::class, 'statusDistribution']);
            });

            Route::middleware('role:admin,staff')->group(function () {
                Route::put('/profile', [AdminProfileController::class, 'update']);
                Route::get('/patients', [PatientRecordController::class, 'index']);
                Route::get('/patients/search', [PatientRecordController::class, 'search']);
                Route::get('/patients/{patientId}', [PatientRecordController::class, 'show']);
                Route::delete('/patients/{patientId}', [PatientRecordController::class, 'destroy']);
                Route::apiResource('services', ServiceController::class);
                Route::apiResource('staff', AdminStaffController::class);
                Route::post('/appointments', [AppointmentController::class, 'storeAdmin']);
                Route::post('/appointments/walk-in', [AppointmentController::class, 'storeWalkIn']);
                Route::post('/appointments/follow-up', [AppointmentController::class, 'storeFollowUp']);
                Route::patch('/appointments/{appointment}/status', [AppointmentController::class, 'updateStatus']);
                Route::patch('/appointments/{id}/restore', [AppointmentController::class, 'restore']);
                Route::get('/appointments/recycle-bin', [AppointmentController::class, 'recycleBin']);
                Route::post('/queues/call-next', [QueueController::class, 'callNext']);
                Route::apiResource('reports', ReportController::class)->only(['index']);

                Route::middleware('role:admin')->group(function () {
                    Route::get('/reports/export', [ReportController::class, 'export']);
                    Route::get('/settings/clinic', [AdminClinicSettingsController::class, 'show']);
                    Route::put('/settings/clinic', [AdminClinicSettingsController::class, 'update']);
                    Route::get('/settings/doctor-unavailability', [DoctorAvailabilityController::class, 'index']);
                    Route::post('/settings/doctor-unavailability', [DoctorAvailabilityController::class, 'store']);
                    Route::delete('/settings/doctor-unavailability/{doctorUnavailability}', [DoctorAvailabilityController::class, 'destroy']);
                });
            });
        });

        // Patient routes
        Route::prefix('patient')->middleware('role:patient')->group(function () {
            Route::get('/services', [ServiceController::class, 'index']);
            Route::get('/appointments/history', [AppointmentController::class, 'medicalHistory']);
            Route::patch('/appointments/{appointment}/cancel', [AppointmentController::class, 'cancel']);
            Route::patch('/appointments/{id}/restore', [AppointmentController::class, 'restore']);
            Route::get('/appointments/recycle-bin', [AppointmentController::class, 'recycleBin']);
            Route::apiResource('appointments', AppointmentController::class);
            Route::patch('/notifications/read-all', [NotificationController::class, 'markAllAsRead']);
            Route::get('/notifications', [NotificationController::class, 'index']);
            Route::patch('/notifications/{notification}/read', [NotificationController::class, 'markAsRead'])
                ->whereNumber('notification');
            Route::get('/notifications/{notification}', [NotificationController::class, 'show'])
                ->whereNumber('notification');
            Route::get('/queues/today', [QueueController::class, 'index']);
            Route::post('/queues/join', [QueueController::class, 'store']);
            Route::match(['put', 'patch'], '/profile/{id}', [PatientProfileController::class, 'update'])
                ->whereNumber('id');
        });

        Route::prefix('staff')->middleware('role:staff')->group(function () {
            Route::patch('/notifications/read-all', [NotificationController::class, 'markAllAsRead']);
            Route::get('/notifications', [NotificationController::class, 'index']);
            Route::patch('/notifications/{notification}/read', [NotificationController::class, 'markAsRead'])
                ->whereNumber('notification');
            Route::match(['put', 'patch'], '/profile/{id}', [StaffProfileController::class, 'update'])
                ->whereNumber('id');
        });

        Route::get('/user', function (Request $request) {
            return $request->user()->load('role');
        });
    });
});
