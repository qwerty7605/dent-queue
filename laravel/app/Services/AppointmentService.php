<?php

namespace App\Services;

use App\Models\Appointment;
use App\Models\PatientRecord;
use App\Models\PatientNotification;
use App\Models\StaffNotification;
use App\Models\User;
use App\Support\AppointmentQueueOrder;
use Illuminate\Contracts\Cache\LockTimeoutException;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\QueryException;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Str;
use Illuminate\Validation\ValidationException;

class AppointmentService
{
    private const RECYCLE_BIN_RESTORE_WINDOW_DAYS = 7;
    private const STATUS_PENDING = 'pending';
    private const STATUS_CONFIRMED = 'confirmed';
    private const STATUS_CANCELLED = 'cancelled';
    private const STATUS_COMPLETED = 'completed';
    private const STATUS_CANCELLED_BY_DOCTOR = 'cancelled_by_doctor';
    private const STATUS_RESCHEDULE_REQUIRED = 'reschedule_required';
    private const STATUS_ALIASES = [
        self::STATUS_PENDING => self::STATUS_PENDING,
        'approved' => self::STATUS_CONFIRMED,
        self::STATUS_CONFIRMED => self::STATUS_CONFIRMED,
        self::STATUS_CANCELLED => self::STATUS_CANCELLED,
        self::STATUS_COMPLETED => self::STATUS_COMPLETED,
        'cancelled by doctor' => self::STATUS_CANCELLED_BY_DOCTOR,
        self::STATUS_CANCELLED_BY_DOCTOR => self::STATUS_CANCELLED_BY_DOCTOR,
        'reschedule required' => self::STATUS_RESCHEDULE_REQUIRED,
        self::STATUS_RESCHEDULE_REQUIRED => self::STATUS_RESCHEDULE_REQUIRED,
    ];
    private const ACTIVE_BOOKING_STATUSES = [
        self::STATUS_PENDING,
        self::STATUS_CONFIRMED,
        self::STATUS_COMPLETED,
        self::STATUS_CANCELLED_BY_DOCTOR,
        self::STATUS_RESCHEDULE_REQUIRED,
    ];
    private const STATUS_TRANSITIONS = [
        self::STATUS_PENDING => [self::STATUS_CONFIRMED, self::STATUS_CANCELLED],
        self::STATUS_CONFIRMED => [self::STATUS_COMPLETED, self::STATUS_CANCELLED],
        self::STATUS_COMPLETED => [],
        self::STATUS_CANCELLED => [],
        self::STATUS_CANCELLED_BY_DOCTOR => [],
        self::STATUS_RESCHEDULE_REQUIRED => [],
    ];

    public function __construct(
        protected BookingRulesEngine $bookingRulesEngine,
        protected QueueService $queueService,
        protected DoctorAvailabilityService $doctorAvailabilityService,
    )
    {
    }

    public function getAllAppointments()
    {
        return Appointment::with(['patient', 'queue'])
            ->whereIn('status', self::ACTIVE_BOOKING_STATUSES)
            ->orderBy('appointment_date')
            ->orderBy('time_slot')
            ->get();
    }

