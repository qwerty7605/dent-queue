<?php

namespace App\Services;

use App\Models\Queue;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\Validator;
use Illuminate\Validation\ValidationException;

class BookingRulesEngine
{
    private const DEFAULT_OPEN_TIME = '07:30';
    private const DEFAULT_CLOSE_TIME = '18:00';
    private const DEFAULT_WORKING_DAYS = [
        'Monday',
        'Tuesday',
        'Wednesday',
        'Thursday',
        'Friday',
        'Saturday',
    ];
    private const WEEK_DAYS = [
        'Sunday',
        'Monday',
        'Tuesday',
        'Wednesday',
        'Thursday',
        'Friday',
        'Saturday',
    ];

    public function __construct(protected ClinicSettingService $clinicSettingService)
    {
    }

    /**
     * Validate booking date/time business rules and normalize time format.
     *
     * @throws \Illuminate\Validation\ValidationException
     */
    public function validate(array $payload): array
    {
        $validator = Validator::make(
            $payload,
            [
                'appointment_date' => ['required', 'date_format:Y-m-d'],
                'time_slot' => ['required', 'string'],
            ],
            [
                'appointment_date.required' => 'Appointment date is required.',
                'appointment_date.date_format' => 'Appointment date must be in YYYY-MM-DD format.',
                'time_slot.required' => 'Appointment time is required.',
                'time_slot.string' => 'Appointment time must be a valid string.',
            ]
        );

        $timezone = (string) config('app.timezone', 'UTC');
        $clinicSchedule = $this->resolveClinicSchedule($timezone);

        $validator->after(function ($validator) use ($payload, $timezone, $clinicSchedule): void {
            if (isset($payload['appointment_date'])) {
                $appointmentDate = $this->parseDate((string) $payload['appointment_date'], $timezone);

                if ($appointmentDate !== null) {
                    if ($appointmentDate->isBefore(Carbon::today($timezone))) {
                        $validator->errors()->add('appointment_date', 'Past dates are not allowed for bookings.');
                    }

                    if (!in_array($appointmentDate->englishDayOfWeek, $clinicSchedule['working_days'], true)) {
                        $validator->errors()->add(
                            'appointment_date',
                            $this->resolveWorkingDayErrorMessage($appointmentDate, $clinicSchedule['uses_default_working_days']),
                        );
                    }

                    $appointmentCount = Queue::where('queue_date', $appointmentDate->toDateString())
                        ->count();

                    if ($appointmentCount >= 50) {
                        $validator->errors()->add('appointment_date', 'The daily limit of 50 patients has been reached for this date.');
                    }
                }
            }

            if (!isset($payload['time_slot'])) {
                return;
            }

            $normalizedTimeSlot = $this->normalizeTimeSlot((string) $payload['time_slot'], $timezone);
            if ($normalizedTimeSlot === null) {
                $validator->errors()->add('time_slot', 'Time must be a valid time (HH:MM or HH:MM AM/PM).');
                return;
            }

            $slot = Carbon::createFromFormat('H:i', $normalizedTimeSlot, $timezone);
            $open = Carbon::createFromFormat('H:i', $clinicSchedule['opening_time'], $timezone);
            $close = Carbon::createFromFormat('H:i', $clinicSchedule['closing_time'], $timezone);

            if ($slot->lt($open) || $slot->gt($close)) {
                $validator->errors()->add(
                    'time_slot',
                    $clinicSchedule['uses_default_time_range']
                        ? 'Booking time must be between 07:30 AM and 6:00 PM.'
                        : sprintf(
                            'Booking time must be between %s and %s.',
                            $open->format('g:i A'),
                            $close->format('g:i A'),
                        ),
                );
            }
        });

        if ($validator->fails()) {
            throw new ValidationException($validator);
        }

        $validated = $validator->validated();
        $validated['time_slot'] = $this->normalizeTimeSlot((string) $payload['time_slot'], $timezone) ?? (string) $payload['time_slot'];

        return $validated;
    }

