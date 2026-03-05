<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
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
        return response()->json([
            'appointments' => $this->appointmentService->getPatientAppointments((int) $request->user()->id),
        ]);
    }

    /**
     * Store a newly created online booking in storage.
     */
    public function store(Request $request): JsonResponse
    {
        $payload = $this->validateBookingPayload($request, false);
        $payload['patient_id'] = (int) $request->user()->id;

        $appointment = $this->appointmentService->createAppointment($payload);

        return response()->json([
            'message' => 'Online booking created successfully.',
            'appointment' => $appointment,
        ], 201);
    }

    /**
     * Store a newly created walk-in booking in storage.
     */
    public function storeWalkIn(Request $request): JsonResponse
    {
        $payload = $this->validateBookingPayload($request, true);
        $appointment = $this->appointmentService->createAppointment($payload);

        return response()->json([
            'message' => 'Walk-in booking created successfully.',
            'appointment' => $appointment,
        ], 201);
    }

    /**
     * Store a newly created follow-up booking in storage.
     */
    public function storeFollowUp(Request $request): JsonResponse
    {
        $payload = $this->validateBookingPayload($request, true);
        $appointment = $this->appointmentService->createAppointment($payload);

        return response()->json([
            'message' => 'Follow-up booking created successfully.',
            'appointment' => $appointment,
        ], 201);
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
            'service_id' => ['required', 'integer', 'exists:services,id'],
            'appointment_date' => ['required', 'date_format:Y-m-d'],
            'time_slot' => ['required', 'string'],
        ];

        if ($requirePatientId) {
            $rules['patient_id'] = ['required', 'integer', 'exists:users,id'];
        }

        return $request->validate($rules);
    }
}
