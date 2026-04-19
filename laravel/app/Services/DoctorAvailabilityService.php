<?php

namespace App\Services;

use App\Models\Appointment;
use App\Models\DoctorUnavailability;
use App\Models\PatientNotification;
use App\Models\User;
use Illuminate\Database\Eloquent\Collection;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

class DoctorAvailabilityService
{
    private const SLOT_DURATION_MINUTES = 30;
    private const DEFAULT_OPEN_TIME = '07:30';
    private const DEFAULT_CLOSE_TIME = '18:00';

    public function __construct(
        private readonly ClinicSettingService $clinicSettingService,
    ) {
    }

    public function create(User $user, array $payload): DoctorUnavailability
    {
        $schedule = $this->validateSchedulePayload($payload);

        $this->assertScheduleDoesNotOverlap(
            $schedule['unavailable_date'],
            $schedule['start_time'],
            $schedule['end_time'],
        );

        return DB::transaction(function () use ($schedule, $user): DoctorUnavailability {
            $doctorUnavailability = DoctorUnavailability::query()->create([
                'unavailable_date' => $schedule['unavailable_date'],
                'start_time' => $schedule['start_time'],
                'end_time' => $schedule['end_time'],
                'reason' => $schedule['reason'] ?? null,
                'created_by_user_id' => (int) $user->id,
            ]);

            $this->notifyAffectedPatients($doctorUnavailability);

            return $doctorUnavailability;
        });
    }

    public function delete(DoctorUnavailability $doctorUnavailability): void
    {
        $doctorUnavailability->delete();
    }

    /**
     * @return array<int, array<string, mixed>>
     */
    public function getUpcomingSchedules(): array
    {
        return DoctorUnavailability::query()
            ->with('createdBy:id,first_name,last_name')
            ->orderBy('unavailable_date')
            ->orderBy('start_time')
            ->get()
            ->map(fn (DoctorUnavailability $schedule): array => $this->serializeSchedule($schedule))
            ->all();
    }

    /**
     * @return array<int, array<string, mixed>>
     */
    public function getSchedulesForDate(string $date): array
    {
        return $this->unavailabilitiesForDate($date)
            ->map(fn (DoctorUnavailability $schedule): array => $this->serializeSchedule($schedule))
            ->all();
    }

    /**
     * @return array{date: string, opening_time: string, closing_time: string, slot_duration_minutes: int, slots: array<int, array<string, mixed>>, unavailable_ranges: array<int, array<string, mixed>>}
     */
    public function getSlotAvailability(string $date, ?int $ignoreAppointmentId = null): array
    {
        $timezone = (string) config('app.timezone', 'UTC');
        $schedule = $this->resolveClinicSchedule($timezone);
        $day = Carbon::createFromFormat('Y-m-d', $date, $timezone)->startOfDay();
        $unavailabilities = $this->unavailabilitiesForDate($date);
        $bookedAppointmentsQuery = Appointment::query()
            ->whereDate('appointment_date', $date)
            ->whereNull('deleted_at')
            ->whereIn('status', ['pending', 'confirmed', 'completed']);

        if ($ignoreAppointmentId !== null) {
            $bookedAppointmentsQuery->whereKeyNot($ignoreAppointmentId);
        }

        $bookedAppointments = $bookedAppointmentsQuery->get(['id', 'time_slot', 'status']);

        $slots = [];
        $current = $this->combineDateAndTime($date, $schedule['opening_time'], $timezone);
        $close = $this->combineDateAndTime($date, $schedule['closing_time'], $timezone);
        $now = Carbon::now($timezone);

        while ($current->lt($close)) {
            $slotStart = $current->copy();
            $slotEnd = $slotStart->copy()->addMinutes(self::SLOT_DURATION_MINUTES);
            $time = $slotStart->format('H:i');
            $reason = null;
            $status = 'available';

            if ($slotEnd->gt($close)) {
                break;
            }

            if ($day->isToday() && $slotStart->lessThanOrEqualTo($now)) {
                $status = 'past';
            }

            foreach ($unavailabilities as $unavailability) {
                if ($this->rangesOverlap(
                    $slotStart,
                    $slotEnd,
                    $this->combineDateAndTime($date, (string) $unavailability->start_time, $timezone),
                    $this->combineDateAndTime($date, (string) $unavailability->end_time, $timezone),
                )) {
                    $status = 'doctor_unavailable';
                    $reason = (string) ($unavailability->reason ?: 'Doctor Unavailable');
                    break;
                }
            }

            if ($status === 'available') {
                foreach ($bookedAppointments as $appointment) {
                    $existingTime = $this->normalizeTimeString((string) $appointment->time_slot, $timezone);

                    if ($existingTime !== null && $existingTime === $time) {
                        $status = 'booked';
                        $reason = 'Already booked';
                        break;
                    }
                }
            }

            $slots[] = [
                'time' => $time,
                'time_label' => $slotStart->format('g:i A'),
                'status' => $status,
                'is_available' => $status === 'available',
                'label' => match ($status) {
                    'doctor_unavailable' => 'Doctor Unavailable',
                    'booked' => 'Booked',
                    'past' => 'Past',
                    default => 'Available',
                },
                'reason' => $reason,
            ];

            $current->addMinutes(self::SLOT_DURATION_MINUTES);
        }

        return [
            'date' => $date,
            'opening_time' => $schedule['opening_time'],
            'closing_time' => $schedule['closing_time'],
            'slot_duration_minutes' => self::SLOT_DURATION_MINUTES,
            'slots' => $slots,
            'unavailable_ranges' => $unavailabilities
                ->map(fn (DoctorUnavailability $item): array => $this->serializeSchedule($item))
                ->all(),
        ];
    }

