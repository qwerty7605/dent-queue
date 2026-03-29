<?php

namespace App\Services;

use App\Models\PatientNotification;
use App\Models\PatientRecord;
use App\Models\User;
use Illuminate\Support\Collection;

class NotificationService
{
    public function listForUser(User $user): Collection
    {
        $roleName = $this->resolveRoleName($user);

        if ($roleName === 'patient') {
            $patientRecord = PatientRecord::resolveForUser($user);

            return PatientNotification::query()
                ->where('patient_id', (int) $patientRecord->id)
                ->orderByDesc('created_at')
                ->orderByDesc('id')
                ->get()
                ->map(fn (PatientNotification $notification) => $this->formatNotification($notification));
        }

        if (in_array($roleName, ['staff', 'admin'], true)) {
            return collect();
        }

        return collect();
    }

    public function formatNotification(PatientNotification $notification): array
    {
        $createdAt = optional($notification->created_at)?->toIso8601String();
        $readAt = optional($notification->read_at)?->toIso8601String();

        return [
            'notification_id' => (int) $notification->id,
            'title' => (string) $notification->title,
            'message' => (string) $notification->message,
            'created_at' => $createdAt,
            'is_read' => $notification->read_at !== null,
            'related_appointment_id' => $notification->appointment_id !== null
                ? (int) $notification->appointment_id
                : null,

            // Keep legacy fields for existing consumers until the frontend is migrated.
            'id' => (int) $notification->id,
            'patient_id' => (int) $notification->patient_id,
            'appointment_id' => $notification->appointment_id !== null
                ? (int) $notification->appointment_id
                : null,
            'type' => (string) $notification->type,
            'read_at' => $readAt,
            'timestamp_created' => $createdAt,
        ];
    }

    private function resolveRoleName(User $user): string
    {
        $user->loadMissing('role');

        return mb_strtolower((string) optional($user->role)->name);
    }
}
