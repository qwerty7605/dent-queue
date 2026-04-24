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
            'clinic_title' => ['nullable', 'string', 'max:255'],
            'practice_license_id' => ['nullable', 'string', 'max:120'],
            'operational_hotline' => ['nullable', 'string', 'max:60'],
            'clinic_headquarters' => ['nullable', 'string', 'max:1000'],
            'opening_time' => ['sometimes', 'nullable', 'date_format:H:i'],
            'closing_time' => ['sometimes', 'nullable', 'date_format:H:i', 'after:opening_time'],
            'working_days' => ['sometimes', 'array', 'min:1'],
            'working_days.*' => ['required_with:working_days', 'string', 'distinct', 'in:Sunday,Monday,Tuesday,Wednesday,Thursday,Friday,Saturday'],
            'daily_operating_hours' => ['required', 'array', 'min:1'],
            'daily_operating_hours.*.opening_time' => ['required', 'date_format:H:i'],
            'daily_operating_hours.*.closing_time' => ['required', 'date_format:H:i'],
        ], [
            'daily_operating_hours.required' => 'At least one working day must be selected.',
            'daily_operating_hours.min' => 'At least one working day must be selected.',
        ]);

        foreach ((array) $request->input('daily_operating_hours', []) as $day => $schedule) {
            if (! in_array($day, ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'], true)) {
                return response()->json([
                    'message' => 'The given data was invalid.',
                    'errors' => [
                        'daily_operating_hours' => ['Each schedule must belong to a valid weekday.'],
                    ],
                ], 422);
            }

            if (strcmp((string) ($schedule['closing_time'] ?? ''), (string) ($schedule['opening_time'] ?? '')) <= 0) {
                return response()->json([
                    'message' => 'The given data was invalid.',
                    'errors' => [
                        "daily_operating_hours.$day.closing_time" => ['Closing time must be later than opening time.'],
                    ],
                ], 422);
            }
        }

        return response()->json([
            'message' => 'Clinic settings saved successfully.',
            'data' => $this->clinicSettingService->saveSettings($request->user(), $payload),
        ]);
    }
}
