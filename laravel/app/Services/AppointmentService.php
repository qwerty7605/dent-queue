<?php

namespace App\Services;

use App\Models\Appointment;
use Illuminate\Database\QueryException;
use Illuminate\Validation\ValidationException;

class AppointmentService
{
    public function __construct(protected BookingRulesEngine $bookingRulesEngine)
    {
    }

    public function getAllAppointments()
    {
        return Appointment::with(['patient', 'service'])
            ->orderBy('appointment_date')
            ->orderBy('time_slot')
            ->get();
    }

    public function createAppointment(array $data)
    {
        $validatedBooking = $this->bookingRulesEngine->validate($data);

        try {
            return Appointment::create([
                'patient_id' => $data['patient_id'],
                'service_id' => $data['service_id'],
                'appointment_date' => $validatedBooking['appointment_date'],
                'time_slot' => $validatedBooking['time_slot'],
                'status' => 'pending',
            ])->load(['patient', 'service']);
        }
        catch (QueryException $exception) {
            if ((string) $exception->getCode() === '23000') {
                throw ValidationException::withMessages([
                    'time_slot' => ['This patient already has a booking for the selected date and time.'],
                ]);
            }

            throw $exception;
        }
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

        return $appointment->fresh(['patient', 'service']);
    }

    public function getPatientAppointments(int $patientId)
    {
        return Appointment::with(['patient', 'service'])
            ->where('patient_id', $patientId)
            ->orderBy('appointment_date')
            ->orderBy('time_slot')
            ->get();
    }
}
