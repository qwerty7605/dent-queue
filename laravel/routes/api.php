<?php

use Illuminate\Http\Request;
use Illuminate\Support\Facades\Route;

use App\Http\Controllers\Api\AuthController;
use App\Http\Controllers\Api\ServiceController;
use App\Http\Controllers\Api\AppointmentController;
use App\Http\Controllers\Api\QueueController;
use App\Http\Controllers\Api\ReportController;

Route::prefix('v1')->group(function () {
    // Admin/Staff routes
    Route::prefix('admin')->group(function () {
        Route::apiResource('services', ServiceController::class);
        Route::post('/queues/call-next', [QueueController::class, 'callNext']);
        Route::apiResource('reports', ReportController::class);
    });

    // Patient/General routes
    Route::prefix('patient')->group(function () {
        Route::apiResource('appointments', AppointmentController::class);
        Route::get('/queues/today', [QueueController::class, 'index']);
        Route::post('/queues/join', [QueueController::class, 'store']);
    });
});
