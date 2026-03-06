<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Appointment;
use App\Models\Service;
use App\Services\AppointmentService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class AppointmentController extends Controller
{
    public function __construct(protected AppointmentService $appointmentService)
    {
    }

    /**
     * Display a listing of the patient's appointments.
     */
    public function index(Request $request): JsonResponse
    {
        $appointments = $this->appointmentService->getPatientAppointments((int) $request->user()->id);
        
        return response()->json([
            'appointments' => $appointments->map(fn ($appointment) => $this->formatAppointmentResponse($appointment)),
        ]);
    }

    /**
     * Store a newly created appointment in storage.
     */
    public function storeAdmin(Request $request): JsonResponse
    {
        $payload = $request->validate([
            'patient_id' => ['required', 'integer', 'exists:users,id'],
            'service_type' => ['required', 'string', 'exists:services,name'],
            'appointment_date' => ['required', 'date_format:Y-m-d'],
            'appointment_time' => ['required', 'string'],
            'notes' => ['nullable', 'string', 'max:1000'],
        ]);

        $service = Service::query()->where('name', (string) $payload['service_type'])->first();

        if ($service === null) {
            return response()->json([
                'message' => 'The selected service type is invalid.',
            ], 422);
        }

        $appointment = $this->appointmentService->createAppointment([
            'patient_id' => (int) $payload['patient_id'],
            'service_id' => (int) $service->id,
            'appointment_date' => (string) $payload['appointment_date'],
            'time_slot' => (string) $payload['appointment_time'],
            'notes' => $payload['notes'] ?? null,
        ]);

        return response()->json([
            'message' => 'Appointment created successfully.',
            'appointment' => $this->formatAppointmentResponse($appointment),
        ], 201);
    }

    /**
     * Store a newly created online booking in storage.
     */
    public function store(Request $request): JsonResponse
    {
        $payload = $this->validateBookingPayload($request, false);
        $payload['patient_id'] = (int) $request->user()->id;

        $appointment = $this->appointmentService->createAppointment($payload);

        $appointment->load('queue');

        return response()->json([
            'message' => 'Online booking created successfully.',
            'appointment' => $this->formatAppointmentResponse($appointment),
        ], 201);
    }

    /**
     * Store a newly created walk-in booking in storage.
     */
    public function storeWalkIn(Request $request): JsonResponse
    {
        $payload = $this->validateBookingPayload($request, true);
        $appointment = $this->appointmentService->createAppointment($payload);

        $appointment->load('queue');

        return response()->json([
            'message' => 'Walk-in booking created successfully.',
            'appointment' => $this->formatAppointmentResponse($appointment),
        ], 201);
    }

    /**
     * Store a newly created follow-up booking in storage.
     */
    public function storeFollowUp(Request $request): JsonResponse
    {
        $payload = $this->validateBookingPayload($request, true);
        $appointment = $this->appointmentService->createAppointment($payload);

        $appointment->load('queue');

        return response()->json([
            'message' => 'Follow-up booking created successfully.',
            'appointment' => $this->formatAppointmentResponse($appointment),
        ], 201);
    }

    public function updateStatus(Request $request, Appointment $appointment): JsonResponse
    {
        $payload = $request->validate([
            'status' => ['required', 'string'],
        ]);

        $updatedAppointment = $this->appointmentService->updateStatus(
            $appointment,
            (string) $payload['status'],
        );

        return response()->json([
            'message' => 'Appointment status updated successfully.',
            'appointment' => $this->formatAppointmentResponse($updatedAppointment),
        ]);
    }

    public function cancel(Request $request, Appointment $appointment): JsonResponse
    {
        if ((int) $appointment->patient_id !== (int) $request->user()->id) {
            return response()->json([
                'message' => 'Unauthorized. You can only cancel your own appointments.',
            ], 403);
        }

        $updatedAppointment = $this->appointmentService->updateStatus(
            $appointment,
            'cancelled',
        );

        return response()->json([
            'message' => 'Appointment cancelled successfully.',
            'appointment' => $this->formatAppointmentResponse($updatedAppointment),
        ]);
    }

    /**
     * Display the specified resource.
     */
    public function show(string $id)
    {
        //
    }

    /**
     * Update the specified resource in storage.
     */
    public function update(Request $request, string $id)
    {
        //
    }

    /**
     * Remove the specified resource from storage.
     */
    public function destroy(string $id)
    {
        //
    }

    private function validateBookingPayload(Request $request, bool $requirePatientId): array
    {
        $rules = [
            'service_id' => ['required', 'integer', 'between:1,6'],
            'appointment_date' => ['required', 'date_format:Y-m-d'],
            'time_slot' => ['required', 'string'],
            'notes' => ['nullable', 'string', 'max:1000'],
        ];

        if ($requirePatientId) {
            $rules['patient_id'] = ['required', 'integer', 'exists:users,id'];
        }

        return $request->validate($rules);
    }

    private function formatAppointmentResponse(Appointment $appointment): array
    {
        return [
            'id' => (int) $appointment->id,
            'patient_id' => (int) $appointment->patient_id,
            'service_type' => match ((int) $appointment->service_id) {
                1 => 'Dental Check-up',
                2 => 'Dental Panoramic X-ray',
                3 => 'Root Canal',
                4 => 'Teeth Cleaning',
                5 => 'Teeth Whitening',
                6 => 'Tooth Extraction',
                default => 'Unknown Service',
            },
            'appointment_date' => (string) $appointment->appointment_date,
            'appointment_time' => (string) $appointment->time_slot,
            'status' => ucfirst((string) $appointment->status),
            'queue_number' => $appointment->queue ? str_pad((string) $appointment->queue->queue_number, 2, '0', STR_PAD_LEFT) : null,
            'timestamp_created' => optional($appointment->created_at)?->toDateTimeString(),
            'notes' => (string) $appointment->notes,
        ];
    }
}
