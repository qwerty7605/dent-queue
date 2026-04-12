<?php

namespace App\Services;

use App\Models\Appointment;
use App\Models\Queue;
use App\Models\PatientNotification;
use App\Support\AppointmentQueueOrder;
use Illuminate\Database\QueryException;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

class QueueService
{
    private const DAILY_QUEUE_LIMIT = 50;
    private const MAX_QUEUE_ASSIGNMENT_RETRIES = 5;
    private const ACTIVE_QUEUE_STATUSES = ['pending', 'confirmed', 'completed'];
    private const ELIGIBLE_CALL_STATUSES = ['confirmed'];
    private const ACTIVE_DISPLAY_STATUSES = ['pending', 'confirmed', 'completed'];

    public function generateQueueNumber(?int $appointmentId = null)
    {
        if ($appointmentId === null) {
            throw ValidationException::withMessages([
                'appointment_id' => ['Appointment ID is required.'],
            ]);
        }

        $appointment = Appointment::query()->find($appointmentId);
        if ($appointment === null) {
            throw ValidationException::withMessages([
                'appointment_id' => ['Appointment not found.'],
            ]);
        }

        $appointmentDate = (string) $appointment->appointment_date;

        return DB::transaction(function () use ($appointment, $appointmentDate) {
            for ($attempt = 0; $attempt < self::MAX_QUEUE_ASSIGNMENT_RETRIES; $attempt++) {
                try {
                    $existingQueue = Queue::query()
                        ->where('appointment_id', (int) $appointment->id)
                        ->lockForUpdate()
                        ->first();

                    if ($existingQueue === null) {
                        $this->createPlaceholderQueueEntry($appointmentDate, (int) $appointment->id);
                    }

                    $this->syncQueueNumbersForDate($appointmentDate);

                    return Queue::query()
                        ->where('appointment_id', (int) $appointment->id)
                        ->firstOrFail();
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

    public function syncQueueNumbersForDate(string $appointmentDate): void
    {
        $activeAppointments = Appointment::query()
            ->whereDate('appointment_date', $appointmentDate)
            ->whereNull('deleted_at')
            ->whereIn('status', self::ACTIVE_QUEUE_STATUSES)
            ->tap(static fn ($query) => AppointmentQueueOrder::apply($query))
            ->lockForUpdate()
            ->get(['id', 'appointment_date']);

        if ($activeAppointments->count() > self::DAILY_QUEUE_LIMIT) {
            throw ValidationException::withMessages([
                'appointment_date' => ['The daily limit of ' . self::DAILY_QUEUE_LIMIT . ' patients has been reached for this date.'],
            ]);
        }

        $activeAppointmentIds = $activeAppointments->pluck('id')->map(
            static fn (mixed $id): int => (int) $id,
        )->all();

        $existingQueues = Queue::query()
            ->where('queue_date', $appointmentDate)
            ->lockForUpdate()
            ->get()
            ->keyBy(static fn (Queue $queue): int => (int) $queue->appointment_id);
        $calledStateByAppointmentId = $existingQueues->mapWithKeys(
            static fn (Queue $queue, int $appointmentId): array => [
                $appointmentId => (bool) $queue->is_called,
            ],
        );

        if ($existingQueues->isNotEmpty()) {
            Queue::query()
                ->whereIn(
                    'id',
                    $existingQueues
                        ->pluck('id')
                        ->map(static fn (mixed $id): int => (int) $id)
                        ->all(),
                )
                ->delete();
        }

        foreach ($activeAppointmentIds as $index => $appointmentId) {
            Queue::query()->create([
                'appointment_id' => $appointmentId,
                'queue_date' => $appointmentDate,
                'queue_number' => $index + 1,
                'is_called' => (bool) ($calledStateByAppointmentId[$appointmentId] ?? false),
            ]);
        }
    }

    public function removeQueueForAppointment(Appointment $appointment): void
    {
        DB::transaction(function () use ($appointment): void {
            Queue::query()
                ->where('appointment_id', (int) $appointment->id)
                ->lockForUpdate()
                ->delete();

            $this->syncQueueNumbersForDate((string) $appointment->appointment_date);
        });
    }

    public function getQueueSnapshot(?int $patientRecordId = null, ?string $date = null): array
    {
        $queueDate = $date !== null
            ? Carbon::createFromFormat('Y-m-d', $date)->toDateString()
            : Carbon::today(config('app.timezone'))->toDateString();

        $hasActiveAppointmentsForDate = Appointment::query()
            ->whereDate('appointment_date', $queueDate)
            ->whereNull('deleted_at')
            ->whereIn('status', self::ACTIVE_QUEUE_STATUSES)
            ->exists();

        if ($hasActiveAppointmentsForDate) {
            $this->syncQueueNumbersForDate($queueDate);
        }

        $nowServing = Queue::query()
            ->join('appointments', 'appointments.id', '=', 'queues.appointment_id')
            ->leftJoin('patient_records', 'patient_records.id', '=', 'appointments.patient_id')
            ->leftJoin('services', 'services.id', '=', 'appointments.service_id')
            ->where('queues.queue_date', $queueDate)
            ->whereNull('appointments.deleted_at')
            ->where('queues.is_called', true)
            ->whereIn('appointments.status', ['confirmed', 'completed'])
            ->tap(static fn ($query) => AppointmentQueueOrder::applyDescending($query))
            ->select([
                'queues.queue_number',
                'queues.is_called',
                'appointments.id as appointment_id',
                'appointments.status',
                'appointments.time_slot',
                'services.name as service_name',
                'patient_records.first_name',
                'patient_records.last_name',
            ])
            ->first();

        $nextUp = Queue::query()
            ->join('appointments', 'appointments.id', '=', 'queues.appointment_id')
            ->leftJoin('patient_records', 'patient_records.id', '=', 'appointments.patient_id')
            ->leftJoin('services', 'services.id', '=', 'appointments.service_id')
            ->where('queues.queue_date', $queueDate)
            ->whereNull('appointments.deleted_at')
            ->where('queues.is_called', false)
            ->whereIn('appointments.status', self::ELIGIBLE_CALL_STATUSES)
            ->tap(static fn ($query) => AppointmentQueueOrder::apply($query))
            ->select([
                'queues.queue_number',
                'queues.is_called',
                'appointments.id as appointment_id',
                'appointments.status',
                'appointments.time_slot',
                'services.name as service_name',
                'patient_records.first_name',
                'patient_records.last_name',
            ])
            ->first();

        return [
            'date' => $queueDate,
            'now_serving' => $nowServing !== null ? $this->formatQueueEntry($nowServing) : null,
            'next_up' => $nextUp !== null ? $this->formatQueueEntry($nextUp) : null,
            'patient_queue' => $patientRecordId !== null
                ? $this->getPatientQueueEntry($patientRecordId, $queueDate, $nowServing !== null ? (int) $nowServing->queue_number : null)
                : null,
        ];
    }

    public function callNext(?string $date = null): array
    {
        $queueDate = $date !== null
            ? Carbon::createFromFormat('Y-m-d', $date)->toDateString()
            : Carbon::today(config('app.timezone'))->toDateString();
        $referenceTime = Carbon::now(config('app.timezone'));
        $today = $referenceTime->copy()->startOfDay()->toDateString();
        $queueStartTime = $referenceTime->copy()->setTime(8, 0);

        if ($queueDate !== $today) {
            throw ValidationException::withMessages([
                'date' => ['Queue calling is only available on the appointment date.'],
            ]);
        }

        if ($referenceTime->lt($queueStartTime)) {
            throw ValidationException::withMessages([
                'date' => ['Queue calling starts at 8:00 AM.'],
            ]);
        }

        $calledQueue = DB::transaction(function () use ($queueDate) {
            $this->syncQueueNumbersForDate($queueDate);

            $activeCalledQueue = Queue::query()
                ->join('appointments', 'appointments.id', '=', 'queues.appointment_id')
                ->where('queues.queue_date', $queueDate)
                ->whereNull('appointments.deleted_at')
                ->where('queues.is_called', true)
                ->where('appointments.status', 'confirmed')
                ->tap(static fn ($query) => AppointmentQueueOrder::applyDescending($query))
                ->select('queues.id')
                ->lockForUpdate()
                ->first();

            if ($activeCalledQueue !== null) {
                throw ValidationException::withMessages([
                    'queue' => ['The current called appointment must be completed before calling the next patient.'],
                ]);
            }

            $queue = Queue::query()
                ->join('appointments', 'appointments.id', '=', 'queues.appointment_id')
                ->where('queues.queue_date', $queueDate)
                ->whereNull('appointments.deleted_at')
                ->where('queues.is_called', false)
                ->whereIn('appointments.status', self::ELIGIBLE_CALL_STATUSES)
                ->tap(static fn ($query) => AppointmentQueueOrder::apply($query))
                ->select('queues.id')
                ->lockForUpdate()
                ->first();

            if ($queue === null) {
                return null;
            }

            Queue::query()
                ->whereKey((int) $queue->id)
                ->update(['is_called' => true]);

            return Queue::query()->find((int) $queue->id);
        });

        $snapshot = $this->getQueueSnapshot(null, $queueDate);

        if ($calledQueue !== null) {
            $appointment = Appointment::query()->find((int) $calledQueue->appointment_id);
            if ($appointment !== null && $appointment->patient_id !== null) {
                PatientNotification::firstOrCreate([
                    'patient_id' => $appointment->patient_id,
                    'appointment_id' => $appointment->id,
                    'type' => 'queue_now_serving',
                ], [
                    'title' => 'Queue Update',
                    'message' => 'Now serving your queue number: ' . $calledQueue->queue_number . '. Please proceed to the clinic.',
                ]);
            }
        }

        if ($snapshot['next_up'] !== null) {
            $nextUpAppointment = Appointment::query()->find($snapshot['next_up']['appointment_id']);
            if ($nextUpAppointment !== null && $nextUpAppointment->patient_id !== null) {
                PatientNotification::firstOrCreate([
                    'patient_id' => $nextUpAppointment->patient_id,
                    'appointment_id' => $nextUpAppointment->id,
                    'type' => 'queue_next_up',
                ], [
                    'title' => 'Queue Update',
                    'message' => 'Your turn is approaching. You are next in line (Queue #' . $snapshot['next_up']['queue_number'] . ').',
                ]);
            }
        }

        return [
            'date' => $queueDate,
            'called_queue' => $calledQueue !== null
                ? $this->formatQueueEntry(
                    Queue::query()
                        ->join('appointments', 'appointments.id', '=', 'queues.appointment_id')
                        ->leftJoin('patient_records', 'patient_records.id', '=', 'appointments.patient_id')
                        ->leftJoin('services', 'services.id', '=', 'appointments.service_id')
                        ->where('queues.appointment_id', (int) $calledQueue->appointment_id)
                        ->where('queues.queue_date', $queueDate)
                        ->whereNull('appointments.deleted_at')
                        ->select([
                            'queues.queue_number',
                            'queues.is_called',
                            'appointments.id as appointment_id',
                            'appointments.status',
                            'appointments.time_slot',
                            'services.name as service_name',
                            'patient_records.first_name',
                            'patient_records.last_name',
                        ])
                        ->first()
                )
                : null,
            'now_serving' => $snapshot['now_serving'],
            'next_up' => $snapshot['next_up'],
        ];
    }

    private function getPatientQueueEntry(int $patientRecordId, string $queueDate, ?int $nowServingNumber): ?array
    {
        $queue = Queue::query()
            ->join('appointments', 'appointments.id', '=', 'queues.appointment_id')
            ->leftJoin('services', 'services.id', '=', 'appointments.service_id')
            ->where('appointments.patient_id', $patientRecordId)
            ->where('queues.queue_date', $queueDate)
            ->whereNull('appointments.deleted_at')
            ->whereIn('appointments.status', self::ACTIVE_DISPLAY_STATUSES)
            ->tap(static fn ($query) => AppointmentQueueOrder::apply($query))
            ->select([
                'queues.queue_number',
                'queues.is_called',
                'appointments.id as appointment_id',
                'appointments.status',
                'appointments.time_slot',
                'services.name as service_name',
            ])
            ->first();

        if ($queue === null) {
            return null;
        }

        $queueNumber = (int) $queue->queue_number;
        $peopleAhead = Queue::query()
            ->join('appointments', 'appointments.id', '=', 'queues.appointment_id')
            ->where('queues.queue_date', $queueDate)
            ->where('queues.queue_number', '<', $queueNumber)
            ->whereNull('appointments.deleted_at')
            ->whereIn('appointments.status', self::ELIGIBLE_CALL_STATUSES)
            ->count();

        return [
            'appointment_id' => (int) $queue->appointment_id,
            'queue_number' => $queueNumber,
            'status' => $this->displayStatus((string) $queue->status),
            'appointment_time' => (string) $queue->time_slot,
            'service_type' => $this->resolveServiceType($queue->service_name),
            'is_called' => (bool) $queue->is_called,
            'is_now_serving' => $nowServingNumber !== null && $queueNumber === $nowServingNumber,
            'people_ahead' => max(0, $peopleAhead),
        ];
    }

    private function formatQueueEntry(object $entry): array
    {
        return [
            'appointment_id' => (int) $entry->appointment_id,
            'queue_number' => (int) $entry->queue_number,
            'patient_name' => trim(sprintf(
                '%s %s',
                (string) ($entry->first_name ?? ''),
                (string) ($entry->last_name ?? ''),
            )),
            'service_type' => $this->resolveServiceType($entry->service_name ?? null),
            'appointment_time' => (string) ($entry->time_slot ?? ''),
            'status' => $this->displayStatus((string) $entry->status),
            'is_called' => (bool) $entry->is_called,
        ];
    }

    private function resolveServiceType(?string $serviceName): string
    {
        return $serviceName !== null && $serviceName !== ''
            ? $serviceName
            : 'Unknown Service';
    }

    private function displayStatus(string $status): string
    {
        return $status === 'confirmed' ? 'Approved' : ucfirst($status);
    }

    private function createPlaceholderQueueEntry(string $appointmentDate, int $appointmentId): Queue
    {
        $nextQueueNumber = Queue::query()
            ->where('queue_date', $appointmentDate)
            ->lockForUpdate()
            ->orderByDesc('queue_number')
            ->value('queue_number');

        return Queue::query()->create([
            'appointment_id' => $appointmentId,
            'queue_date' => $appointmentDate,
            'queue_number' => ((int) $nextQueueNumber) + 1,
            'is_called' => false,
        ]);
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
}
