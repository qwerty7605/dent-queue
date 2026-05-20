<?php

namespace App\Services;

use App\Models\Appointment;
use App\Models\PatientRecord;
use App\Models\User;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;

class OneSignalNotificationService
{
    public function sendToUser(User $user, string $title, string $message, array $data = []): bool
    {
        $appId = config('services.onesignal.app_id');
        $restApiKey = config('services.onesignal.rest_api_key');

        if (empty($appId) || empty($restApiKey)) {
            Log::error('OneSignal configuration is missing.');

            return false;
        }

        $subscriptionIds = $user->userDevices()
            ->where('provider', 'onesignal')
            ->where('is_active', true)
            ->pluck('device_token')
            ->filter()
            ->unique()
            ->values()
            ->all();

        if (empty($subscriptionIds)) {
            return false;
        }

        $payload = [
            'app_id' => $appId,
            'target_channel' => 'push',
            'include_subscription_ids' => $subscriptionIds,
            'small_icon' => 'ic_launcher',
            'large_icon' => 'ic_launcher',
            'headings' => [
                'en' => $title,
            ],
            'contents' => [
                'en' => $message,
            ],
        ];

        if (!empty($data)) {
            $payload['data'] = $data;
        }

        try {
            $response = Http::withHeaders([
                'Authorization' => 'Key '.$restApiKey,
                'Content-Type' => 'application/json',
            ])
                ->acceptJson()
                ->timeout(10)
                ->post('https://api.onesignal.com/notifications', $payload);

            if ($response->failed()) {
                Log::error('OneSignal notification send failed.', [
                    'user_id' => $user->id,
                    'status' => $response->status(),
                    'response' => $response->json() ?? $response->body(),
                ]);

                return false;
            }

            return true;
        } catch (\Throwable $exception) {
            Log::error('OneSignal notification send exception.', [
                'user_id' => $user->id,
                'message' => $exception->getMessage(),
            ]);

            return false;
        }
    }

    public function sendAppointmentApproved(Appointment $appointment): bool
    {
        $appointment->loadMissing(['service', 'services']);

        $patientRecord = PatientRecord::query()
            ->with('user')
            ->find($appointment->patient_id);
        $user = $patientRecord?->user;
        $patientUserId = $user?->id;

        if ($user === null) {
            Log::info('No patient user found for appointment approval push.', [
                'appointment_id' => (int) $appointment->id,
                'patient_id' => (int) $appointment->patient_id,
                'patient_record_user_id' => $patientRecord?->user_id,
                'patient_user_id' => $patientUserId,
            ]);

            return false;
        }

        $subscriptionIds = $user->userDevices()
            ->where('provider', 'onesignal')
            ->where('is_active', true)
            ->pluck('device_token')
            ->filter()
            ->unique()
            ->values()
            ->all();

        $payload = [
            'app_id' => config('services.onesignal.app_id'),
            'target_channel' => 'push',
            'include_subscription_ids' => $subscriptionIds,
            'small_icon' => 'ic_launcher',
            'large_icon' => 'ic_launcher',
            'headings' => [
                'en' => 'Appointment Approved',
            ],
            'contents' => [
                'en' => sprintf(
                    'Your appointment on %s at %s has been approved.',
                    (string) $appointment->appointment_date,
                    (string) $appointment->time_slot,
                ),
            ],
            'data' => [
                'type' => 'appointment_approved',
                'appointment_id' => (int) $appointment->id,
            ],
        ];

        Log::info('OneSignal appointment approval push prepared.', [
            'appointment_id' => (int) $appointment->id,
            'patient_id' => (int) $appointment->patient_id,
            'resolved_patient_user_id' => (int) $user->id,
            'patient_user_id' => (int) $user->id,
            'device_tokens_found' => $subscriptionIds,
            'payload' => $payload,
        ]);

        if (empty($subscriptionIds)) {
            Log::info('No active OneSignal device token found.', [
                'appointment_id' => (int) $appointment->id,
                'patient_id' => (int) $appointment->patient_id,
                'resolved_patient_user_id' => (int) $user->id,
                'patient_user_id' => (int) $user->id,
            ]);

            return false;
        }

        if (empty(config('services.onesignal.app_id')) || empty(config('services.onesignal.rest_api_key'))) {
            Log::error('OneSignal appointment approval push configuration is missing.', [
                'appointment_id' => (int) $appointment->id,
                'patient_id' => (int) $appointment->patient_id,
                'patient_user_id' => (int) $user->id,
                'device_tokens_found' => $subscriptionIds,
                'payload' => $payload,
            ]);

            return false;
        }

        try {
            $response = Http::withHeaders([
                'Authorization' => 'Key '.config('services.onesignal.rest_api_key'),
                'Content-Type' => 'application/json',
            ])
                ->acceptJson()
                ->timeout(10)
                ->post('https://api.onesignal.com/notifications', $payload);

            Log::info('OneSignal appointment approval push response.', [
                'appointment_id' => (int) $appointment->id,
                'patient_id' => (int) $appointment->patient_id,
                'patient_user_id' => (int) $user->id,
                'device_tokens_found' => $subscriptionIds,
                'payload' => $payload,
                'status' => $response->status(),
                'body' => $response->body(),
            ]);

            return $response->successful();
        } catch (\Throwable $exception) {
            Log::error('OneSignal appointment approval push exception.', [
                'appointment_id' => (int) $appointment->id,
                'patient_id' => (int) $appointment->patient_id,
                'patient_user_id' => (int) $user->id,
                'device_tokens_found' => $subscriptionIds,
                'payload' => $payload,
                'message' => $exception->getMessage(),
            ]);

            return false;
        }
    }
}
