<?php

namespace App\Services;

use App\Models\PatientNotification;
use App\Models\PatientRecord;
use App\Models\StaffNotification;
use App\Models\User;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Support\Collection;

class NotificationService
{
    public function __construct(
        private readonly CentralizedCacheService $cacheService,
    ) {}

    public function listForUser(User $user, bool $forceRefresh = false): Collection
    {
        return collect($this->cacheService->rememberNotificationsListForUser($user, function () use ($user): array {
            $roleName = $this->resolveRoleName($user);

            if ($roleName === 'patient') {
                return $this->patientNotificationsQuery($user)
                    ->orderByDesc('created_at')
                    ->orderByDesc('id')
                    ->get()
                    ->map(fn (PatientNotification $notification) => $this->formatNotification($notification))
                    ->values()
                    ->all();
            }

            if (in_array($roleName, ['staff', 'admin'], true)) {
                return $this->staffNotificationsQuery($user)
                    ->orderByDesc('created_at')
                    ->orderByDesc('id')
                    ->get()
                    ->map(fn (StaffNotification $notification) => $this->formatNotification($notification))
                    ->values()
                    ->all();
            }

            return [];
        }, $forceRefresh));
    }

    public function unreadCountForUser(User $user, bool $forceRefresh = false): int
    {
        return $this->cacheService->rememberNotificationsUnreadCountForUser($user, function () use ($user): int {
            $roleName = $this->resolveRoleName($user);

            return match ($roleName) {
                'patient' => $this->patientNotificationsQuery($user)->whereNull('read_at')->count(),
                'staff', 'admin' => $this->staffNotificationsQuery($user)->whereNull('read_at')->count(),
                default => 0,
            };
        }, $forceRefresh);
    }

    public function resolveNotificationForUser(User $user, int $notificationId): PatientNotification|StaffNotification|null
    {
        $roleName = $this->resolveRoleName($user);

        if ($roleName === 'patient') {
            return $this->patientNotificationsQuery($user)
                ->whereKey($notificationId)
                ->first();
        }

        if (in_array($roleName, ['staff', 'admin'], true)) {
            return $this->staffNotificationsQuery($user)
                ->whereKey($notificationId)
                ->first();
        }

        return null;
    }

    public function markNotificationAsRead(PatientNotification|StaffNotification $notification): PatientNotification|StaffNotification
    {
        if ($notification->read_at === null) {
            $notification->forceFill([
                'read_at' => now(),
            ])->save();
        }

        $this->flushNotificationCacheForModel($notification);

        return $notification->fresh() ?? $notification;
    }

    public function markAllAsReadForUser(User $user): int
    {
        $timestamp = now();
        $roleName = $this->resolveRoleName($user);

        $updatedCount = match ($roleName) {
            'patient' => $this->patientNotificationsQuery($user)
                ->whereNull('read_at')
                ->update([
                    'read_at' => $timestamp,
                    'updated_at' => $timestamp,
                ]),
            'staff', 'admin' => $this->staffNotificationsQuery($user)
                ->whereNull('read_at')
                ->update([
                    'read_at' => $timestamp,
                    'updated_at' => $timestamp,
                ]),
            default => 0,
        };

        $this->cacheService->flushNotificationsForUser($user);

        return $updatedCount;
    }

    public function formatNotification(Model $notification): array
    {
        $createdAt = optional($notification->created_at)?->toIso8601String();
        $readAt = optional($notification->read_at)?->toIso8601String();
        $recipientId = $notification instanceof PatientNotification
            ? (int) ($notification->patient_id ?? 0)
            : (int) ($notification->user_id ?? 0);

        return [
            'notification_id' => (int) $notification->id,
            'title' => (string) $notification->title,
            'message' => (string) $notification->message,
            'created_at' => $createdAt,
            'is_read' => $notification->read_at !== null,
            'related_appointment_id' => $notification->appointment_id !== null
                ? (int) $notification->appointment_id
                : null,

            'id' => (int) $notification->id,
            'patient_id' => $recipientId,
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

    private function patientNotificationsQuery(User $user): Builder
    {
        $patientRecord = PatientRecord::resolveForUser($user);

        return PatientNotification::query()
            ->where('patient_id', (int) $patientRecord->id);
    }

    private function staffNotificationsQuery(User $user): Builder
    {
        return StaffNotification::query()
            ->where('user_id', (int) $user->id);
    }

    private function flushNotificationCacheForModel(PatientNotification|StaffNotification $notification): void
    {
        if ($notification instanceof PatientNotification) {
            $this->cacheService->flushNotificationsForPatientRecord((int) $notification->patient_id);

            return;
        }

        $this->cacheService->flushNotificationsForStaffUser((int) $notification->user_id);
    }
}
