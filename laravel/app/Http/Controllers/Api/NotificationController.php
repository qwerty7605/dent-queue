<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
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
            'unread_count' => $this->notificationService->unreadCountForUser($user),
        ]);
    }

    public function show(Request $request, PatientNotification $notification): JsonResponse
    {
        /** @var \App\Models\User $user */
        $user = $request->user();

        if (!$this->notificationService->canAccessNotification($user, $notification)) {
            return response()->json([
                'message' => 'Unauthorized. You can only view your own notifications.',
            ], 403);
        }

        return response()->json([
            'notification' => $this->notificationService->formatNotification($notification),
        ]);
    }

    public function markAsRead(Request $request, PatientNotification $notification): JsonResponse
    {
        /** @var \App\Models\User $user */
        $user = $request->user();

        if (!$this->notificationService->canAccessNotification($user, $notification)) {
            return response()->json([
                'message' => 'Unauthorized. You can only update your own notifications.',
            ], 403);
        }

        $notification = $this->notificationService->markNotificationAsRead($notification);

        return response()->json([
            'message' => 'Notification marked as read.',
            'notification' => $this->notificationService->formatNotification($notification),
            'unread_count' => $this->notificationService->unreadCountForUser($user),
        ]);
    }

    public function markAllAsRead(Request $request): JsonResponse
    {
        /** @var \App\Models\User $user */
        $user = $request->user();

        $updatedCount = $this->notificationService->markAllAsReadForUser($user);

        return response()->json([
            'message' => 'Notifications marked as read.',
            'updated_count' => $updatedCount,
            'unread_count' => $this->notificationService->unreadCountForUser($user),
        ]);
    }
}
