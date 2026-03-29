<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\PatientRecord;
use App\Models\PatientNotification;
use App\Services\NotificationService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class NotificationController extends Controller
{
    public function __construct(
        private readonly NotificationService $notificationService,
    ) {
    }

    public function index(Request $request): JsonResponse
    {
        /** @var \App\Models\User $user */
        $user = $request->user();

        return response()->json([
            'notifications' => $this->notificationService->listForUser($user)->values(),
        ]);
    }

    public function show(Request $request, PatientNotification $notification): JsonResponse
    {
        $patientRecord = $this->resolveAuthenticatedPatientRecord($request);

        if ((int) $notification->patient_id !== (int) $patientRecord->id) {
            return response()->json([
                'message' => 'Unauthorized. You can only view your own notifications.',
            ], 403);
        }

        return response()->json([
            'notification' => $this->notificationService->formatNotification($notification),
        ]);
    }

    private function resolveAuthenticatedPatientRecord(Request $request): PatientRecord
    {
        /** @var \App\Models\User $user */
        $user = $request->user();

        return PatientRecord::resolveForUser($user);
    }
}