    public function getMasterList()
    {
        return Appointment::query()
            ->join('patient_records', 'patient_records.id', '=', 'appointments.patient_id')
            ->leftJoin('services', 'services.id', '=', 'appointments.service_id')
            ->leftJoin('queues', 'queues.appointment_id', '=', 'appointments.id')
            ->whereIn('appointments.status', self::ACTIVE_BOOKING_STATUSES)
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
                'appointments.notes',
                'patient_records.user_id',
                'queues.queue_number',
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

                $isWalkIn = (str_contains(strtolower((string)$appointment->notes), 'walk-in') || $appointment->user_id === null);
                
                return [
                    'appointment_id' => (int) $appointment->appointment_id,
                    'patient_name' => $patientName,
                    'service' => $appointment->service_type !== null ? (string) $appointment->service_type : 'Unknown Service',
                    'date' => (string) $appointment->appointment_date,
                    'contact' => (string) $appointment->contact,
                    'status' => self::humanStatusLabel((string) $appointment->status),
                    'booking_type' => $isWalkIn ? 'Walk-in' : 'Online',
                    'queue_number' => $appointment->queue_number ? str_pad((string)$appointment->queue_number, 2, '0', STR_PAD_LEFT) : '-',
                ];
            });
    }

    public function getCalendarAppointmentsByDate(string $date)
    {
        $this->syncDailyQueueNumbers($date);

        return Appointment::query()
            ->leftJoin('queues', 'queues.appointment_id', '=', 'appointments.id')
            ->join('patient_records', 'patient_records.id', '=', 'appointments.patient_id')
            ->leftJoin('services', 'services.id', '=', 'appointments.service_id')
            ->where('appointments.appointment_date', $date)
            ->whereIn('appointments.status', [
                self::STATUS_PENDING,
                self::STATUS_CONFIRMED,
                self::STATUS_COMPLETED,
                self::STATUS_CANCELLED_BY_DOCTOR,
                self::STATUS_RESCHEDULE_REQUIRED,
            ])
            ->tap(static fn (Builder $query) => AppointmentQueueOrder::apply($query))
            ->select([
                'appointments.id',
                'appointments.patient_id',
                'appointments.service_id',
                'appointments.appointment_date',
                'appointments.time_slot',
                'appointments.created_at',
                'appointments.notes',
                'appointments.status',
                'queues.queue_number',
                'queues.is_called',
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
                    'status' => self::humanStatusLabel((string) $appointment->status),
                    'queue_number' => $appointment->queue_number !== null
                        ? (int) $appointment->queue_number
                        : null,
                    'appointment_date' => (string) $appointment->appointment_date,
                    'timestamp_created' => $appointment->created_at !== null
                        ? Carbon::parse((string) $appointment->created_at)->toIso8601String()
                        : null,
                    'notes' => (string) ($appointment->notes ?? ''),
                ];
            });
    }

    public function getCalendarAppointmentDetails(int $appointmentId): ?array
    {
        $appointment = Appointment::query()
            ->leftJoin('queues', 'queues.appointment_id', '=', 'appointments.id')
            ->join('patient_records', 'patient_records.id', '=', 'appointments.patient_id')
            ->leftJoin('services', 'services.id', '=', 'appointments.service_id')
            ->where('appointments.id', $appointmentId)
            ->whereIn('appointments.status', [
                self::STATUS_PENDING,
                self::STATUS_CONFIRMED,
                self::STATUS_COMPLETED,
                self::STATUS_CANCELLED_BY_DOCTOR,
                self::STATUS_RESCHEDULE_REQUIRED,
            ])
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
            'queue_number' => $appointment->queue_number !== null ? (int) $appointment->queue_number : null,
            'notes' => (string) ($appointment->notes ?? ''),
            'status' => self::humanStatusLabel((string) $appointment->status),
        ];
    }

    public function getAppointmentsByDateOrderedQueue(string $date)
    {
        $this->syncDailyQueueNumbers($date);

        return Appointment::query()
            ->join('queues', 'queues.appointment_id', '=', 'appointments.id')
            ->join('patient_records', 'patient_records.id', '=', 'appointments.patient_id')
            ->leftJoin('services', 'services.id', '=', 'appointments.service_id')
            ->where('appointments.appointment_date', $date)
            ->whereIn('appointments.status', self::ACTIVE_BOOKING_STATUSES)
            ->tap(static fn (Builder $query) => AppointmentQueueOrder::apply($query))
            ->select([
                'appointments.id',
                'appointments.patient_id',
                'appointments.service_id',
                'appointments.appointment_date',
                'appointments.time_slot',
                'appointments.created_at',
                'appointments.status',
                'queues.queue_number',
                'queues.is_called',
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
                    'status' => self::humanStatusLabel((string) $appointment->status),
                    'queue_number' => (int) $appointment->queue_number,
                    'is_called' => (bool) $appointment->is_called,
                    'appointment_date' => (string) $appointment->appointment_date,
                    'timestamp_created' => $appointment->created_at !== null
                        ? Carbon::parse((string) $appointment->created_at)->toIso8601String()
                        : null,
                ];
            });
    }

    public function createAppointment(array $data)
    {
        $validatedBooking = $this->bookingRulesEngine->validate($data);
        $initialStatus = $this->resolveInitialStatus($data);

        return $this->withAppointmentDateLock(
            (string) $validatedBooking['appointment_date'],
            function () use ($data, $validatedBooking, $initialStatus) {
                $this->assertTimeSlotAvailable(
                    (string) $validatedBooking['appointment_date'],
                    (string) $validatedBooking['time_slot'],
                );

                $existingAppointment = Appointment::where('patient_id', $data['patient_id'])
                    ->where('appointment_date', $validatedBooking['appointment_date'])
                    ->whereIn('status', self::ACTIVE_BOOKING_STATUSES)
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

                    $this->queueService->generateQueueNumber((int) $appointment->id);

                    $appointment->load(['patient', 'queue', 'service']);
                    $this->createBookingNotification($appointment);
                    $this->createStaffBookingNotification($appointment);

                    if ($initialStatus === self::STATUS_CONFIRMED) {
                        $this->createApprovalNotification($appointment);
                    }

                    return $appointment;
                });
            },
        );
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

    public function updateStatus(Appointment $appointment, string $status, int $changedByUserId)
    {
        $targetStatus = $this->normalizeStatus($status);
        if ($targetStatus === null) {
            throw ValidationException::withMessages([
                'status' => ['Status must be one of: pending, approved, cancelled, completed, cancelled by doctor, reschedule required.'],
            ]);
        }

        $currentStatus = $this->normalizeStatus((string) $appointment->status);
        if ($currentStatus === null) {
            throw ValidationException::withMessages([
                'status' => ['Current appointment status is invalid and cannot be transitioned.'],
            ]);
        }

        $updatedAppointment = $this->loadAppointmentForResponse((int) $appointment->id);

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

            if ($targetStatus === self::STATUS_CANCELLED) {
                $updatedAppointment = $this->recycleCancelledAppointment($appointment);
            } else {
                $appointment->update(['status' => $targetStatus]);

                if ($targetStatus === self::STATUS_CONFIRMED) {
                    $this->createApprovalNotification($appointment);
                }

                $updatedAppointment = $this->loadAppointmentForResponse((int) $appointment->id);
            }

            Log::channel('audit')->info('appointment.status_updated', [
                'appointment_id' => (int) $appointment->id,
                'changed_by_user_id' => $changedByUserId,
                'action' => ucfirst($this->displayStatusLabel($targetStatus)),
                    'previous_status' => $this->displayStatusLabel($currentStatus),
                ]);
        }

        return $updatedAppointment;
    }

    public function cancelByPatient(Appointment $appointment, int $patientId): Appointment
    {
        $currentStatus = $this->normalizeStatus((string) $appointment->status);

        if (!in_array($currentStatus, [self::STATUS_PENDING, self::STATUS_CONFIRMED], true)) {
            throw ValidationException::withMessages([
                'status' => ['Only pending or approved appointments can be cancelled.'],
            ]);
        }

        $appointment = $this->recycleCancelledAppointment($appointment);

        Log::info('appointment.cancelled.by_patient', [
            'appointment_id' => (int) $appointment->id,
            'patient_id' => $patientId,
            'previous_status' => $currentStatus,
            'new_status' => self::STATUS_CANCELLED,
            'occurred_at' => now()->toISOString(),
        ]);

        return $appointment;
    }

    public function restoreAppointment(Appointment $appointment): Appointment
    {
        $this->assertRecycleBinAppointmentCanBeRestored($appointment);

        $this->withAppointmentDateLock((string) $appointment->appointment_date, function () use ($appointment): void {
            $this->assertTimeSlotAvailable(
                (string) $appointment->appointment_date,
                (string) $appointment->time_slot,
                (int) $appointment->id,
            );

            $existingAppointment = Appointment::where('patient_id', $appointment->patient_id)
                ->where('appointment_date', $appointment->appointment_date)
                ->whereIn('status', self::ACTIVE_BOOKING_STATUSES)
                ->exists();

            if ($existingAppointment) {
                throw ValidationException::withMessages([
                    'appointment_date' => ['The patient already has an active booking for this date.'],
                ]);
            }

            DB::transaction(function () use ($appointment): void {
                $appointment->restore();
                // Default to pending. Admin can approve it later if needed.
                $appointment->status = self::STATUS_PENDING;
                $appointment->save();

                $this->queueService->generateQueueNumber((int) $appointment->id);
            });
        });

        Log::info('appointment.restored', [
            'appointment_id' => (int) $appointment->id,
            'occurred_at' => now()->toISOString(),
        ]);

        return $this->loadAppointmentForResponse((int) $appointment->id);
    }

    public function rescheduleByPatient(Appointment $appointment, int $patientId, array $data): Appointment
    {
        $currentStatus = $this->normalizeStatus((string) $appointment->status);

        if (!in_array($currentStatus, [
            self::STATUS_PENDING,
            self::STATUS_CONFIRMED,
            self::STATUS_CANCELLED_BY_DOCTOR,
            self::STATUS_RESCHEDULE_REQUIRED,
        ], true)) {
            throw ValidationException::withMessages([
                'status' => ['Only pending, approved, cancelled by doctor, or reschedule required appointments can be rescheduled.'],
            ]);
        }

        $validatedBooking = $this->bookingRulesEngine->validate([
            ...$data,
            'patient_id' => $patientId,
            'service_id' => (int) $appointment->service_id,
        ]);
        $validatedBooking['notes'] = $data['notes'] ?? $appointment->notes;

        $originalDate = (string) $appointment->appointment_date;
        $originalTime = (string) $appointment->time_slot;
        $targetDate = (string) $validatedBooking['appointment_date'];
        $targetTime = (string) $validatedBooking['time_slot'];

        $performReschedule = function () use (
            $appointment,
            $patientId,
            $validatedBooking,
            $originalDate,
            $originalTime,
            $targetDate,
            $targetTime,
            $currentStatus,
        ) {
            $this->assertTimeSlotAvailable(
                $targetDate,
                $targetTime,
                (int) $appointment->id,
            );

            $existingAppointment = Appointment::query()
                ->where('patient_id', $patientId)
                ->where('appointment_date', $targetDate)
                ->whereIn('status', self::ACTIVE_BOOKING_STATUSES)
                ->whereKeyNot((int) $appointment->id)
                ->exists();

            if ($existingAppointment) {
                throw ValidationException::withMessages([
                    'appointment_date' => ['You already have a booking for this date.'],
                ]);
            }

            try {
                DB::transaction(function () use ($appointment, $validatedBooking, $originalDate, $targetDate, $currentStatus): void {
                    $appointment->forceFill([
                        'appointment_date' => $validatedBooking['appointment_date'],
                        'time_slot' => $validatedBooking['time_slot'],
                        'status' => $this->resolvePatientRescheduleStatus(
                            $currentStatus,
                            (string) $appointment->status,
                        ),
                        'notes' => $validatedBooking['notes'] ?? $appointment->notes,
                    ])->save();

                    if ($originalDate !== $targetDate) {
                        $this->queueService->syncQueueNumbersForDate($originalDate);
                    }

                    $this->queueService->generateQueueNumber((int) $appointment->id);
                });
            } catch (QueryException $exception) {
                if ($this->isUniqueConstraintViolation($exception)) {
                    throw ValidationException::withMessages([
                        'time_slot' => ['You already have an appointment for the selected date and time. Please choose another slot.'],
                    ]);
                }

                throw $exception;
            }

            Log::info('appointment.rescheduled.by_patient', [
                'appointment_id' => (int) $appointment->id,
                'patient_id' => $patientId,
                'previous_status' => $currentStatus,
                'previous_date' => $originalDate,
                'previous_time_slot' => $originalTime,
                'new_date' => $targetDate,
                'new_time_slot' => $targetTime,
                'occurred_at' => now()->toISOString(),
            ]);

            $updatedAppointment = $this->loadAppointmentForResponse((int) $appointment->id);
            $this->createRescheduleSuccessNotification($updatedAppointment);

            return $updatedAppointment;
        };

        if ($originalDate === $targetDate) {
            return $this->withAppointmentDateLock($targetDate, $performReschedule);
        }

        $lockDates = [$originalDate, $targetDate];
        sort($lockDates);

        return $this->withAppointmentDateLock($lockDates[0], function () use ($lockDates, $performReschedule) {
            return $this->withAppointmentDateLock($lockDates[1], $performReschedule);
        });
    }

    private function resolvePatientRescheduleStatus(string $currentStatus, string $persistedStatus): string
    {
        return in_array($currentStatus, [self::STATUS_CANCELLED_BY_DOCTOR, self::STATUS_RESCHEDULE_REQUIRED], true)
            ? self::STATUS_CONFIRMED
            : $persistedStatus;
    }

    public function getRecycleBinAppointments(?int $patientId = null)
    {
        $query = $this->recycleBinAppointmentsQuery()
            ->with(['patient', 'queue', 'service'])
            ->orderByDesc('deleted_at')
            ->orderByDesc('appointment_date')
            ->orderByDesc('time_slot');

        if ($patientId !== null) {
            $query->where('patient_id', $patientId);
        }

        return $query->get();
    }

    public function findRecycleBinAppointment(int $appointmentId): ?Appointment
    {
        return $this->recycleBinAppointmentsQuery()
            ->with(['patient', 'queue', 'service'])
            ->whereKey($appointmentId)
            ->first();
    }

    public function getRecycleBinRestoreWindowDays(): int
    {
        return self::RECYCLE_BIN_RESTORE_WINDOW_DAYS;
    }

    public function buildRecycleBinState(Appointment $appointment, ?Carbon $referenceTime = null): array
    {
        $expiresAt = $this->resolveRecycleBinExpiresAt($appointment);
        $isExpired = $this->isRecycleBinAppointmentExpired($appointment, $referenceTime);

        return [
            'deleted_at' => $appointment->deleted_at?->copy()->shiftTimezone('UTC')->toIso8601String(),
            'expires_at' => $expiresAt?->copy()->shiftTimezone('UTC')->toIso8601String(),
            'is_expired' => $isExpired,
            'is_restorable' => $this->canRestoreRecycleBinAppointment($appointment, $referenceTime),
            'restore_window_days' => self::RECYCLE_BIN_RESTORE_WINDOW_DAYS,
        ];
    }

    public function isRecycleBinAppointmentExpired(Appointment $appointment, ?Carbon $referenceTime = null): bool
    {
        $expiresAt = $this->resolveRecycleBinExpiresAt($appointment);
        if ($expiresAt === null) {
            return false;
        }

        $comparisonTime = $referenceTime?->copy()
            ?? Carbon::now((string) config('app.timezone', 'UTC'));

        return $comparisonTime->greaterThanOrEqualTo($expiresAt);
    }

    public function canRestoreRecycleBinAppointment(Appointment $appointment, ?Carbon $referenceTime = null): bool
    {
        if (!$this->isRecycleBinAppointment($appointment)) {
            return false;
        }

        if ($this->isRecycleBinAppointmentDateInPast($appointment, $referenceTime)) {
            return false;
        }

        return !$this->isRecycleBinAppointmentExpired($appointment, $referenceTime);
    }

    public function assertRecycleBinAppointmentCanBeRestored(
        Appointment $appointment,
        ?Carbon $referenceTime = null,
    ): void {
        if (!$this->isRecycleBinAppointment($appointment)) {
            throw ValidationException::withMessages([
                'appointment' => ['Only cancelled appointments in the recycle bin can be restored.'],
            ]);
        }

        if ($this->isRecycleBinAppointmentExpired($appointment, $referenceTime)) {
            throw ValidationException::withMessages([
                'appointment' => ['This cancelled appointment is no longer eligible for restore.'],
            ]);
        }

        if ($this->isRecycleBinAppointmentDateInPast($appointment, $referenceTime)) {
            throw ValidationException::withMessages([
                'appointment_date' => ['Cannot restore appointments from past dates.'],
            ]);
        }
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
                'status' => ['Status must be one of: pending, approved, cancelled, completed, cancelled by doctor, reschedule required.'],
            ]);
        }

        return $normalized;
    }

    public static function formatStatusLabel(string $status): string
    {
        return match ($status) {
            self::STATUS_CONFIRMED => 'approved',
            self::STATUS_CANCELLED_BY_DOCTOR => 'cancelled by doctor',
            self::STATUS_RESCHEDULE_REQUIRED => 'reschedule required',
            default => $status,
        };
    }

    public static function humanStatusLabel(string $status): string
    {
        return Str::headline(self::formatStatusLabel($status));
    }

    private function displayStatusLabel(string $status): string
    {
        return self::formatStatusLabel($status);
    }

    public function getPatientAppointments(int $patientId)
    {
        return Appointment::with([
            'patient',
            'queue',
            'service',
            'patientNotifications' => function ($query) {
                $query->whereIn('type', [
                    'appointment_reschedule_required',
                    'appointment_cancelled_by_doctor',
                ])->latest('id');
            },
        ])
            ->where('patient_id', $patientId)
            ->whereIn('status', self::ACTIVE_BOOKING_STATUSES)
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
            ->whereIn('status', [
                self::STATUS_PENDING,
                self::STATUS_CONFIRMED,
                self::STATUS_CANCELLED_BY_DOCTOR,
                self::STATUS_RESCHEDULE_REQUIRED,
            ])
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

    private function syncDailyQueueNumbers(string $date): void
    {
        $hasActiveAppointments = Appointment::query()
            ->whereDate('appointment_date', $date)
            ->whereNull('deleted_at')
            ->whereIn('status', self::ACTIVE_BOOKING_STATUSES)
            ->exists();

        if ($hasActiveAppointments) {
            $this->queueService->syncQueueNumbersForDate($date);
        }
    }

    private function withAppointmentDateLock(string $appointmentDate, callable $callback): mixed
    {
        $lockName = sprintf('appointment-booking:%s', $appointmentDate);

        try {
            return Cache::lock($lockName, 10)->block(5, $callback);
        }
        catch (LockTimeoutException) {
            throw ValidationException::withMessages([
                'appointment_date' => ['Another booking is being processed for this date. Please try again.'],
            ]);
        }
    }

    private function assertTimeSlotAvailable(
        string $appointmentDate,
        string $timeSlot,
        ?int $ignoreAppointmentId = null,
    ): void {
        try {
            $this->doctorAvailabilityService->assertDateTimeAvailable(
                $appointmentDate,
                $timeSlot,
                $ignoreAppointmentId,
            );
        } catch (ValidationException $exception) {
            throw $exception;
        }
    }

    private function createBookingNotification(Appointment $appointment): void
    {
        $appointment->loadMissing('patient');
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

    private function createApprovalNotification(Appointment $appointment): void
    {
        $appointment->loadMissing(['patient', 'service']);
        if ((int) ($appointment->patient?->user_id ?? 0) === 0) {
            return;
        }

        PatientNotification::create([
            'patient_id' => (int) $appointment->patient_id,
            'appointment_id' => (int) $appointment->id,
            'type' => 'approved',
            'title' => 'Appointment Approved',
            'message' => sprintf(
                'Your appointment for %s on %s has been approved.',
                $this->resolveServiceType($appointment->service?->name, (int) $appointment->service_id),
                (string) $appointment->appointment_date,
            ),
        ]);
    }

    private function createRescheduleSuccessNotification(Appointment $appointment): void
    {
        $appointment->loadMissing(['patient', 'service']);
        if ((int) ($appointment->patient?->user_id ?? 0) === 0) {
            return;
        }

        PatientNotification::create([
            'patient_id' => (int) $appointment->patient_id,
            'appointment_id' => (int) $appointment->id,
            'type' => 'appointment_rescheduled',
            'title' => 'Appointment Rescheduled',
            'message' => sprintf(
                'Your appointment for %s has been rescheduled to %s at %s.',
                $this->resolveServiceType($appointment->service?->name, (int) $appointment->service_id),
                (string) $appointment->appointment_date,
                (string) $appointment->time_slot,
            ),
        ]);
    }

    private function createStaffBookingNotification(Appointment $appointment): void
    {
        $appointment->loadMissing(['patient.user.role', 'service']);

        $patientName = trim(sprintf(
            '%s %s',
            (string) ($appointment->patient?->first_name ?? ''),
            (string) ($appointment->patient?->last_name ?? ''),
        ));
        $serviceName = $this->resolveServiceType($appointment->service?->name, (int) $appointment->service_id);
        $timeSlot = (string) $appointment->time_slot;

        $recipientIds = User::query()
            ->where('is_active', true)
            ->whereHas('role', static function ($query): void {
                $query->whereRaw('LOWER(name) IN (?, ?)', ['staff', 'admin']);
            })
            ->pluck('id');

        foreach ($recipientIds as $recipientId) {
            StaffNotification::create([
                'user_id' => (int) $recipientId,
                'appointment_id' => (int) $appointment->id,
                'type' => 'staff_appointment_created',
                'title' => 'New appointment booked',
                'message' => sprintf(
                    '%s booked %s for %s at %s.',
                    $patientName !== '' ? $patientName : 'A patient',
                    $serviceName,
                    (string) $appointment->appointment_date,
                    $timeSlot,
                ),
            ]);
        }
    }

    private function recycleCancelledAppointment(Appointment $appointment): Appointment
    {
        DB::transaction(function () use ($appointment): void {
            if ((string) $appointment->status !== self::STATUS_CANCELLED) {
                $appointment->forceFill([
                    'status' => self::STATUS_CANCELLED,
                ])->save();
            }

            if (!$appointment->trashed()) {
                $appointment->forceFill([
                    'deleted_at' => Carbon::now('UTC'),
                ])->save();
            }

            $this->queueService->removeQueueForAppointment($appointment);
        });

        return $this->loadAppointmentForResponse((int) $appointment->id);
    }

    private function loadAppointmentForResponse(int $appointmentId): Appointment
    {
        return Appointment::withTrashed()
            ->with(['patient', 'queue', 'service'])
            ->findOrFail($appointmentId);
    }

    private function resolveRecycleBinExpiresAt(Appointment $appointment): ?Carbon
    {
        if (!$this->isRecycleBinAppointment($appointment)) {
            return null;
        }

        return $appointment->deleted_at
            ? $appointment->deleted_at->copy()->addDays(self::RECYCLE_BIN_RESTORE_WINDOW_DAYS)
            : null;
    }

    private function isRecycleBinAppointment(Appointment $appointment): bool
    {
        return $appointment->trashed() && (string) $appointment->status === self::STATUS_CANCELLED;
    }

    private function isRecycleBinAppointmentDateInPast(
        Appointment $appointment,
        ?Carbon $referenceTime = null,
    ): bool {
        $timezone = (string) config('app.timezone', 'UTC');
        $appointmentDate = Carbon::parse($appointment->appointment_date, $timezone)->startOfDay();
        $today = $referenceTime?->copy()->setTimezone($timezone)->startOfDay()
            ?? Carbon::today($timezone);

        return $appointmentDate->isBefore($today);
    }

    private function recycleBinAppointmentsQuery(): Builder
    {
        return Appointment::recycleBinEligible();
    }
}
