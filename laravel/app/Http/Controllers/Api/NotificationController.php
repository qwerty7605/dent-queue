<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
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
        $forceRefresh = $request->boolean('force_refresh');

        return response()->json([
            'notifications' => $this->notificationService->listForUser($user, $forceRefresh)->values(),
            'unread_count' => $this->notificationService->unreadCountForUser($user, $forceRefresh),
        ]);
    }

    public function show(Request $request, int $notification): JsonResponse
    {
        /** @var \App\Models\User $user */
        $user = $request->user();

        $resolvedNotification = $this->notificationService->resolveNotificationForUser($user, $notification);

        if ($resolvedNotification === null) {
            return response()->json([
                'message' => 'Unauthorized. You can only view your own notifications.',
            ], 403);
        }

        return response()->json([
            'notification' => $this->notificationService->formatNotification($resolvedNotification),
        ]);
    }

    public function markAsRead(Request $request, int $notification): JsonResponse
    {
        /** @var \App\Models\User $user */
        $user = $request->user();

        $resolvedNotification = $this->notificationService->resolveNotificationForUser($user, $notification);

        if ($resolvedNotification === null) {
            return response()->json([
                'message' => 'Unauthorized. You can only update your own notifications.',
            ], 403);
        }

        $resolvedNotification = $this->notificationService->markNotificationAsRead($resolvedNotification);

        return response()->json([
            'message' => 'Notification marked as read.',
            'notification' => $this->notificationService->formatNotification($resolvedNotification),
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
