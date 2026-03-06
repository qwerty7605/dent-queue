<?php

namespace App\Services;

use App\Models\Appointment;
use App\Models\Queue;
use Illuminate\Database\QueryException;
use Illuminate\Support\Facades\DB;
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

        return DB::transaction(function () use ($data, $validatedBooking) {
            $appointment = $this->createAppointmentRecord($data, $validatedBooking);
            $this->assignQueueNumberOrFail(
                appointmentId: (int) $appointment->id,
                appointmentDate: (string) $validatedBooking['appointment_date'],
            );

            return $appointment->load(['patient', 'queue']);
        });
    }

    private function createAppointmentRecord(array $data, array $validatedBooking): Appointment
    {
        try {
            return Appointment::create([
                'patient_id' => $data['patient_id'],
                'service_id' => $data['service_id'],
                'appointment_date' => $validatedBooking['appointment_date'],
                'time_slot' => $validatedBooking['time_slot'],
                'status' => 'pending',
            ]);
        }
        catch (QueryException $exception) {
            if ($this->isUniqueConstraintViolation($exception)) {
                throw ValidationException::withMessages([
                    'time_slot' => ['This patient already has a booking for the selected date and time.'],
                ]);
            }

            throw $exception;
        }
    }

    private function assignQueueNumberOrFail(int $appointmentId, string $appointmentDate): void
    {
        for ($attempt = 0; $attempt < self::MAX_QUEUE_ASSIGNMENT_RETRIES; $attempt++) {
            $lastQueue = Queue::where('queue_date', $appointmentDate)
                ->lockForUpdate()
                ->orderByDesc('queue_number')
                ->first();

            $nextQueueNumber = $lastQueue ? ((int) $lastQueue->queue_number + 1) : 1;
            if ($nextQueueNumber > self::DAILY_QUEUE_LIMIT) {
                throw ValidationException::withMessages([
                    'appointment_date' => ['The daily limit of 50 patients has been reached for this date.'],
                ]);
            }

            try {
                Queue::create([
                    'appointment_id' => $appointmentId,
                    'queue_date' => $appointmentDate,
                    'queue_number' => $nextQueueNumber,
                    'is_called' => false,
                ]);

                return;
            }
            catch (QueryException $exception) {
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
}
