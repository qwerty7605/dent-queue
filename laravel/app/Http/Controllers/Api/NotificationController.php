<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\PatientRecord;
use App\Models\PatientNotification;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class NotificationController extends Controller
{
    public function index(Request $request): JsonResponse
    {
        $patientRecord = $this->resolveAuthenticatedPatientRecord($request);

        $notifications = PatientNotification::query()
            ->where('patient_id', (int) $patientRecord->id)
            ->orderByDesc('created_at')
            ->get();

        return response()->json([
            'notifications' => $notifications->map(fn (PatientNotification $notification) => $this->formatNotificationResponse($notification)),
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
            'notification' => $this->formatNotificationResponse($notification),
        ]);
    }

    private function formatNotificationResponse(PatientNotification $notification): array
    {
        return [
            'id' => (int) $notification->id,
            'patient_id' => (int) $notification->patient_id,
            'appointment_id' => (int) $notification->appointment_id,
            'type' => (string) $notification->type,
            'title' => (string) $notification->title,
            'message' => (string) $notification->message,
            'read_at' => optional($notification->read_at)?->toDateTimeString(),
            'timestamp_created' => optional($notification->created_at)?->toDateTimeString(),
        ];
    }

    private function resolveAuthenticatedPatientRecord(Request $request): PatientRecord
    {
        /** @var \App\Models\User $user */
        $user = $request->user();

        return PatientRecord::resolveForUser($user);
    }
}