    public function assertDateTimeAvailable(
        string $date,
        string $timeSlot,
        ?int $ignoreAppointmentId = null,
    ): void {
        $timezone = (string) config('app.timezone', 'UTC');
        $normalizedTime = $this->normalizeTimeString($timeSlot, $timezone) ?? $timeSlot;
        $slotStart = $this->combineDateAndTime($date, $normalizedTime, $timezone);
        $slotEnd = $slotStart->copy()->addMinutes(self::SLOT_DURATION_MINUTES);

        foreach ($this->unavailabilitiesForDate($date) as $unavailability) {
            $blockedStart = $this->combineDateAndTime($date, (string) $unavailability->start_time, $timezone);
            $blockedEnd = $this->combineDateAndTime($date, (string) $unavailability->end_time, $timezone);

            if ($this->rangesOverlap($slotStart, $slotEnd, $blockedStart, $blockedEnd)) {
                throw ValidationException::withMessages([
                    'time_slot' => [
                        $unavailability->reason !== null && trim((string) $unavailability->reason) !== ''
                            ? sprintf('Doctor Unavailable: %s', trim((string) $unavailability->reason))
                            : 'Doctor Unavailable for the selected time slot.',
                    ],
                ]);
            }
        }

        $activeAppointments = Appointment::query()
            ->whereDate('appointment_date', $date)
            ->whereNull('deleted_at')
            ->whereIn('status', ['pending', 'confirmed', 'completed']);

        if ($ignoreAppointmentId !== null) {
            $activeAppointments->whereKeyNot($ignoreAppointmentId);
        }

        /** @var Collection<int, Appointment> $appointments */
        $appointments = $activeAppointments->get(['id', 'time_slot']);

        foreach ($appointments as $appointment) {
            $existingTime = $this->normalizeTimeString((string) $appointment->time_slot, $timezone);
            if ($existingTime === null) {
                continue;
            }

            if ($existingTime === $normalizedTime) {
                throw ValidationException::withMessages([
                    'time_slot' => ['This time slot is already booked. Please choose another time.'],
                ]);
            }
        }
    }

    public function normalizeTimeString(string $value, string $timezone = 'UTC'): ?string
    {
        $trimmed = trim($value);

        foreach (['H:i', 'H:i:s', 'g:i A', 'g:iA'] as $format) {
            try {
                return Carbon::createFromFormat($format, $trimmed, $timezone)->format('H:i');
            } catch (\Throwable) {
                continue;
            }
        }

        try {
            return Carbon::parse($trimmed, $timezone)->format('H:i');
        } catch (\Throwable) {
            return null;
        }
    }

    /**
     * @return array{opening_time: string, closing_time: string}
     */
    private function resolveClinicSchedule(string $timezone): array
    {
        $settings = $this->clinicSettingService->getCurrentSettings();
        $openingTime = $this->normalizeTimeString((string) ($settings['opening_time'] ?? ''), $timezone) ?? self::DEFAULT_OPEN_TIME;
        $closingTime = $this->normalizeTimeString((string) ($settings['closing_time'] ?? ''), $timezone) ?? self::DEFAULT_CLOSE_TIME;

        return [
            'opening_time' => $openingTime,
            'closing_time' => $closingTime,
        ];
    }

    private function assertScheduleDoesNotOverlap(
        string $date,
        string $startTime,
        string $endTime,
        ?int $ignoreId = null,
    ): void {
        $timezone = (string) config('app.timezone', 'UTC');
        $newStart = $this->combineDateAndTime($date, $startTime, $timezone);
        $newEnd = $this->combineDateAndTime($date, $endTime, $timezone);

        $query = DoctorUnavailability::query()
            ->whereDate('unavailable_date', $date);

        if ($ignoreId !== null) {
            $query->whereKeyNot($ignoreId);
        }

        foreach ($query->get(['id', 'start_time', 'end_time']) as $existing) {
            if ($this->rangesOverlap(
                $newStart,
                $newEnd,
                $this->combineDateAndTime($date, (string) $existing->start_time, $timezone),
                $this->combineDateAndTime($date, (string) $existing->end_time, $timezone),
            )) {
                throw ValidationException::withMessages([
                    'start_time' => ['This unavailable schedule overlaps with an existing blocked range.'],
                ]);
            }
        }
    }

