<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Appointment;
use App\Models\PatientRecord;
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
        $patientRecord = $this->resolveAuthenticatedPatientRecord($request);
        $appointments = $this->appointmentService->getPatientAppointments((int) $patientRecord->id);
        
        return response()->json([
            'appointments' => $appointments->map(fn ($appointment) => $this->formatAppointmentResponse($appointment)),
        ]);
    }

    public function medicalHistory(Request $request): JsonResponse
    {
        $patientRecord = $this->resolveAuthenticatedPatientRecord($request);
        $appointments = $this->appointmentService->getPatientCompletedAppointments((int) $patientRecord->id);

        return response()->json([
            'appointments' => $appointments->map(fn ($appointment) => [
                'date' => (string) $appointment->appointment_date,
                'service_type' => match ((int) $appointment->service_id) {
                    1 => 'Dental Check-up',
                    2 => 'Dental Panoramic X-ray',
                    3 => 'Root Canal',
                    4 => 'Teeth Cleaning',
                    5 => 'Teeth Whitening',
                    6 => 'Tooth Extraction',
                    default => 'Unknown Service',
                },
                'status' => ucfirst((string) $appointment->status),
            ]),
        ]);
    }

    public function indexAdmin(Request $request): JsonResponse
    {
        $payload = $request->validate([
            'date' => ['required', 'date_format:Y-m-d'],
        ]);

        $appointments = $this->appointmentService->getAppointmentsByDateOrderedQueue(
            (string) $payload['date'],
        );

        return response()->json([
            'date' => (string) $payload['date'],
            'appointments' => $appointments,
        ]);
    }

    /**
     * Store a newly created appointment in storage.
     */
    public function storeAdmin(Request $request): JsonResponse
    {
        $payload = $request->validate([
            'patient_id' => ['required', 'integer', 'exists:patient_records,id'],
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
        $payload['patient_id'] = (int) $this->resolveAuthenticatedPatientRecord($request)->id;

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
        if ($request->filled('surname') && !$request->filled('last_name')) {
            $request->merge([
                'last_name' => $request->input('surname'),
            ]);
        }

        $payload = $request->validate([
            'first_name' => ['required', 'string', 'max:100'],
            'middle_name' => ['nullable', 'string', 'max:100'],
            'last_name' => ['required', 'string', 'max:100'],
            'surname' => ['sometimes', 'nullable', 'string', 'max:100'],
            'address' => ['required', 'string', 'max:255'],
            'gender' => ['required', 'string', 'in:Male,Female,Other'],
            'contact_number' => ['required', 'string', 'max:20'],
            'birthdate' => ['nullable', 'date', 'before_or_equal:today'],
            'service_type' => ['required', 'string', 'exists:services,name'],
            'appointment_date' => ['required', 'date_format:Y-m-d'],
            'appointment_time' => ['required', 'string'],
        ]);

        $service = Service::query()->where('name', (string) $payload['service_type'])->first();

        if ($service === null) {
            return response()->json([
                'message' => 'The selected service type is invalid.',
            ], 422);
        }

        try {
            [$patientRecord, $appointment] = $this->appointmentService->createWalkInAppointment([
                'first_name' => $payload['first_name'],
                'middle_name' => $payload['middle_name'] ?? null,
                'last_name' => $payload['last_name'],
                'address' => $payload['address'],
                'gender' => strtolower($payload['gender']),
                'contact_number' => $payload['contact_number'],
                'birthdate' => $payload['birthdate'] ?? null,
                'user_id' => null,
            ], [
                'service_id' => $service->id,
                'appointment_date' => $payload['appointment_date'],
                'time_slot' => $payload['appointment_time'],
                'status' => 'approved',
                'notes' => 'Walk-In Patient',
            ]);

            $appointmentResponse = $this->formatAppointmentResponse($appointment);
            $appointmentResponse['status'] = 'Approved';

            return response()->json([
                'message' => 'Walk-in booking created successfully.',
                'patient_record' => [
                    'id' => (int) $patientRecord->id,
                    'patient_id' => (string) $patientRecord->patient_id,
                    'user_id' => $patientRecord->user_id,
                    'first_name' => (string) $patientRecord->first_name,
                    'middle_name' => $patientRecord->middle_name,
                    'last_name' => (string) $patientRecord->last_name,
                    'gender' => (string) $patientRecord->gender,
                    'address' => (string) $patientRecord->address,
                    'contact_number' => (string) $patientRecord->contact_number,
                    'birthdate' => optional($patientRecord->birthdate)?->toDateString(),
                ],
                'appointment' => $appointmentResponse,
            ], 201);

        } catch (\Illuminate\Validation\ValidationException $e) {
            throw $e;
        } catch (\Exception $e) {
            return response()->json([
                'message' => 'Failed to create walk-in appointment.',
                'error' => $e->getMessage()
            ], 500);
        }
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
            (int) $request->user()->id,
        );

        return response()->json([
            'message' => 'Appointment status updated successfully.',
            'appointment' => $this->formatAppointmentResponse($updatedAppointment),
        ]);
    }

    public function cancel(Request $request, Appointment $appointment): JsonResponse
    {
        $patientRecord = $this->resolveAuthenticatedPatientRecord($request);

        if ((int) $appointment->patient_id !== (int) $patientRecord->id) {
            return response()->json([
                'message' => 'Unauthorized. You can only cancel your own appointments.',
            ], 403);
        }

        $updatedAppointment = $this->appointmentService->cancelByPatient(
            $appointment,
            (int) $patientRecord->id,
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
            $rules['patient_id'] = ['required', 'integer', 'exists:patient_records,id'];
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

    private function resolveAuthenticatedPatientRecord(Request $request): PatientRecord
    {
        /** @var \App\Models\User $user */
        $user = $request->user();

        return PatientRecord::resolveForUser($user);
    }
}
