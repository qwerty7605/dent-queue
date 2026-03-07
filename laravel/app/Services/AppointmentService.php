<?php

namespace App\Services;

use App\Models\Appointment;
use App\Models\Queue;
use Illuminate\Database\QueryException;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;
use Illuminate\Validation\ValidationException;

class AppointmentService
{
    private const DAILY_QUEUE_LIMIT = 50;
    private const MAX_QUEUE_ASSIGNMENT_RETRIES = 5;
    private const STATUS_PENDING = 'pending';
    private const STATUS_CONFIRMED = 'confirmed';
    private const STATUS_CANCELLED = 'cancelled';
    private const STATUS_COMPLETED = 'completed';
    private const STATUS_ALIASES = [
        self::STATUS_PENDING => self::STATUS_PENDING,
        'approved' => self::STATUS_CONFIRMED,
        self::STATUS_CONFIRMED => self::STATUS_CONFIRMED,
        self::STATUS_CANCELLED => self::STATUS_CANCELLED,
        self::STATUS_COMPLETED => self::STATUS_COMPLETED,
    ];
    private const STATUS_TRANSITIONS = [
        self::STATUS_PENDING => [self::STATUS_CONFIRMED, self::STATUS_CANCELLED],
        self::STATUS_CONFIRMED => [self::STATUS_COMPLETED, self::STATUS_CANCELLED],
        self::STATUS_COMPLETED => [],
        self::STATUS_CANCELLED => [],
    ];

    public function __construct(protected BookingRulesEngine $bookingRulesEngine)
    {
    }

    public function getAllAppointments()
    {
        return Appointment::with(['patient', 'queue'])
            ->orderBy('appointment_date')
            ->orderBy('time_slot')
            ->get();
    }

    public function createAppointment(array $data)
    {
        $validatedBooking = $this->bookingRulesEngine->validate($data);

        $existingAppointment = Appointment::where('patient_id', $data['patient_id'])
            ->where('appointment_date', $validatedBooking['appointment_date'])
            ->whereIn('status', ['pending', 'confirmed', 'completed'])
            ->exists();

        if ($existingAppointment) {
            throw ValidationException::withMessages([
                'appointment_date' => ['You already have a booking for this date.'],
            ]);
        }

        return DB::transaction(function () use ($data, $validatedBooking) {
            try {
                $appointment = Appointment::create([
                    'patient_id' => $data['patient_id'],
                    'service_id' => $data['service_id'],
                    'appointment_date' => $validatedBooking['appointment_date'],
                    'time_slot' => $validatedBooking['time_slot'],
                    'status' => self::STATUS_PENDING,
                    'notes' => $data['notes'] ?? null,
                ]);
            } catch (QueryException $exception) {
                if ($this->isUniqueConstraintViolation($exception)) {
                    throw ValidationException::withMessages([
                        'time_slot' => ['This patient already has a booking for the selected date and time.'],
                    ]);
                }
                throw $exception;
            }

            for ($attempt = 0; $attempt < self::MAX_QUEUE_ASSIGNMENT_RETRIES; $attempt++) {
                $lastQueue = Queue::where('queue_date', $validatedBooking['appointment_date'])
                    ->lockForUpdate()
                    ->orderByDesc('queue_number')
                    ->first();

                $nextQueueNumber = $lastQueue ? ((int) $lastQueue->queue_number + 1) : 1;

                if ($nextQueueNumber > self::DAILY_QUEUE_LIMIT) {
                    throw ValidationException::withMessages([
                        'appointment_date' => ['The daily limit of ' . self::DAILY_QUEUE_LIMIT . ' patients has been reached for this date.'],
                    ]);
                }

                try {
                    Queue::create([
                        'appointment_id' => $appointment->id,
                        'queue_date' => $validatedBooking['appointment_date'],
                        'queue_number' => $nextQueueNumber,
                        'is_called' => false,
                    ]);

                    return $appointment->load(['patient', 'queue']);
                } catch (QueryException $exception) {
                    if (!$this->isUniqueConstraintViolation($exception)) {
                        throw $exception;
                    }

                    if ($attempt === self::MAX_QUEUE_ASSIGNMENT_RETRIES - 1) {
                        throw ValidationException::withMessages([
                            'appointment_date' => ['Unable to assign a queue number right now. Please retry.'],
                        ]);
                    }
                }
            }
        });
    }

    private function isUniqueConstraintViolation(QueryException $exception): bool
    {
        $sqlState = (string) ($exception->errorInfo[0] ?? $exception->getCode());
        if ($sqlState === '23000' || $sqlState === '23505') {
            return true;
        }

        $message = mb_strtolower($exception->getMessage());

        return str_contains($message, 'unique constraint')
            || str_contains($message, 'duplicate entry')
            || str_contains($message, 'is not unique');
    }

    public function updateStatus(Appointment $appointment, string $status)
    {
        $targetStatus = $this->normalizeStatus($status);
        if ($targetStatus === null) {
            throw ValidationException::withMessages([
                'status' => ['Status must be one of: pending, approved, cancelled, completed.'],
            ]);
        }

        $currentStatus = $this->normalizeStatus((string) $appointment->status);
        if ($currentStatus === null) {
            throw ValidationException::withMessages([
                'status' => ['Current appointment status is invalid and cannot be transitioned.'],
            ]);
        }

        if ($currentStatus !== $targetStatus) {
            $allowedTransitions = self::STATUS_TRANSITIONS[$currentStatus] ?? [];
            if (!in_array($targetStatus, $allowedTransitions, true)) {
                throw ValidationException::withMessages([
                    'status' => [
                        sprintf(
                            'Invalid status transition: %s -> %s.',
                            $this->displayStatusLabel($currentStatus),
                            $this->displayStatusLabel($targetStatus),
                        ),
                    ],
                ]);
            }

            $appointment->update(['status' => $targetStatus]);
        }

        return $appointment->fresh(['patient', 'queue']);
    }

    public function cancelByPatient(Appointment $appointment, int $patientId): Appointment
    {
        $currentStatus = $this->normalizeStatus((string) $appointment->status);

        if (!in_array($currentStatus, [self::STATUS_PENDING, self::STATUS_CONFIRMED], true)) {
            throw ValidationException::withMessages([
                'status' => ['Only pending or approved appointments can be cancelled.'],
            ]);
        }

        $appointment->update(['status' => self::STATUS_CANCELLED]);

        Log::info('appointment.cancelled.by_patient', [
            'appointment_id' => (int) $appointment->id,
            'patient_id' => $patientId,
            'previous_status' => $currentStatus,
            'new_status' => self::STATUS_CANCELLED,
            'occurred_at' => now()->toISOString(),
        ]);

        return $appointment->fresh(['patient', 'queue']);
    }

    private function normalizeStatus(string $status): ?string
    {
        $normalized = mb_strtolower(trim($status));

        return self::STATUS_ALIASES[$normalized] ?? null;
    }

    private function displayStatusLabel(string $status): string
    {
        return match ($status) {
            self::STATUS_CONFIRMED => 'approved',
            default => $status,
        };
    }

    public function getPatientAppointments(int $patientId)
    {
        return Appointment::with(['patient', 'queue'])
            ->where('patient_id', $patientId)
            ->orderBy('appointment_date')
            ->orderBy('time_slot')
            ->get();
    }

    public function getPatientCompletedAppointments(int $patientId)
    {
        return Appointment::with(['patient', 'queue'])
            ->where('patient_id', $patientId)
            ->where('status', self::STATUS_COMPLETED)
            ->orderByDesc('appointment_date')
            ->orderByDesc('time_slot')
            ->get();
    }
}