    /**
     * @return array{opening_time: string, closing_time: string, working_days: array<int, string>, uses_default_working_days: bool, uses_default_time_range: bool}
     */
    private function resolveClinicSchedule(string $timezone): array
    {
        $settings = $this->clinicSettingService->getCurrentSettings();
        $openingTime = $this->normalizeConfiguredTime($settings['opening_time'] ?? null, $timezone) ?? self::DEFAULT_OPEN_TIME;
        $closingTime = $this->normalizeConfiguredTime($settings['closing_time'] ?? null, $timezone) ?? self::DEFAULT_CLOSE_TIME;
        $usesDefaultTimeRange = $openingTime === self::DEFAULT_OPEN_TIME
            && $closingTime === self::DEFAULT_CLOSE_TIME;

        if (!$this->hasValidTimeRange($openingTime, $closingTime, $timezone)) {
            $openingTime = self::DEFAULT_OPEN_TIME;
            $closingTime = self::DEFAULT_CLOSE_TIME;
            $usesDefaultTimeRange = true;
        }

        $workingDays = $this->normalizeWorkingDays($settings['working_days'] ?? null);
        $usesDefaultWorkingDays = $workingDays === [];

        if ($usesDefaultWorkingDays) {
            $workingDays = self::DEFAULT_WORKING_DAYS;
        }

        return [
            'opening_time' => $openingTime,
            'closing_time' => $closingTime,
            'working_days' => $workingDays,
            'uses_default_working_days' => $usesDefaultWorkingDays,
            'uses_default_time_range' => $usesDefaultTimeRange,
        ];
    }

    private function parseDate(string $value, string $timezone): ?Carbon
    {
        try {
            return Carbon::createFromFormat('Y-m-d', trim($value), $timezone)->startOfDay();
        }
        catch (\Throwable) {
            return null;
        }
    }

    private function normalizeConfiguredTime(mixed $value, string $timezone): ?string
    {
        if ($value === null || trim((string) $value) === '') {
            return null;
        }

        return $this->normalizeTimeSlot((string) $value, $timezone);
    }

    private function hasValidTimeRange(string $openingTime, string $closingTime, string $timezone): bool
    {
        try {
            $open = Carbon::createFromFormat('H:i', $openingTime, $timezone);
            $close = Carbon::createFromFormat('H:i', $closingTime, $timezone);

            return $close->gt($open);
        }
        catch (\Throwable) {
            return false;
        }
    }

    /**
     * @param  mixed  $workingDays
     * @return array<int, string>
     */
    private function normalizeWorkingDays(mixed $workingDays): array
    {
        if (!is_array($workingDays)) {
            return [];
        }

        $selectedLookup = [];

        foreach ($workingDays as $workingDay) {
            $selectedLookup[mb_strtolower(trim((string) $workingDay))] = true;
        }

        $normalized = [];

        foreach (self::WEEK_DAYS as $weekDay) {
            if (isset($selectedLookup[mb_strtolower($weekDay)])) {
                $normalized[] = $weekDay;
            }
        }

        return $normalized;
    }

    private function resolveWorkingDayErrorMessage(Carbon $appointmentDate, bool $usesDefaultWorkingDays): string
    {
        if ($usesDefaultWorkingDays && $appointmentDate->isSunday()) {
            return 'Sunday bookings are not allowed.';
        }

        return 'Booking date must fall on a selected working day.';
    }

    private function normalizeTimeSlot(string $value, string $timezone): ?string
    {
        $formats = ['H:i', 'H:i:s', 'g:i A', 'g:i a', 'h:i A', 'h:i a'];

        foreach ($formats as $format) {
            try {
                return Carbon::createFromFormat($format, trim($value), $timezone)->format('H:i');
            }
            catch (\Throwable) {
                // Try next supported format.
            }
        }

        return null;
    }
}
