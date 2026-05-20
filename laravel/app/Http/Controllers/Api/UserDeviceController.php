<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\UserDevice;
use App\Services\OneSignalNotificationService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;

class UserDeviceController extends Controller
{
    public function storeOneSignalId(Request $request): JsonResponse
    {
        $data = $request->validate([
            'device_token' => ['required', 'string'],
            'provider' => ['nullable', 'string'],
            'device_name' => ['nullable', 'string'],
        ]);

        $user = $request->user();
        $deviceToken = $data['device_token'];
        $provider = strtolower((string) ($data['provider'] ?? 'onesignal'));

        $oldUserIds = UserDevice::query()
            ->where('device_token', $deviceToken)
            ->where('user_id', '!=', $user->id)
            ->pluck('user_id')
            ->unique()
            ->values()
            ->all();

        UserDevice::query()
            ->where('device_token', $deviceToken)
            ->where('user_id', '!=', $user->id)
            ->update(['is_active' => false]);

        $userDevice = UserDevice::updateOrCreate(
            [
                'user_id' => $user->id,
                'device_token' => $deviceToken,
            ],
            [
                'provider' => $provider,
                'device_name' => $data['device_name'] ?? null,
                'is_active' => true,
                'last_login_at' => now(),
            ],
        );
        $userDevice->refresh();

        Log::info('OneSignal device token saved.', [
            'authenticated_user_id' => (int) $user->id,
            'authenticated_user_role' => optional($user->role)->name,
            'device_token' => $deviceToken,
            'old_user_ids_for_token' => $oldUserIds,
            'provider' => $provider,
            'final_active_user_device' => $userDevice->only([
                'id',
                'user_id',
                'provider',
                'device_token',
                'device_name',
                'is_active',
                'last_login_at',
            ]),
        ]);

        return response()->json([
            'message' => 'OneSignal device registered successfully',
            'user_device' => [
                'id' => (int) $userDevice->id,
                'user_id' => (int) $userDevice->user_id,
                'provider' => (string) $userDevice->provider,
                'device_name' => $userDevice->device_name,
                'is_active' => (bool) $userDevice->is_active,
                'last_login_at' => optional($userDevice->last_login_at)->toIso8601String(),
            ],
        ]);
    }

    public function testPush(
        Request $request,
        OneSignalNotificationService $oneSignalNotificationService,
    ): JsonResponse {
        $sent = $oneSignalNotificationService->sendToUser(
            $request->user(),
            'SmartDentQueue Test',
            'Your OneSignal push notification setup is working.',
            ['type' => 'test_push'],
        );

        if (!$sent) {
            return response()->json([
                'message' => 'Unable to send test push notification',
            ], 422);
        }

        return response()->json([
            'message' => 'Test push notification sent successfully',
        ]);
    }

    public function testOneSignalPush(Request $request): JsonResponse
    {
        $user = $request->user();

        $deviceToken = $user->userDevices()
            ->where('provider', 'onesignal')
            ->where('is_active', true)
            ->latest('last_login_at')
            ->value('device_token');

        $payload = [
            'app_id' => config('services.onesignal.app_id'),
            'target_channel' => 'push',
            'include_subscription_ids' => [$deviceToken],
            'small_icon' => 'ic_launcher',
            'large_icon' => 'ic_launcher',
            'headings' => [
                'en' => 'Laravel OneSignal Test',
            ],
            'contents' => [
                'en' => 'This test push was sent directly from Laravel.',
            ],
            'data' => [
                'type' => 'test_onesignal_push',
                'user_id' => $user->id,
            ],
        ];

        Log::info('OneSignal debug push authenticated user.', [
            'user_id' => $user->id,
        ]);
        Log::info('OneSignal debug push device token.', [
            'device_token' => $deviceToken,
        ]);
        Log::info('OneSignal debug push request payload.', [
            'payload' => $payload,
        ]);

        if (empty($deviceToken)) {
            return response()->json([
                'message' => 'No active OneSignal device token found for authenticated user.',
                'user_id' => $user->id,
                'device_token' => $deviceToken,
                'payload' => $payload,
            ], 404);
        }

        if (empty(config('services.onesignal.app_id')) || empty(config('services.onesignal.rest_api_key'))) {
            return response()->json([
                'message' => 'OneSignal app ID or REST API key is missing.',
                'user_id' => $user->id,
                'device_token' => $deviceToken,
                'payload' => $payload,
            ], 422);
        }

        try {
            $response = Http::withHeaders([
                'Authorization' => 'Key '.config('services.onesignal.rest_api_key'),
                'Content-Type' => 'application/json',
            ])
                ->acceptJson()
                ->timeout(10)
                ->post('https://api.onesignal.com/notifications', $payload);

            Log::info('OneSignal debug push HTTP status.', [
                'status' => $response->status(),
            ]);
            Log::info('OneSignal debug push response body.', [
                'body' => $response->body(),
            ]);

            return response()->json([
                'message' => $response->successful()
                    ? 'OneSignal debug push request sent.'
                    : 'OneSignal debug push request failed.',
                'user_id' => $user->id,
                'device_token' => $deviceToken,
                'payload' => $payload,
                'onesignal_status' => $response->status(),
                'onesignal_response' => $response->json() ?? $response->body(),
            ], $response->successful() ? 200 : 422);
        } catch (\Throwable $exception) {
            Log::error('OneSignal debug push exception.', [
                'user_id' => $user->id,
                'device_token' => $deviceToken,
                'message' => $exception->getMessage(),
            ]);

            return response()->json([
                'message' => 'OneSignal debug push exception.',
                'user_id' => $user->id,
                'device_token' => $deviceToken,
                'payload' => $payload,
                'error' => $exception->getMessage(),
            ], 500);
        }
    }
}
