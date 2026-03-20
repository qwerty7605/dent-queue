<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Services\ClinicSettingService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class AdminClinicSettingsController extends Controller
{
    public function __construct(protected ClinicSettingService $clinicSettingService)
    {
    }

    public function show(): JsonResponse
    {
        return response()->json([
            'data' => $this->clinicSettingService->getCurrentSettings(),
        ]);
    }

    public function update(Request $request): JsonResponse
    {
        $payload = $request->validate([
            'opening_time' => ['required', 'date_format:H:i'],
            'closing_time' => ['required', 'date_format:H:i', 'after:opening_time'],
            'working_days' => ['required', 'array', 'min:1'],
            'working_days.*' => ['required', 'string', 'distinct', 'in:Sunday,Monday,Tuesday,Wednesday,Thursday,Friday,Saturday'],
        ], [
            'opening_time.required' => 'Opening time is required.',
            'closing_time.required' => 'Closing time is required.',
            'closing_time.after' => 'Closing time must be later than opening time.',
            'working_days.required' => 'At least one working day must be selected.',
            'working_days.min' => 'At least one working day must be selected.',
        ]);

        return response()->json([
            'message' => 'Clinic settings saved successfully.',
            'data' => $this->clinicSettingService->saveSettings($request->user(), $payload),
        ]);
    }
}
