<?php

namespace App\Http\Controllers\Api\Concerns;

use Illuminate\Contracts\Support\Arrayable;
use Illuminate\Http\Request;

trait ProtectsInternPatientPrivacy
{
    /**
     * @param  array<string, mixed>  $payload
     * @return array<string, mixed>
     */
    private function protectInternPatientPrivacy(Request $request, array $payload): array
    {
        if (!$this->isInternRequest($request)) {
            return $payload;
        }

        return $this->redactInternPatientData($payload);
    }

    private function isInternRequest(Request $request): bool
    {
        $user = $request->user();

        if ($user === null) {
            return false;
        }

        if ($user->role === null) {
            $user->load('role');
        }

        return mb_strtolower((string) optional($user->role)->name) === 'intern';
    }

    /**
     * @param  mixed  $value
     * @return mixed
     */
    private function redactInternPatientData(mixed $value): mixed
    {
        if ($value instanceof Arrayable) {
            $value = $value->toArray();
        }

        if (!is_array($value)) {
            return $value;
        }

        if (array_is_list($value)) {
            return array_map(fn (mixed $item): mixed => $this->redactInternPatientData($item), $value);
        }

        $redacted = [];

        foreach ($value as $key => $item) {
            if (!is_string($key)) {
                $redacted[$key] = $this->redactInternPatientData($item);
                continue;
            }

            if ($key === 'patient_name' || $key === 'full_name') {
                $redacted[$key] = $this->internPatientAlias($value);
                continue;
            }

            if ($key === 'patient') {
                $redacted[$key] = [
                    'display_name' => $this->internPatientAlias($value),
                ];
                continue;
            }

            if ($this->isInternSensitivePatientField($key)) {
                continue;
            }

            $redacted[$key] = $this->redactInternPatientData($item);
        }

        return $redacted;
    }

    /**
     * @param  array<string, mixed>  $record
     */
    private function internPatientAlias(array $record): string
    {
        $appointmentId = $record['appointment_id'] ?? $record['id'] ?? null;

        if ($appointmentId !== null && (string) $appointmentId !== '') {
            return 'Patient #' . (string) $appointmentId;
        }

        return 'Patient';
    }

    private function isInternSensitivePatientField(string $key): bool
    {
        return in_array($key, [
            'patient_id',
            'user_id',
            'first_name',
            'middle_name',
            'last_name',
            'gender',
            'birthdate',
            'address',
            'contact',
            'contact_number',
            'phone_number',
            'location',
            'email',
            'notes',
            'logs',
            'cancellation_reason',
            'cancelled_by',
            'cancelled_by_name',
            'reschedule_reason',
        ], true);
    }
}
