<?php

namespace App\Services;

use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\Validator;
use Illuminate\Validation\ValidationException;

class BookingRulesEngine
{
    private const OPEN_TIME = '07:30';
    private const CLOSE_TIME = '18:00';

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

        $validator->after(function ($validator) use ($payload): void {
            $timezone = (string) config('app.timezone', 'UTC');

            if (isset($payload['appointment_date'])) {
                $appointmentDate = $this->parseDate((string) $payload['appointment_date'], $timezone);

                if ($appointmentDate !== null) {
                    if ($appointmentDate->isBefore(Carbon::today($timezone))) {
                        $validator->errors()->add('appointment_date', 'Past dates are not allowed for bookings.');
                    }

                    if ($appointmentDate->isSunday()) {
                        $validator->errors()->add('appointment_date', 'Sunday bookings are not allowed.');
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
            $open = Carbon::createFromFormat('H:i', self::OPEN_TIME, $timezone);
            $close = Carbon::createFromFormat('H:i', self::CLOSE_TIME, $timezone);

            if ($slot->lt($open) || $slot->gt($close)) {
                $validator->errors()->add('time_slot', 'Booking time must be between 07:30 AM and 6:00 PM.');
            }
        });

        if ($validator->fails()) {
            throw new ValidationException($validator);
        }

        $validated = $validator->validated();
        $timezone = (string) config('app.timezone', 'UTC');
        $validated['time_slot'] = $this->normalizeTimeSlot((string) $payload['time_slot'], $timezone) ?? (string) $payload['time_slot'];

        return $validated;
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
