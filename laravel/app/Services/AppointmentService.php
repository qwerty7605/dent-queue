<?php

namespace App\Services;

use App\Models\Appointment;
use App\Models\AuditTrail;
use App\Models\PatientRecord;
use App\Models\PatientNotification;
use App\Models\Service;
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
    private const VALIDATION_ACTIVE_STATUSES = [
        self::STATUS_PENDING,
        self::STATUS_CONFIRMED,
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
        return Appointment::with(['patient', 'queue', 'service', 'services'])
            ->whereIn('status', self::ACTIVE_BOOKING_STATUSES)
            ->orderBy('appointment_date')
            ->orderBy('time_slot')
            ->get();
    }

    public function getMasterList()
    {
        return Appointment::query()
            ->with(['service', 'services', 'auditTrails.user'])
            ->join('patient_records', 'patient_records.id', '=', 'appointments.patient_id')
            ->leftJoin('services', 'services.id', '=', 'appointments.service_id')
            ->leftJoin('queues', 'queues.appointment_id', '=', 'appointments.id')
            ->leftJoin('users as cancelled_by_users', 'cancelled_by_users.id', '=', 'appointments.cancelled_by')
            ->whereIn('appointments.status', self::ACTIVE_BOOKING_STATUSES)
            ->orderByDesc('appointments.appointment_date')
            ->orderByDesc('appointments.time_slot')
            ->select([
                'appointments.id',
                'appointments.id as appointment_id',
                'patient_records.first_name',
                'patient_records.middle_name',
                'patient_records.last_name',
                'services.name as service_type',
                'appointments.appointment_date',
                'patient_records.contact_number as contact',
                'appointments.status',
                'appointments.notes',
                'appointments.cancellation_reason',
                'appointments.cancelled_by',
                'appointments.cancelled_at',
                'cancelled_by_users.first_name as cancelled_by_first_name',
                'cancelled_by_users.last_name as cancelled_by_last_name',
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
                    'service' => $this->appointmentServiceSummary($appointment),
                    'date' => (string) $appointment->appointment_date,
                    'contact' => (string) $appointment->contact,
                    'status' => self::humanStatusLabel((string) $appointment->status),
                    'booking_type' => $isWalkIn ? 'Walk-in' : 'Online',
                    'queue_number' => $appointment->queue_number ? str_pad((string)$appointment->queue_number, 2, '0', STR_PAD_LEFT) : '-',
                    'cancellation_reason' => $appointment->cancellation_reason,
                    'cancelled_by' => $appointment->cancelled_by !== null ? (int) $appointment->cancelled_by : null,
                    'cancelled_by_name' => $this->formatCancelledByName($appointment),
                    'cancelled_at' => $appointment->cancelled_at !== null
                        ? Carbon::parse((string) $appointment->cancelled_at)->toIso8601String()
                        : null,
                    'logs' => $this->formatAppointmentLogs($appointment),
                ];
            });
    }

    public function getCalendarAppointmentsByDate(string $date)
    {
        $this->syncDailyQueueNumbers($date);

        return Appointment::query()
            ->with(['service', 'services', 'auditTrails.user'])
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
                    'service_type' => $this->appointmentServiceSummary($appointment),
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
                    'logs' => $this->formatAppointmentLogs($appointment),
                ];
            });
    }

    public function getCalendarAppointmentDetails(int $appointmentId): ?array
    {
        $appointment = Appointment::query()
            ->with(['service', 'services', 'auditTrails.user'])
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
            'service_type' => $this->appointmentServiceSummary($appointment),
            'appointment_date' => (string) $appointment->appointment_date,
            'appointment_time' => (string) $appointment->time_slot,
            'queue_number' => $appointment->queue_number !== null ? (int) $appointment->queue_number : null,
            'notes' => (string) ($appointment->notes ?? ''),
            'status' => self::humanStatusLabel((string) $appointment->status),
            'logs' => $this->formatAppointmentLogs($appointment),
        ];
    }

    public function getAppointmentsByDateOrderedQueue(string $date)
    {
        $this->syncDailyQueueNumbers($date);

        return Appointment::query()
            ->with(['service', 'services', 'auditTrails.user'])
            ->leftJoin('queues', 'queues.appointment_id', '=', 'appointments.id')
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
                    'service_type' => $this->appointmentServiceSummary($appointment),
                    'time' => (string) $appointment->time_slot,
                    'status' => self::humanStatusLabel((string) $appointment->status),
                    'queue_number' => $appointment->queue_number !== null
                        ? (int) $appointment->queue_number
                        : null,
                    'is_called' => (bool) $appointment->is_called,
                    'appointment_date' => (string) $appointment->appointment_date,
                    'timestamp_created' => $appointment->created_at !== null
                        ? Carbon::parse((string) $appointment->created_at)->toIso8601String()
                        : null,
                    'logs' => $this->formatAppointmentLogs($appointment),
                ];
            });
    }

    public function createAppointment(array $data)
    {
        $serviceIds = $this->normalizeServiceIds($data);
        $data['service_id'] = $serviceIds[0];
        $data['service_ids'] = $serviceIds;
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
                        'appointment_date' => ['You already have an appointment scheduled on this day.'],
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

                    $this->syncSelectedServices($appointment, $data['service_ids']);
                    $this->refreshQueueForAppointment($appointment);

                    $appointment->load(['patient', 'queue', 'service', 'services']);
                    $this->logAppointmentAction(
                        $appointment,
                        'appointment_created',
                        isset($data['actor_user_id']) ? (int) $data['actor_user_id'] : null,
                        null,
                        $initialStatus,
                    );
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

    public function updateStatus(
        Appointment $appointment,
        string $status,
        int $changedByUserId,
        ?string $cancellationReason = null,
    )
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
                $reason = trim((string) $cancellationReason);
                if ($reason === '') {
                    throw ValidationException::withMessages([
                        'cancellation_reason' => ['Cancellation reason is required.'],
                    ]);
                }

                $updatedAppointment = $this->recycleCancelledAppointment(
                    $appointment,
                    $changedByUserId,
                    $reason,
                );
                $this->logAppointmentAction(
                    $updatedAppointment,
                    'appointment_cancelled',
                    $changedByUserId,
                    $currentStatus,
                    $targetStatus,
                    $reason,
                );
                $this->createStaffCancelledPatientNotification($updatedAppointment, $reason);
            } else {
                $appointment->update(['status' => $targetStatus]);

                $this->refreshQueueForAppointment($appointment);

                if ($targetStatus === self::STATUS_CONFIRMED) {
                    $this->createApprovalNotification($appointment);
                }

                $updatedAppointment = $this->loadAppointmentForResponse((int) $appointment->id);
                $this->logAppointmentAction(
                    $updatedAppointment,
                    $this->statusActionName($targetStatus),
                    $changedByUserId,
                    $currentStatus,
                    $targetStatus,
                );
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

    public function cancelByPatient(Appointment $appointment, int $patientId, int $cancelledByUserId): Appointment
    {
        $currentStatus = $this->normalizeStatus((string) $appointment->status);

        if ($currentStatus !== self::STATUS_PENDING) {
            throw ValidationException::withMessages([
                'status' => ['Only pending appointments can be cancelled by patients.'],
            ]);
        }

        $appointment = $this->recycleCancelledAppointment($appointment, $cancelledByUserId);
        $this->logAppointmentAction(
            $appointment,
            'appointment_cancelled',
            $cancelledByUserId,
            $currentStatus,
            self::STATUS_CANCELLED,
        );
        $this->createPatientCancelledStaffNotification($appointment);

        Log::info('appointment.cancelled.by_patient', [
            'appointment_id' => (int) $appointment->id,
            'patient_id' => $patientId,
            'cancelled_by_user_id' => $cancelledByUserId,
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
                $appointment->cancellation_reason = null;
                $appointment->cancelled_by = null;
                $appointment->cancelled_at = null;
                $appointment->save();

                $this->refreshQueueForAppointment($appointment);
                $this->logAppointmentAction(
                    $appointment,
                    'appointment_restored',
                    null,
                    self::STATUS_CANCELLED,
                    self::STATUS_PENDING,
                );
            });
        });

        Log::info('appointment.restored', [
            'appointment_id' => (int) $appointment->id,
            'occurred_at' => now()->toISOString(),
        ]);

        return $this->loadAppointmentForResponse((int) $appointment->id);
    }

    public function rescheduleByPatient(
        Appointment $appointment,
        int $patientId,
        array $data,
        ?int $changedByUserId = null,
    ): Appointment
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

        $serviceIds = array_key_exists('service_ids', $data) || array_key_exists('service_id', $data)
            ? $this->normalizeServiceIds($data)
            : $this->appointmentServiceIds($appointment);

        $validatedBooking = $this->bookingRulesEngine->validate([
            ...$data,
            'patient_id' => $patientId,
            'service_id' => $serviceIds[0],
        ]);
        $validatedBooking['notes'] = $data['notes'] ?? $appointment->notes;
        $validatedBooking['service_id'] = $serviceIds[0];
        $validatedBooking['service_ids'] = $serviceIds;

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
            $changedByUserId,
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
                        'service_id' => $validatedBooking['service_id'],
                        'appointment_date' => $validatedBooking['appointment_date'],
                        'time_slot' => $validatedBooking['time_slot'],
                        'status' => $this->resolvePatientRescheduleStatus(
                            $currentStatus,
                            (string) $appointment->status,
                        ),
                        'notes' => $validatedBooking['notes'] ?? $appointment->notes,
                    ])->save();

                    $this->syncSelectedServices($appointment, $validatedBooking['service_ids']);

                    if ($originalDate !== $targetDate) {
                        $this->queueService->syncQueueNumbersForDate($originalDate);
                    }

                    $this->refreshQueueForAppointment($appointment);
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
            $this->logAppointmentAction(
                $updatedAppointment,
                'appointment_rescheduled',
                $changedByUserId,
                $currentStatus,
                $this->normalizeStatus((string) $updatedAppointment->status),
                null,
                [
                    'previous_date' => $originalDate,
                    'previous_time_slot' => $originalTime,
                    'new_date' => $targetDate,
                    'new_time_slot' => $targetTime,
                ],
            );
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
            ->with(['patient', 'queue', 'service', 'services'])
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
            ->with(['patient', 'queue', 'service', 'services'])
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

    private function refreshQueueForAppointment(Appointment $appointment): void
    {
        $status = $this->normalizeStatus((string) $appointment->status);

        if (in_array($status, [self::STATUS_CONFIRMED, self::STATUS_COMPLETED], true)) {
            $this->queueService->generateQueueNumber((int) $appointment->id);

            return;
        }

        $this->queueService->syncQueueNumbersForDate((string) $appointment->appointment_date);
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

    public function validateBookingRequest(array $data, int $patientId): array
    {
        $serviceIds = $this->normalizeServiceIds($data);
        $timeSlot = $data['time_slot'] ?? $data['appointment_time'] ?? null;

        $validatedBooking = $this->bookingRulesEngine->validate([
            ...$data,
            'patient_id' => $patientId,
            'service_id' => $serviceIds[0],
            'service_ids' => $serviceIds,
            'time_slot' => $timeSlot,
        ]);

        $this->assertPatientHasNoValidationActiveAppointmentOnDate(
            $patientId,
            (string) $validatedBooking['appointment_date'],
        );

        return [
            'appointment_date' => (string) $validatedBooking['appointment_date'],
            'time_slot' => (string) $validatedBooking['time_slot'],
            'service_ids' => $serviceIds,
        ];
    }

    private function assertPatientHasNoValidationActiveAppointmentOnDate(int $patientId, string $appointmentDate): void
    {
        $exists = Appointment::query()
            ->where('patient_id', $patientId)
            ->whereDate('appointment_date', $appointmentDate)
            ->whereNull('deleted_at')
            ->whereIn('status', self::VALIDATION_ACTIVE_STATUSES)
            ->exists();

        if ($exists) {
            throw ValidationException::withMessages([
                'appointment_date' => ['You already have an appointment scheduled on this day.'],
            ]);
        }
    }

    public function getPatientAppointments(int $patientId)
    {
        return Appointment::with([
            'patient',
            'queue',
            'service',
            'services',
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
        return Appointment::with(['patient', 'queue', 'service', 'services'])
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
        return Appointment::with(['patient', 'queue', 'service', 'services'])
            ->where('patient_id', $patientId)
            ->where('status', self::STATUS_COMPLETED)
            ->orderByDesc('appointment_date')
            ->orderByDesc('time_slot')
            ->get();
    }

    public function getPatientAppointmentHistory(int $patientId)
    {
        return Appointment::withTrashed()
            ->with(['service', 'services', 'cancelledBy', 'auditTrails.user'])
            ->where('patient_id', $patientId)
            ->orderByDesc('appointment_date')
            ->orderByDesc('time_slot')
            ->get()
            ->flatMap(function (Appointment $appointment) {
                if ($appointment->auditTrails->isEmpty()) {
                    return [$this->formatAppointmentHistorySnapshot($appointment)];
                }

                return $appointment->auditTrails
                    ->sortByDesc('created_at')
                    ->values()
                    ->map(fn (AuditTrail $trail): array => $this->formatAppointmentHistoryLog($appointment, $trail));
            })
            ->sortByDesc(fn (array $item): string => (string) ($item['action_at'] ?? ''))
            ->values();
    }

    public function formatAppointmentLogs(Appointment $appointment): array
    {
        $appointment->loadMissing(['service', 'services', 'auditTrails.user']);

        return $appointment->auditTrails
            ->sortByDesc('created_at')
            ->values()
            ->map(fn (AuditTrail $trail): array => $this->formatAppointmentHistoryLog($appointment, $trail))
            ->all();
    }

    /**
     * @return list<int>
     */
    private function normalizeServiceIds(array $data): array
    {
        $rawIds = $data['service_ids'] ?? $data['services'] ?? null;

        if ($rawIds === null && array_key_exists('service_id', $data)) {
            $rawIds = [$data['service_id']];
        }

        $serviceIds = collect(is_array($rawIds) ? $rawIds : [$rawIds])
            ->filter(static fn (mixed $id): bool => $id !== null && $id !== '')
            ->map(static fn (mixed $id): int => (int) $id)
            ->filter(static fn (int $id): bool => $id > 0)
            ->unique()
            ->values()
            ->all();

        if ($serviceIds === []) {
            throw ValidationException::withMessages([
                'services' => ['At least one service must be selected.'],
            ]);
        }

        return $serviceIds;
    }

    /**
     * @return list<int>
     */
    private function appointmentServiceIds(Appointment $appointment): array
    {
        $serviceIds = $appointment->selectedServiceIds();

        if ($serviceIds !== []) {
            return $serviceIds;
        }

        if ((int) $appointment->service_id > 0) {
            return [(int) $appointment->service_id];
        }

        throw ValidationException::withMessages([
            'services' => ['At least one service must be selected.'],
        ]);
    }

    private function appointmentServiceSummary(Appointment $appointment): string
    {
        return $appointment->serviceSummary();
    }

    private function formatCancelledByName(object $appointment): ?string
    {
        $firstName = trim((string) ($appointment->cancelled_by_first_name ?? ''));
        $lastName = trim((string) ($appointment->cancelled_by_last_name ?? ''));
        $name = trim($firstName . ' ' . $lastName);

        return $name !== '' ? $name : null;
    }

    /**
     * @param  list<int>  $serviceIds
     */
    private function syncSelectedServices(Appointment $appointment, array $serviceIds): void
    {
        $existingServiceIds = Service::query()
            ->whereIn('id', $serviceIds)
            ->pluck('id')
            ->map(static fn (mixed $id): int => (int) $id)
            ->values()
            ->all();

        if ($existingServiceIds === []) {
            return;
        }

        $appointment->services()->sync($existingServiceIds);
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

    private function statusActionName(string $status): string
    {
        return match ($status) {
            self::STATUS_CONFIRMED => 'appointment_approved',
            self::STATUS_COMPLETED => 'appointment_completed',
            self::STATUS_CANCELLED => 'appointment_cancelled',
            self::STATUS_RESCHEDULE_REQUIRED => 'appointment_reschedule_required',
            default => 'appointment_status_updated',
        };
    }

    private function logAppointmentAction(
        Appointment $appointment,
        string $action,
        ?int $userId,
        ?string $oldStatus,
        ?string $newStatus,
        ?string $reason = null,
        array $extra = [],
    ): void {
        $appointment->loadMissing(['service', 'services']);

        AuditTrail::create([
            'event' => $action,
            'auditable_type' => Appointment::class,
            'auditable_id' => (int) $appointment->id,
            'user_id' => $userId,
            'metadata' => [
                'action' => $action,
                'old_status' => $oldStatus,
                'new_status' => $newStatus,
                'reason' => $reason,
                'appointment_date' => (string) $appointment->appointment_date,
                'appointment_time' => (string) $appointment->time_slot,
                'service_type' => $this->appointmentServiceSummary($appointment),
                ...$extra,
            ],
        ]);
    }

    private function formatAppointmentHistoryLog(Appointment $appointment, AuditTrail $trail): array
    {
        $metadata = is_array($trail->metadata) ? $trail->metadata : [];
        $newStatus = isset($metadata['new_status']) ? (string) $metadata['new_status'] : (string) $appointment->status;
        $oldStatus = isset($metadata['old_status']) ? (string) $metadata['old_status'] : null;
        $reason = trim((string) ($metadata['reason'] ?? ''));

        return [
            'id' => (int) $trail->id,
            'appointment_id' => (int) $appointment->id,
            'date' => (string) $appointment->appointment_date,
            'appointment_date' => (string) $appointment->appointment_date,
            'appointment_time' => (string) $appointment->time_slot,
            'service_type' => $this->appointmentServiceSummary($appointment),
            'services' => $appointment->selectedServices()
                ->map(static fn (Service $service): array => [
                    'id' => (int) $service->id,
                    'name' => (string) $service->name,
                ])
                ->values()
                ->all(),
            'status' => self::humanStatusLabel((string) $appointment->status),
            'action_status' => $newStatus !== '' ? self::humanStatusLabel($newStatus) : self::humanStatusLabel((string) $appointment->status),
            'old_status' => $oldStatus !== null && $oldStatus !== '' ? self::humanStatusLabel($oldStatus) : null,
            'new_status' => $newStatus !== '' ? self::humanStatusLabel($newStatus) : null,
            'action' => $this->historyActionLabel((string) $trail->event, $newStatus, $reason),
            'performed_by' => $this->formatHistoryActor($trail),
            'performed_by_id' => $trail->user_id !== null ? (int) $trail->user_id : null,
            'action_at' => optional($trail->created_at)?->toIso8601String(),
            'created_at' => optional($trail->created_at)?->toIso8601String(),
            'reason' => $reason !== '' ? $reason : null,
            'cancellation_reason' => $reason !== ''
                ? $reason
                : ($newStatus === self::STATUS_CANCELLED ? $appointment->cancellation_reason : null),
        ];
    }

    private function formatAppointmentHistorySnapshot(Appointment $appointment): array
    {
        $status = $this->normalizeStatus((string) $appointment->status) ?? (string) $appointment->status;
        $actionAt = $appointment->cancelled_at
            ?? $appointment->updated_at
            ?? $appointment->created_at;

        return [
            'id' => null,
            'appointment_id' => (int) $appointment->id,
            'date' => (string) $appointment->appointment_date,
            'appointment_date' => (string) $appointment->appointment_date,
            'appointment_time' => (string) $appointment->time_slot,
            'service_type' => $this->appointmentServiceSummary($appointment),
            'services' => $appointment->selectedServices()
                ->map(static fn (Service $service): array => [
                    'id' => (int) $service->id,
                    'name' => (string) $service->name,
                ])
                ->values()
                ->all(),
            'status' => self::humanStatusLabel((string) $appointment->status),
            'action_status' => self::humanStatusLabel($status),
            'old_status' => null,
            'new_status' => self::humanStatusLabel($status),
            'action' => $this->historyActionLabel('appointment_snapshot', $status, (string) $appointment->cancellation_reason),
            'performed_by' => $appointment->cancelledBy !== null ? $this->formatUserName($appointment->cancelledBy) : null,
            'performed_by_id' => $appointment->cancelled_by !== null ? (int) $appointment->cancelled_by : null,
            'action_at' => optional($actionAt)?->toIso8601String(),
            'created_at' => optional($actionAt)?->toIso8601String(),
            'reason' => $appointment->cancellation_reason,
            'cancellation_reason' => $status === self::STATUS_CANCELLED ? $appointment->cancellation_reason : null,
        ];
    }

    private function historyActionLabel(string $event, string $newStatus, ?string $reason = null): string
    {
        return match ($event) {
            'appointment_created' => $newStatus === self::STATUS_PENDING
                ? 'Pending appointment created'
                : 'Appointment created',
            'appointment_approved' => 'Approved appointment',
            'appointment_cancelled' => trim((string) $reason) !== ''
                ? 'Staff/Admin cancellation with reason'
                : 'Patient cancellation while still pending',
            'appointment_completed' => 'Completed appointment',
            'appointment_rescheduled' => 'Rescheduled appointment',
            'appointment_reschedule_required' => 'Reschedule required',
            'appointment_snapshot' => match ($newStatus) {
                self::STATUS_PENDING => 'Pending appointment created',
                self::STATUS_CONFIRMED => 'Approved appointment',
                self::STATUS_CANCELLED => 'Cancelled appointment',
                self::STATUS_COMPLETED => 'Completed appointment',
                default => 'Appointment status recorded',
            },
            default => 'Appointment status updated',
        };
    }

    private function formatHistoryActor(AuditTrail $trail): ?string
    {
        return $trail->user !== null ? $this->formatUserName($trail->user) : null;
    }

    private function formatUserName(User $user): string
    {
        $name = trim(sprintf(
            '%s %s',
            (string) $user->first_name,
            (string) $user->last_name,
        ));

        return $name !== '' ? $name : (string) $user->username;
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
        $appointment->loadMissing(['patient', 'service', 'services']);
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
                $this->appointmentServiceSummary($appointment),
                (string) $appointment->appointment_date,
            ),
        ]);
    }

    private function createRescheduleSuccessNotification(Appointment $appointment): void
    {
        $appointment->loadMissing(['patient', 'service', 'services']);
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
                $this->appointmentServiceSummary($appointment),
                (string) $appointment->appointment_date,
                (string) $appointment->time_slot,
            ),
        ]);
    }

    private function createStaffBookingNotification(Appointment $appointment): void
    {
        $appointment->loadMissing(['patient.user.role', 'service', 'services']);

        $patientName = trim(sprintf(
            '%s %s',
            (string) ($appointment->patient?->first_name ?? ''),
            (string) ($appointment->patient?->last_name ?? ''),
        ));
        $serviceName = $this->appointmentServiceSummary($appointment);
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

    private function createStaffCancelledPatientNotification(Appointment $appointment, string $reason): void
    {
        $appointment->loadMissing('patient');
        if ((int) ($appointment->patient?->user_id ?? 0) === 0) {
            return;
        }

        PatientNotification::create([
            'patient_id' => (int) $appointment->patient_id,
            'appointment_id' => (int) $appointment->id,
            'type' => 'appointment_cancelled',
            'title' => 'Appointment Cancelled',
            'message' => sprintf(
                'Your appointment on %s at %s has been cancelled. Reason: %s',
                (string) $appointment->appointment_date,
                (string) $appointment->time_slot,
                $reason,
            ),
        ]);
    }

    private function createPatientCancelledStaffNotification(Appointment $appointment): void
    {
        $appointment->loadMissing(['patient', 'service', 'services']);

        $patientName = trim(sprintf(
            '%s %s',
            (string) ($appointment->patient?->first_name ?? ''),
            (string) ($appointment->patient?->last_name ?? ''),
        ));

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
                'type' => 'staff_appointment_cancelled',
                'title' => 'Appointment cancelled by patient',
                'message' => sprintf(
                    '%s cancelled %s for %s at %s.',
                    $patientName !== '' ? $patientName : 'A patient',
                    $this->appointmentServiceSummary($appointment),
                    (string) $appointment->appointment_date,
                    (string) $appointment->time_slot,
                ),
            ]);
        }
    }

    private function recycleCancelledAppointment(
        Appointment $appointment,
        int $cancelledByUserId,
        ?string $cancellationReason = null,
    ): Appointment
    {
        DB::transaction(function () use ($appointment, $cancelledByUserId, $cancellationReason): void {
            if ((string) $appointment->status !== self::STATUS_CANCELLED) {
                $appointment->forceFill([
                    'status' => self::STATUS_CANCELLED,
                    'cancellation_reason' => $cancellationReason,
                    'cancelled_by' => $cancelledByUserId,
                    'cancelled_at' => Carbon::now('UTC'),
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
            ->with(['patient', 'queue', 'service', 'services', 'cancelledBy'])
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
