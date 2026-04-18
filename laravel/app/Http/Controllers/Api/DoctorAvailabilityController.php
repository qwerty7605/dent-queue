<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\DoctorUnavailability;
use App\Services\DoctorAvailabilityService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class DoctorAvailabilityController extends Controller
{
    public function __construct(
        private readonly DoctorAvailabilityService $doctorAvailabilityService,
    ) {
    }

    public function slots(Request $request): JsonResponse
    {
        $payload = $request->validate([
            'date' => ['required', 'date_format:Y-m-d'],
        ]);

        return response()->json([
            'data' => $this->doctorAvailabilityService->getSlotAvailability((string) $payload['date']),
        ]);
    }

    public function index(): JsonResponse
    {
        return response()->json([
            'data' => $this->doctorAvailabilityService->getUpcomingSchedules(),
        ]);
    }

    public function store(Request $request): JsonResponse
    {
        $payload = $request->validate([
            'unavailable_date' => ['required', 'date_format:Y-m-d'],
            'start_time' => ['required', 'string'],
            'end_time' => ['required', 'string'],
            'reason' => ['nullable', 'string', 'max:255'],
        ]);

        $schedule = $this->doctorAvailabilityService->create($request->user(), $payload);

        return response()->json([
            'message' => 'Doctor unavailability saved successfully.',
            'data' => $this->doctorAvailabilityService->getUpcomingSchedules(),
        ], 201);
    }

    public function destroy(DoctorUnavailability $doctorUnavailability): JsonResponse
    {
        $this->doctorAvailabilityService->delete($doctorUnavailability);

        return response()->json([
            'message' => 'Doctor unavailability removed successfully.',
        ]);
    }
}
