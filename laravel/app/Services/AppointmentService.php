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
                    'status' => 'pending',
                    'notes' => $data['notes'] ?? null,
                ]);

                $lastQueue = Queue::where('queue_date', $validatedBooking['appointment_date'])
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
        $allowedStatuses = ['pending', 'confirmed', 'cancelled', 'completed'];
        if (!in_array($status, $allowedStatuses, true)) {
            throw ValidationException::withMessages([
                'status' => ['Status must be one of: pending, confirmed, cancelled, completed.'],
            ]);
        }

        $appointment->update(['status' => $status]);

        return $appointment->fresh(['patient', 'queue']);
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
