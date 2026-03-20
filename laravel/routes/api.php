<?php

use Illuminate\Http\Request;
use Illuminate\Support\Facades\Route;

use App\Http\Controllers\Api\AuthController;
use App\Http\Controllers\Api\ServiceController;
use App\Http\Controllers\Api\AppointmentController;
use App\Http\Controllers\Api\NotificationController;
use App\Http\Controllers\Api\QueueController;
use App\Http\Controllers\Api\PatientProfileController;
use App\Http\Controllers\Api\StaffProfileController;
use App\Http\Controllers\Api\PatientRecordController;
use App\Http\Controllers\Api\ReportController;

Route::prefix('v1')->group(function () {
    // Public routes (Auth)
    Route::prefix('auth')->group(function () {
        Route::post('/register', [AuthController::class, 'register']);
        Route::post('/login', [AuthController::class, 'login']);
    });

    // Protected routes
    Route::middleware('auth:sanctum')->group(function () {
        Route::post('/auth/logout', [AuthController::class, 'logout']);

        // Admin/Staff routes
        Route::prefix('admin')->middleware('role:admin,staff')->group(function () {
            Route::get('/patients', [PatientRecordController::class, 'index']);
            Route::get('/patients/search', [PatientRecordController::class, 'search']);
            Route::get('/patients/{patientId}', [PatientRecordController::class, 'show']);
            Route::apiResource('services', ServiceController::class);
            Route::get('/appointments', [AppointmentController::class, 'indexAdmin']);
            Route::get('/appointments/master-list', [AppointmentController::class, 'masterList']);
            Route::post('/appointments', [AppointmentController::class, 'storeAdmin']);
            Route::post('/appointments/walk-in', [AppointmentController::class, 'storeWalkIn']);
            Route::post('/appointments/follow-up', [AppointmentController::class, 'storeFollowUp']);
            Route::patch('/appointments/{appointment}/status', [AppointmentController::class, 'updateStatus']);
            Route::get('/calendar/appointments', [AppointmentController::class, 'calendarAppointments']);
            Route::get('/calendar/appointments/{appointment}', [AppointmentController::class, 'calendarAppointmentDetails']);
            Route::post('/queues/call-next', [QueueController::class, 'callNext']);
            Route::apiResource('reports', ReportController::class);
        });

        // Patient routes
        Route::prefix('patient')->middleware('role:patient')->group(function () {
            Route::get('/services', [ServiceController::class, 'index']);
            Route::get('/appointments/history', [AppointmentController::class, 'medicalHistory']);
            Route::apiResource('appointments', AppointmentController::class);
            Route::patch('/appointments/{appointment}/cancel', [AppointmentController::class, 'cancel']);
            Route::get('/notifications', [NotificationController::class, 'index']);
            Route::get('/notifications/{notification}', [NotificationController::class, 'show']);
            Route::get('/queues/today', [QueueController::class, 'index']);
            Route::post('/queues/join', [QueueController::class, 'store']);
            Route::match(['put', 'patch'], '/profile/{id}', [PatientProfileController::class, 'update'])
                ->whereNumber('id');
        });

        Route::prefix('staff')->middleware('role:staff')->group(function () {
            Route::match(['put', 'patch'], '/profile/{id}', [StaffProfileController::class, 'update'])
                ->whereNumber('id');
        });

        Route::get('/user', function (Request $request) {
            return $request->user()->load('role');
        });
    });
});
