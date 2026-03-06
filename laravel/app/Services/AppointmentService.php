<?php

namespace App\Services;

use App\Models\Appointment;
use App\Models\Queue;
use Illuminate\Database\QueryException;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

class AppointmentService
{
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
            try {
                $appointment = Appointment::create([
                    'patient_id' => $data['patient_id'],
                    'service_id' => $data['service_id'],
                    'appointment_date' => $validatedBooking['appointment_date'],
                    'time_slot' => $validatedBooking['time_slot'],
                    'status' => 'pending',
                ]);

                $lastQueue = Queue::where('queue_date', $validatedBooking['appointment_date'])
                    ->lockForUpdate()
                    ->orderByDesc('queue_number')
                    ->first();

                $nextQueueNumber = $lastQueue ? $lastQueue->queue_number + 1 : 1;

                Queue::create([
                    'appointment_id' => $appointment->id,
                    'queue_date' => $validatedBooking['appointment_date'],
                    'queue_number' => $nextQueueNumber,
                    'is_called' => false,
                ]);

                return $appointment->load(['patient', 'queue']);
            }
            catch (QueryException $exception) {
                if ((string) $exception->getCode() === '23000') {
                    throw ValidationException::withMessages([
                        'time_slot' => ['This patient already has a booking for the selected date and time.'],
                    ]);
                }

                throw $exception;
            }
        });
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
