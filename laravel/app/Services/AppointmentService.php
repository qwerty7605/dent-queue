<?php

namespace App\Services;

use App\Models\Appointment;
use App\Models\PatientRecord;
use App\Models\PatientNotification;
use App\Models\Queue;
use Illuminate\Database\QueryException;
use Illuminate\Support\Carbon;
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

    public function getMasterList()
    {
        return Appointment::query()
            ->join('patient_records', 'patient_records.id', '=', 'appointments.patient_id')
            ->leftJoin('services', 'services.id', '=', 'appointments.service_id')
            ->orderByDesc('appointments.appointment_date')
            ->orderByDesc('appointments.time_slot')
            ->select([
                'appointments.id as appointment_id',
                'patient_records.first_name',
                'patient_records.middle_name',
                'patient_records.last_name',
                'services.name as service_type',
                'appointments.appointment_date',
                'patient_records.contact_number as contact',
                'appointments.status',
            ])
            ->get()
            ->map(function ($appointment) {
                $middleName = $appointment->middle_name !== null && $appointment->middle_name !== ''
                    ? ' ' . mb_substr((string) $appointment->middle_name, 0, 1) . '.'
                    : '';
                
                $patientName = trim(sprintf(
                    '%s%s %s',
                    (string) $appointment->first_name,
                    $middleName,
                    (string) $appointment->last_name,
                ));
                
                return [
                    'appointment_id' => (int) $appointment->appointment_id,
                    'patient_name' => $patientName,
                    'service' => $appointment->service_type !== null ? (string) $appointment->service_type : 'Unknown Service',
                    'date' => (string) $appointment->appointment_date,
                    'contact' => (string) $appointment->contact,
                    'status' => ucfirst((string) $appointment->status),
                ];
            });
    }

    public function getApprovedAppointmentsByDate(string $date)
    {
        return Appointment::query()
            ->join('queues', 'queues.appointment_id', '=', 'appointments.id')
            ->join('patient_records', 'patient_records.id', '=', 'appointments.patient_id')
            ->leftJoin('services', 'services.id', '=', 'appointments.service_id')
            ->where('appointments.appointment_date', $date)
            ->where('appointments.status', self::STATUS_CONFIRMED)
            ->orderBy('queues.queue_number')
            ->select([
                'appointments.id',
                'appointments.patient_id',
                'appointments.service_id',
                'appointments.appointment_date',
                'appointments.time_slot',
                'appointments.notes',
                'appointments.status',
                'queues.queue_number',
                'patient_records.first_name',
                'patient_records.last_name',
                'services.name as service_name',
            ])
            ->get()
            ->map(function (Appointment $appointment): array {
                return [
                    'id' => (int) $appointment->id,
                    'patient_name' => trim(
                        sprintf('%s %s', (string) $appointment->first_name, (string) $appointment->last_name),
                    ),
                    'service_type' => $this->resolveServiceType(
                        $appointment->service_name !== null ? (string) $appointment->service_name : null,
                        (int) $appointment->service_id,
                    ),
                    'appointment_time' => (string) $appointment->time_slot,
                    'status' => 'Approved',
                    'queue_number' => (int) $appointment->queue_number,
                    'appointment_date' => (string) $appointment->appointment_date,
                    'notes' => (string) ($appointment->notes ?? ''),
                ];
            });
    }

    public function getApprovedAppointmentDetails(int $appointmentId): ?array
    {
        $appointment = Appointment::query()
            ->join('queues', 'queues.appointment_id', '=', 'appointments.id')
            ->join('patient_records', 'patient_records.id', '=', 'appointments.patient_id')
            ->leftJoin('services', 'services.id', '=', 'appointments.service_id')
            ->where('appointments.id', $appointmentId)
            ->where('appointments.status', self::STATUS_CONFIRMED)
            ->select([
                'appointments.id',
                'appointments.patient_id',
                'appointments.service_id',
                'appointments.appointment_date',
                'appointments.time_slot',
                'appointments.notes',
                'appointments.status',
                'queues.queue_number',
                'patient_records.first_name',
                'patient_records.last_name',
                'services.name as service_name',
            ])
            ->first();

        if ($appointment === null) {
            return null;
        }

        return [
            'id' => (int) $appointment->id,
            'patient_name' => trim(
                sprintf('%s %s', (string) $appointment->first_name, (string) $appointment->last_name),
            ),
            'service_type' => $this->resolveServiceType(
                $appointment->service_name !== null ? (string) $appointment->service_name : null,
                (int) $appointment->service_id,
            ),
            'appointment_date' => (string) $appointment->appointment_date,
            'appointment_time' => (string) $appointment->time_slot,
            'queue_number' => (int) $appointment->queue_number,
            'notes' => (string) ($appointment->notes ?? ''),
            'status' => 'Approved',
        ];
    }

    public function getAppointmentsByDateOrderedQueue(string $date)
    {
        return Appointment::query()
            ->join('queues', 'queues.appointment_id', '=', 'appointments.id')
            ->join('patient_records', 'patient_records.id', '=', 'appointments.patient_id')
            ->leftJoin('services', 'services.id', '=', 'appointments.service_id')
            ->where('appointments.appointment_date', $date)
            ->orderBy('queues.queue_number')
            ->select([
                'appointments.id',
                'appointments.patient_id',
                'appointments.service_id',
                'appointments.appointment_date',
                'appointments.time_slot',
                'appointments.status',
                'queues.queue_number',
                'patient_records.first_name',
                'patient_records.last_name',
                'services.name as service_name',
            ])
            ->get()
            ->map(function (Appointment $appointment): array {
                return [
                    'id' => (int) $appointment->id,
                    'patient_name' => trim(
                        sprintf('%s %s', (string) $appointment->first_name, (string) $appointment->last_name),
                    ),
                    'service_type' => $this->resolveServiceType(
                        $appointment->service_name !== null ? (string) $appointment->service_name : null,
                        (int) $appointment->service_id,
                    ),
                    'time' => (string) $appointment->time_slot,
                    'status' => ucfirst((string) $appointment->status),
                    'queue_number' => (int) $appointment->queue_number,
                    'appointment_date' => (string) $appointment->appointment_date,
                ];
            });
    }

    public function createAppointment(array $data)
    {
        $validatedBooking = $this->bookingRulesEngine->validate($data);
        $initialStatus = $this->resolveInitialStatus($data);

        $existingAppointment = Appointment::where('patient_id', $data['patient_id'])
            ->where('appointment_date', $validatedBooking['appointment_date'])
            ->whereIn('status', ['pending', 'confirmed', 'completed'])
            ->exists();

        if ($existingAppointment) {
            throw ValidationException::withMessages([
                'appointment_date' => ['You already have a booking for this date.'],
            ]);
        }

        return DB::transaction(function () use ($data, $validatedBooking, $initialStatus) {
            try {
                $appointment = Appointment::create([
                    'patient_id' => $data['patient_id'],
                    'service_id' => $data['service_id'],
                    'appointment_date' => $validatedBooking['appointment_date'],
                    'time_slot' => $validatedBooking['time_slot'],
                    'status' => $initialStatus,
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

            $this->assignQueueForDate(
                $appointment,
                (string) $validatedBooking['appointment_date'],
            );

            $appointment->load(['patient', 'queue']);
            $this->createBookingNotification($appointment);

            return $appointment;
        });
    }

    public function createWalkInAppointment(array $patientData, array $appointmentData): array
    {
        return DB::transaction(function () use ($patientData, $appointmentData) {
            $patientRecord = PatientRecord::create($patientData);

            $appointment = $this->createAppointment([
                ...$appointmentData,
                'patient_id' => (int) $patientRecord->id,
            ]);

            $appointment->load(['patient', 'queue']);

            return [$patientRecord, $appointment];
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

    private function assignQueueForDate(Appointment $appointment, string $appointmentDate): void
    {
        for ($attempt = 0; $attempt < self::MAX_QUEUE_ASSIGNMENT_RETRIES; $attempt++) {
            $nextQueueNumber = $this->resolveNextQueueNumber($appointmentDate);

            if ($nextQueueNumber > self::DAILY_QUEUE_LIMIT) {
                throw ValidationException::withMessages([
                    'appointment_date' => ['The daily limit of ' . self::DAILY_QUEUE_LIMIT . ' patients has been reached for this date.'],
                ]);
            }

            try {
                Queue::create([
                    'appointment_id' => (int) $appointment->id,
                    'queue_date' => $appointmentDate,
                    'queue_number' => $nextQueueNumber,
                    'is_called' => false,
                ]);

                return;
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
    }

    private function resolveNextQueueNumber(string $appointmentDate): int
    {
        $lastQueue = Queue::where('queue_date', $appointmentDate)
            ->lockForUpdate()
            ->orderByDesc('queue_number')
            ->first();

        return $lastQueue ? ((int) $lastQueue->queue_number + 1) : 1;
    }

    public function updateStatus(Appointment $appointment, string $status, int $changedByUserId)
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

            Log::channel('audit')->info('appointment.status_updated', [
                'appointment_id' => (int) $appointment->id,
                'changed_by_user_id' => $changedByUserId,
                'action' => ucfirst($this->displayStatusLabel($targetStatus)),
                'previous_status' => $this->displayStatusLabel($currentStatus),
            ]);
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

    private function resolveInitialStatus(array $data): string
    {
        if (!array_key_exists('status', $data) || $data['status'] === null) {
            return self::STATUS_PENDING;
        }

        $normalized = $this->normalizeStatus((string) $data['status']);

        if ($normalized === null) {
            throw ValidationException::withMessages([
                'status' => ['Status must be one of: pending, approved, cancelled, completed.'],
            ]);
        }

        return $normalized;
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
        return Appointment::with(['patient', 'queue', 'service'])
            ->where('patient_id', $patientId)
            ->orderBy('appointment_date')
            ->orderBy('time_slot')
            ->get();
    }

    public function getPatientUpcomingAppointments(int $patientId)
    {
        return Appointment::with(['patient', 'queue', 'service'])
            ->where('patient_id', $patientId)
            ->whereDate(
                'appointment_date',
                '>=',
                Carbon::today((string) config('app.timezone', 'UTC'))->toDateString(),
            )
            ->whereIn('status', [self::STATUS_PENDING, self::STATUS_CONFIRMED])
            ->orderBy('appointment_date')
            ->orderBy('time_slot')
            ->get();
    }

    public function getPatientCompletedAppointments(int $patientId)
    {
        return Appointment::with(['patient', 'queue', 'service'])
            ->where('patient_id', $patientId)
            ->where('status', self::STATUS_COMPLETED)
            ->orderByDesc('appointment_date')
            ->orderByDesc('time_slot')
            ->get();
    }

    private function resolveServiceType(?string $serviceName, int $serviceId): string
    {
        if ($serviceName !== null && $serviceName !== '') {
            return $serviceName;
        }

        return match ($serviceId) {
            1 => 'Dental Check-up',
            2 => 'Dental Panoramic X-ray',
            3 => 'Root Canal',
            4 => 'Teeth Cleaning',
            5 => 'Teeth Whitening',
            6 => 'Tooth Extraction',
            default => 'Unknown Service',
        };
    }

    private function createBookingNotification(Appointment $appointment): void
    {
        if ((int) ($appointment->patient?->user_id ?? 0) === 0) {
            return;
        }

        PatientNotification::create([
            'patient_id' => (int) $appointment->patient_id,
            'appointment_id' => (int) $appointment->id,
            'type' => 'appointment_created',
            'title' => 'Appointment booked',
            'message' => sprintf(
                'Your appointment on %s at %s has been booked successfully.',
                (string) $appointment->appointment_date,
                (string) $appointment->time_slot,
            ),
        ]);
    }
}
