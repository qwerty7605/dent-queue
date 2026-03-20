<?php

namespace App\Services;

use App\Models\ClinicSetting;
use App\Models\User;

class ClinicSettingService
{
    private const WEEK_DAYS = [
        'Sunday',
        'Monday',
        'Tuesday',
        'Wednesday',
        'Thursday',
        'Friday',
        'Saturday',
    ];

    public function getCurrentSettings(): array
    {
        $clinicSetting = ClinicSetting::query()->with('updatedBy')->latest('id')->first();

        return $this->formatSettings($clinicSetting);
    }

    public function saveSettings(User $user, array $payload): array
    {
        $clinicSetting = ClinicSetting::query()->with('updatedBy')->first() ?? new ClinicSetting();
        $clinicSetting->fill([
            'opening_time' => (string) $payload['opening_time'],
            'closing_time' => (string) $payload['closing_time'],
            'working_days' => $this->normalizeWorkingDays($payload['working_days']),
            'updated_by_user_id' => (int) $user->id,
        ]);
        $clinicSetting->save();
        $clinicSetting->load('updatedBy');

        return $this->formatSettings($clinicSetting);
    }

    public function formatSettings(?ClinicSetting $clinicSetting): array
    {
        return [
            'opening_time' => $this->formatTime($clinicSetting?->opening_time),
            'closing_time' => $this->formatTime($clinicSetting?->closing_time),
            'working_days' => $clinicSetting !== null
                ? $this->normalizeWorkingDays($clinicSetting->working_days ?? [])
                : [],
            'updated_by_user_id' => $clinicSetting?->updated_by_user_id !== null
                ? (int) $clinicSetting->updated_by_user_id
                : null,
            'updated_at' => optional($clinicSetting?->updated_at)?->toDateTimeString(),
        ];
    }

    /**
     * Normalize selected working days into a stable calendar order.
     *
     * @param  array<int, mixed>  $workingDays
     * @return array<int, string>
     */
    private function normalizeWorkingDays(array $workingDays): array
    {
        $selectedLookup = [];

        foreach ($workingDays as $workingDay) {
            $selectedLookup[mb_strtolower((string) $workingDay)] = true;
        }

        $normalized = [];

        foreach (self::WEEK_DAYS as $weekDay) {
            if (isset($selectedLookup[mb_strtolower($weekDay)])) {
                $normalized[] = $weekDay;
            }
        }

        return $normalized;
    }

    private function formatTime(mixed $value): ?string
    {
        if ($value === null) {
            return null;
        }

        $time = (string) $value;

        if (mb_strlen($time) >= 5) {
            return mb_substr($time, 0, 5);
        }

        return $time;
    }
}
