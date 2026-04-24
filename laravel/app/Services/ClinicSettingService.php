<?php

namespace App\Services;

use App\Models\Appointment;
use App\Models\ClinicSetting;
use App\Models\PatientNotification;
use App\Models\User;
use Illuminate\Support\Carbon;

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

    public function __construct(
        private readonly QueueService $queueService,
    ) {
    }

    public function getCurrentSettings(): array
    {
        $clinicSetting = $this->getCurrentClinicSetting();

        return $this->formatSettings($clinicSetting);
    }

    public function saveSettings(User $user, array $payload): array
    {
        $clinicSetting = $this->getCurrentClinicSetting() ?? new ClinicSetting();
        $previousDailyOperatingHours = $this->normalizeDailyOperatingHours(
            $clinicSetting?->daily_operating_hours,
            $clinicSetting?->working_days ?? [],
            $clinicSetting?->opening_time,
            $clinicSetting?->closing_time,
        );
        $dailyOperatingHours = $this->normalizeDailyOperatingHours(
            $payload['daily_operating_hours'] ?? null,
            $payload['working_days'] ?? [],
            $payload['opening_time'] ?? null,
            $payload['closing_time'] ?? null,
        );

        $clinicSetting->fill([
            'clinic_title' => $this->resolveNullableTextField(
                $payload,
                'clinic_title',
                $clinicSetting->clinic_title,
            ),
            'practice_license_id' => $this->resolveNullableTextField(
                $payload,
                'practice_license_id',
                $clinicSetting->practice_license_id,
            ),
            'operational_hotline' => $this->resolveNullableTextField(
                $payload,
                'operational_hotline',
                $clinicSetting->operational_hotline,
            ),
            'clinic_headquarters' => $this->resolveNullableTextField(
                $payload,
                'clinic_headquarters',
                $clinicSetting->clinic_headquarters,
            ),
            'opening_time' => $this->resolveLegacyOpeningTime($dailyOperatingHours),
            'closing_time' => $this->resolveLegacyClosingTime($dailyOperatingHours),
            'working_days' => array_keys($dailyOperatingHours),
            'daily_operating_hours' => $dailyOperatingHours,
            'updated_by_user_id' => (int) $user->id,
        ]);
        $clinicSetting->save();
        $clinicSetting->load('updatedBy');
        $this->applyScheduleChangesToExistingAppointments(
            $previousDailyOperatingHours,
            $dailyOperatingHours,
        );

        return $this->formatSettings($clinicSetting);
    }

    public function formatSettings(?ClinicSetting $clinicSetting): array
    {
        $dailyOperatingHours = $this->normalizeDailyOperatingHours(
            $clinicSetting?->daily_operating_hours,
            $clinicSetting?->working_days ?? [],
            $clinicSetting?->opening_time,
            $clinicSetting?->closing_time,
        );

        return [
            'clinic_title' => $clinicSetting?->clinic_title,
            'practice_license_id' => $clinicSetting?->practice_license_id,
            'operational_hotline' => $clinicSetting?->operational_hotline,
            'clinic_headquarters' => $clinicSetting?->clinic_headquarters,
            'opening_time' => $this->resolveLegacyOpeningTime($dailyOperatingHours),
            'closing_time' => $this->resolveLegacyClosingTime($dailyOperatingHours),
            'working_days' => array_keys($dailyOperatingHours),
            'daily_operating_hours' => $dailyOperatingHours,
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

    /**
     * @param  mixed  $rawDailyOperatingHours
     * @param  array<int, mixed>  $legacyWorkingDays
     * @return array<string, array{opening_time: string, closing_time: string}>
     */
    private function normalizeDailyOperatingHours(
        mixed $rawDailyOperatingHours,
        array $legacyWorkingDays = [],
        mixed $legacyOpeningTime = null,
        mixed $legacyClosingTime = null,
    ): array {
        $normalized = [];

        if (is_array($rawDailyOperatingHours)) {
            foreach (self::WEEK_DAYS as $weekDay) {
                $rawSchedule = $rawDailyOperatingHours[$weekDay] ?? null;
                if (! is_array($rawSchedule)) {
                    continue;
                }

                $openingTime = $this->formatTime($rawSchedule['opening_time'] ?? null);
                $closingTime = $this->formatTime($rawSchedule['closing_time'] ?? null);

                if ($openingTime === null || $closingTime === null) {
                    continue;
                }

                $normalized[$weekDay] = [
                    'opening_time' => $openingTime,
                    'closing_time' => $closingTime,
                ];
            }
        }

        if ($normalized !== []) {
            return $normalized;
        }

        $legacyDays = $this->normalizeWorkingDays($legacyWorkingDays);
        $openingTime = $this->formatTime($legacyOpeningTime);
        $closingTime = $this->formatTime($legacyClosingTime);

        if ($legacyDays === [] || $openingTime === null || $closingTime === null) {
            return [];
        }

        foreach ($legacyDays as $legacyDay) {
            $normalized[$legacyDay] = [
                'opening_time' => $openingTime,
                'closing_time' => $closingTime,
            ];
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

    /**
     * @param  array<string, array{opening_time: string, closing_time: string}>  $dailyOperatingHours
     */
    private function resolveLegacyOpeningTime(array $dailyOperatingHours): ?string
    {
        if ($dailyOperatingHours === []) {
            return null;
        }

        $firstDay = array_key_first($dailyOperatingHours);

        return $firstDay !== null ? $dailyOperatingHours[$firstDay]['opening_time'] : null;
    }

    /**
     * @param  array<string, array{opening_time: string, closing_time: string}>  $dailyOperatingHours
     */
    private function resolveLegacyClosingTime(array $dailyOperatingHours): ?string
    {
        if ($dailyOperatingHours === []) {
            return null;
        }

        $firstDay = array_key_first($dailyOperatingHours);

        return $firstDay !== null ? $dailyOperatingHours[$firstDay]['closing_time'] : null;
    }

    private function resolveNullableTextField(array $payload, string $key, mixed $fallback): ?string
    {
        if (! array_key_exists($key, $payload)) {
            return $fallback !== null ? (string) $fallback : null;
        }

        $value = trim((string) $payload[$key]);

        return $value !== '' ? $value : null;
    }

    private function getCurrentClinicSetting(): ?ClinicSetting
    {
        return ClinicSetting::query()
            ->with('updatedBy')
            ->latest('id')
            ->first();
    }

    /**
     * @param  array<string, array{opening_time: string, closing_time: string}>  $previousDailyOperatingHours
     * @param  array<string, array{opening_time: string, closing_time: string}>  $currentDailyOperatingHours
     */
    private function applyScheduleChangesToExistingAppointments(
        array $previousDailyOperatingHours,
        array $currentDailyOperatingHours,
    ): void {
        $changedDays = [];

        foreach (self::WEEK_DAYS as $weekDay) {
            $previous = $previousDailyOperatingHours[$weekDay] ?? null;
            $current = $currentDailyOperatingHours[$weekDay] ?? null;

            if ($previous !== $current) {
                $changedDays[] = $weekDay;
            }
        }

        if ($changedDays === []) {
            return;
        }

        $timezone = (string) config('app.timezone', 'UTC');
        $today = Carbon::today($timezone)->toDateString();

        $appointments = Appointment::query()
            ->with(['service'])
            ->whereDate('appointment_date', '>=', $today)
            ->whereNull('deleted_at')
            ->whereIn('status', ['pending', 'confirmed'])
            ->get()
            ->filter(function (Appointment $appointment) use (
                $changedDays,
                $currentDailyOperatingHours,
                $timezone,
            ): bool {
                $dayName = Carbon::createFromFormat(
                    'Y-m-d',
                    (string) $appointment->appointment_date,
                    $timezone,
                )->format('l');

                if (! in_array($dayName, $changedDays, true)) {
                    return false;
                }

                $schedule = $currentDailyOperatingHours[$dayName] ?? null;
                if ($schedule === null) {
                    return true;
                }

                $appointmentTime = $this->normalizeTimeString(
                    (string) $appointment->time_slot,
                );
                if ($appointmentTime === null) {
                    return false;
                }

                return $appointmentTime < $schedule['opening_time']
                    || $appointmentTime >= $schedule['closing_time'];
            })
            ->values();

        if ($appointments->isEmpty()) {
            return;
        }

        $affectedDates = [];

        foreach ($appointments as $appointment) {
            $newStatus = (string) $appointment->status === 'confirmed'
                ? 'cancelled_by_doctor'
                : 'reschedule_required';
            $appointment->forceFill(['status' => $newStatus])->save();

            $notificationMeta = $this->buildScheduleChangeNotificationMeta(
                $newStatus,
            );
            PatientNotification::create([
                'patient_id' => (int) $appointment->patient_id,
                'appointment_id' => (int) $appointment->id,
                'type' => $notificationMeta['type'],
                'title' => $notificationMeta['title'],
                'message' => $this->buildScheduleChangeNotificationMessage(
                    $appointment,
                ),
            ]);

            $affectedDates[(string) $appointment->appointment_date] = true;
        }

        foreach (array_keys($affectedDates) as $affectedDate) {
            $this->queueService->syncQueueNumbersForDate($affectedDate);
        }
    }

    private function normalizeTimeString(string $value): ?string
    {
        $trimmed = trim($value);

        try {
            return Carbon::parse($trimmed)->format('H:i');
        } catch (\Throwable) {
            return null;
        }
    }

    /**
     * @return array{type: string, title: string}
     */
    private function buildScheduleChangeNotificationMeta(string $status): array
    {
        return match ($status) {
            'cancelled_by_doctor' => [
                'type' => 'appointment_cancelled_by_doctor',
                'title' => 'Appointment Cancelled by Doctor',
            ],
            default => [
                'type' => 'appointment_reschedule_required',
                'title' => 'Appointment Needs Reschedule',
            ],
        };
    }

    private function buildScheduleChangeNotificationMessage(
        Appointment $appointment,
    ): string {
        $serviceName = trim((string) ($appointment->service?->name ?? 'your appointment'));
        $status = AppointmentService::humanStatusLabel((string) $appointment->status);
        $message = sprintf(
            'Your appointment for %s on %s at %s is affected because the clinic schedule changed. Status updated to %s.',
            $serviceName !== '' ? $serviceName : 'your appointment',
            (string) $appointment->appointment_date,
            (string) $appointment->time_slot,
            $status,
        );

        if ((string) $appointment->status === 'cancelled_by_doctor') {
            return $message . ' The clinic will contact you for follow-up on the cancellation.';
        }

        return $message . ' Please contact the clinic to reschedule.';
    }
}