    /**
     * @return array{unavailable_date: string, start_time: string, end_time: string, reason: ?string}
     */
    private function validateSchedulePayload(array $payload): array
    {
        $timezone = (string) config('app.timezone', 'UTC');
        $date = Carbon::createFromFormat('Y-m-d', (string) $payload['unavailable_date'], $timezone)->toDateString();
        $startTime = $this->normalizeTimeString((string) $payload['start_time'], $timezone);
        $endTime = $this->normalizeTimeString((string) $payload['end_time'], $timezone);

        if ($startTime === null) {
            throw ValidationException::withMessages([
                'start_time' => ['Start time must be a valid time.'],
            ]);
        }

        if ($endTime === null) {
            throw ValidationException::withMessages([
                'end_time' => ['End time must be a valid time.'],
            ]);
        }

        if ($this->combineDateAndTime($date, $endTime, $timezone)->lessThanOrEqualTo(
            $this->combineDateAndTime($date, $startTime, $timezone),
        )) {
            throw ValidationException::withMessages([
                'end_time' => ['End time must be later than start time.'],
            ]);
        }

        return [
            'unavailable_date' => $date,
            'start_time' => $startTime,
            'end_time' => $endTime,
            'reason' => isset($payload['reason']) ? trim((string) $payload['reason']) : null,
        ];
    }

    /**
     * @return Collection<int, DoctorUnavailability>
     */
    private function unavailabilitiesForDate(string $date): Collection
    {
        return DoctorUnavailability::query()
            ->whereDate('unavailable_date', $date)
            ->orderBy('start_time')
            ->get();
    }

    /**
     * @return Collection<int, Appointment>
     */
    private function affectedAppointmentsForSchedule(DoctorUnavailability $schedule): Collection
    {
        $timezone = (string) config('app.timezone', 'UTC');
        $date = (string) $schedule->unavailable_date;
        $blockedStart = $this->combineDateAndTime($date, (string) $schedule->start_time, $timezone);
        $blockedEnd = $this->combineDateAndTime($date, (string) $schedule->end_time, $timezone);

        return Appointment::query()
            ->with(['patient', 'service'])
            ->whereDate('appointment_date', $date)
            ->whereNull('deleted_at')
            ->whereIn('status', ['pending', 'confirmed'])
            ->get()
            ->filter(function (Appointment $appointment) use ($date, $timezone, $blockedStart, $blockedEnd): bool {
                $normalizedTime = $this->normalizeTimeString((string) $appointment->time_slot, $timezone);
                if ($normalizedTime === null) {
                    return false;
                }

                $appointmentTime = $this->combineDateAndTime($date, $normalizedTime, $timezone);

                return $appointmentTime->greaterThanOrEqualTo($blockedStart)
                    && $appointmentTime->lessThan($blockedEnd);
            })
            ->values();
    }

    private function combineDateAndTime(string $date, string $time, string $timezone): Carbon
    {
        $normalizedTime = $this->normalizeTimeString($time, $timezone) ?? $time;

        return Carbon::createFromFormat('Y-m-d H:i', sprintf('%s %s', $date, $normalizedTime), $timezone);
    }

    private function rangesOverlap(
        Carbon $firstStart,
        Carbon $firstEnd,
        Carbon $secondStart,
        Carbon $secondEnd,
    ): bool {
        return $firstStart->lt($secondEnd) && $firstEnd->gt($secondStart);
    }

    private function notifyAffectedPatients(DoctorUnavailability $schedule): void
    {
        foreach ($this->affectedAppointmentsForSchedule($schedule) as $appointment) {
            PatientNotification::create([
                'patient_id' => (int) $appointment->patient_id,
                'appointment_id' => (int) $appointment->id,
                'type' => 'doctor_unavailable',
                'title' => 'Appointment affected by doctor unavailability',
                'message' => $this->buildAffectedAppointmentMessage($appointment, $schedule),
            ]);
        }
    }

    private function buildAffectedAppointmentMessage(
        Appointment $appointment,
        DoctorUnavailability $schedule,
    ): string {
        $serviceName = trim((string) ($appointment->service?->name ?? 'your appointment'));
        $reason = trim((string) ($schedule->reason ?? ''));

        $message = sprintf(
            'Your appointment for %s on %s at %s is no longer available because the doctor is unavailable.',
            $serviceName !== '' ? $serviceName : 'your appointment',
            (string) $appointment->appointment_date,
            (string) $appointment->time_slot,
        );

        if ($reason !== '') {
            $message .= ' Reason: ' . $reason . '.';
        }

        return $message . ' Please contact the clinic to reschedule.';
    }

    /**
     * @return array<string, mixed>
     */
    private function serializeSchedule(DoctorUnavailability $schedule): array
    {
        return [
            'id' => (int) $schedule->id,
            'unavailable_date' => (string) $schedule->unavailable_date,
            'start_time' => mb_substr((string) $schedule->start_time, 0, 5),
            'end_time' => mb_substr((string) $schedule->end_time, 0, 5),
            'reason' => $schedule->reason,
            'created_by_user_id' => $schedule->created_by_user_id !== null ? (int) $schedule->created_by_user_id : null,
            'created_by_name' => $schedule->createdBy !== null
                ? trim(sprintf('%s %s', (string) $schedule->createdBy->first_name, (string) $schedule->createdBy->last_name))
                : null,
        ];
    }
}
