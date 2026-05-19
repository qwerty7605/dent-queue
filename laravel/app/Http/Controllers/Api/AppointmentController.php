<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Api\Concerns\InteractsWithReportFilters;
use App\Http\Controllers\Controller;
use App\Models\Appointment;
use App\Models\PatientRecord;
use App\Models\Service;
use App\Services\AppointmentService;
use App\Services\ReportService;
use Illuminate\Http\Exceptions\HttpResponseException;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Validation\ValidationException;

class AppointmentController extends Controller
{
    use InteractsWithReportFilters;

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
        $history = $this->appointmentService->getPatientAppointmentHistory((int) $patientRecord->id);

        return response()->json([
            'appointments' => $history,
            'history' => $history,
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

    public function masterList(Request $request, ReportService $reportService): JsonResponse
    {
        $filters = $this->validateReportFilters($request);
        $search = $this->validateMasterListSearch($request);
        if ($search !== null) {
            $filters['search'] = $search;
        }
        $pagination = $this->resolvePagination($request);

        if ($pagination !== null) {
            return response()->json(
                $reportService->getDetailedRecordsPage(
                    $filters,
                    $pagination['page'],
                    $pagination['per_page'],
                ),
            );
        }

        $appointments = $reportService->getDetailedRecords($filters);

        return response()->json([
            'data' => $appointments,
        ]);
    }

    public function validatePatientBooking(Request $request): JsonResponse
    {
        $patientRecord = $this->resolveAuthenticatedPatientRecord($request);

        return $this->validateBookingAvailabilityForPatient(
            $request,
            (int) $patientRecord->id,
        );
    }

    public function validateAdminBooking(Request $request): JsonResponse
    {
        $this->forbidInternWrites($request);

        $payload = $request->validate([
            'patient_id' => ['required', 'integer', 'exists:patient_records,id'],
        ]);

        return $this->validateBookingAvailabilityForPatient(
            $request,
            (int) $payload['patient_id'],
        );
    }

    public function calendarAppointments(Request $request): JsonResponse
    {
        $payload = $request->validate([
            'date' => ['required', 'date_format:Y-m-d'],
        ]);

        $appointments = $this->appointmentService->getCalendarAppointmentsByDate(
            (string) $payload['date'],
        );

        return response()->json([
            'date' => (string) $payload['date'],
            'appointments' => $appointments,
        ]);
    }

    public function calendarAppointmentDetails(Appointment $appointment): JsonResponse
    {
        $details = $this->appointmentService->getCalendarAppointmentDetails(
            (int) $appointment->id,
        );

        if ($details === null) {
            return response()->json([
                'message' => 'Appointment not found.',
            ], 404);
        }

        return response()->json([
            'appointment' => $details,
        ]);
    }

    /**
     * Store a newly created appointment in storage.
     */
    public function storeAdmin(Request $request): JsonResponse
    {
        $this->forbidInternWrites($request);

        $payload = $request->validate([
            'patient_id' => ['required', 'integer', 'exists:patient_records,id'],
            'service_type' => ['required_without_all:service_types,services', 'string', 'exists:services,name'],
            'service_types' => ['required_without_all:service_type,services', 'array', 'min:1'],
            'service_types.*' => ['required', 'string', 'exists:services,name'],
            'services' => ['required_without_all:service_type,service_types', 'array', 'min:1'],
            'services.*' => ['required', 'integer', 'exists:services,id'],
            'appointment_date' => ['required', 'date_format:Y-m-d'],
            'appointment_time' => ['required', 'string'],
            'notes' => ['nullable', 'string', 'max:1000'],
        ]);

        $serviceIds = $this->resolveServiceIdsFromPayload($payload);

        $appointment = $this->appointmentService->createAppointment([
            'patient_id' => (int) $payload['patient_id'],
            'service_ids' => $serviceIds,
            'appointment_date' => (string) $payload['appointment_date'],
            'time_slot' => (string) $payload['appointment_time'],
            'status' => 'approved',
            'notes' => $payload['notes'] ?? null,
            'actor_user_id' => (int) $request->user()->id,
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
        $payload['actor_user_id'] = (int) $request->user()->id;

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
        $this->forbidInternWrites($request);

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
            'contact_number' => ['required', 'regex:/^09\d{9}$/'],
            'birthdate' => ['nullable', 'date', 'before_or_equal:today'],
            'service_type' => ['required_without_all:service_types,services', 'string', 'exists:services,name'],
            'service_types' => ['required_without_all:service_type,services', 'array', 'min:1'],
            'service_types.*' => ['required', 'string', 'exists:services,name'],
            'services' => ['required_without_all:service_type,service_types', 'array', 'min:1'],
            'services.*' => ['required', 'integer', 'exists:services,id'],
            'appointment_date' => ['required', 'date_format:Y-m-d'],
            'appointment_time' => ['required', 'string'],
        ], [
            'contact_number.regex' => 'Contact number must be a valid 11-digit mobile number starting with 09.',
        ]);

        $serviceIds = $this->resolveServiceIdsFromPayload($payload);

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
                'service_ids' => $serviceIds,
                'appointment_date' => $payload['appointment_date'],
                'time_slot' => $payload['appointment_time'],
                'status' => 'approved',
                'notes' => 'Walk-In Patient',
                'actor_user_id' => (int) $request->user()->id,
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
        $this->forbidInternWrites($request);

        $payload = $this->validateBookingPayload($request, true);
        $payload['actor_user_id'] = (int) $request->user()->id;
        $appointment = $this->appointmentService->createAppointment($payload);

        $appointment->load('queue');

        return response()->json([
            'message' => 'Follow-up booking created successfully.',
            'appointment' => $this->formatAppointmentResponse($appointment),
        ], 201);
    }

    public function updateStatus(Request $request, Appointment $appointment): JsonResponse
    {
        $this->forbidInternWrites($request);

        $payload = $request->validate([
            'status' => ['required', 'string'],
            'cancellation_reason' => ['nullable', 'string', 'max:2000'],
        ]);

        $updatedAppointment = $this->appointmentService->updateStatus(
            $appointment,
            (string) $payload['status'],
            (int) $request->user()->id,
            $payload['cancellation_reason'] ?? null,
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
            (int) $request->user()->id,
        );

        return response()->json([
            'message' => 'Appointment cancelled successfully.',
            'appointment' => $this->formatAppointmentResponse($updatedAppointment),
        ]);
    }

    public function restore(Request $request, $id): JsonResponse
    {
        $this->forbidInternWrites($request);

        $user = $request->user();
        if ($user->role === null) {
            $user->load('role');
        }

        $isPatient = $request->is('api/v1/patient/appointments/recycle-bin')
            || mb_strtolower((string) $user->role->name) === 'patient';
        
        /** @var Appointment $appointment */
        $appointment = Appointment::withTrashed()->findOrFail($id);

        if ($isPatient) {
            $patientRecord = $this->resolveAuthenticatedPatientRecord($request);
            if ((int) $appointment->patient_id !== (int) $patientRecord->id) {
                return response()->json([
                    'message' => 'Unauthorized. You can only restore your own appointments.',
                ], 403);
            }
        }

        try {
            $restoredAppointment = $this->appointmentService->restoreAppointment($appointment);
            return response()->json([
                'message' => 'Appointment restored successfully.',
                'appointment' => $this->formatAppointmentResponse($restoredAppointment),
            ]);
        } catch (ValidationException $e) {
            return response()->json([
                'type' => 'validation_error',
                'message' => 'The given data was invalid.',
                'errors' => $e->errors(),
            ], 422);
        }
    }

    public function recycleBin(Request $request): JsonResponse
    {
        $patientId = null;

        if (!str_contains($request->path(), 'admin/appointments/recycle-bin')) {
            $patientRecord = $this->resolveAuthenticatedPatientRecord($request);
            $patientId = (int) $patientRecord->id;
        }

        $appointments = $this->appointmentService->getRecycleBinAppointments($patientId);

        return response()->json([
            'recycle_bin' => $appointments->map(function ($appointment) {
                $data = $this->formatAppointmentResponse($appointment);
                if ($appointment->patient) {
                    $data['patient_name'] = trim("{$appointment->patient->first_name} {$appointment->patient->last_name}");
                }
                return $data;
            }),
        ]);
    }

    /**
     * Display the specified resource.
     */
    public function show(Request $request, string $id): JsonResponse
    {
        $patientRecord = $this->resolveAuthenticatedPatientRecord($request);

        /** @var Appointment $appointment */
        $appointment = Appointment::withTrashed()
            ->with([
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
            ->findOrFail($id);

        if ((int) $appointment->patient_id !== (int) $patientRecord->id) {
            return response()->json([
                'message' => 'Unauthorized. You can only view your own appointments.',
            ], 403);
        }

        return response()->json([
            'appointment' => $this->formatAppointmentResponse($appointment),
        ]);
    }

    /**
     * Update the specified resource in storage.
     */
    public function update(Request $request, string $id): JsonResponse
    {
        $patientRecord = $this->resolveAuthenticatedPatientRecord($request);

        /** @var Appointment $appointment */
        $appointment = Appointment::query()
            ->with(['patient', 'queue', 'service', 'services'])
            ->findOrFail($id);

        if ((int) $appointment->patient_id !== (int) $patientRecord->id) {
            return response()->json([
                'message' => 'Unauthorized. You can only update your own appointments.',
            ], 403);
        }

        $payload = $request->validate([
            'appointment_date' => ['required', 'date_format:Y-m-d'],
            'time_slot' => ['required', 'string'],
            'services' => ['sometimes', 'array', 'min:1'],
            'services.*' => ['required', 'integer', 'exists:services,id'],
            'service_id' => ['sometimes', 'integer', 'exists:services,id'],
            'notes' => ['nullable', 'string', 'max:1000'],
        ]);

        if (array_key_exists('services', $payload)) {
            $payload['service_ids'] = $payload['services'];
        }

        $updatedAppointment = $this->appointmentService->rescheduleByPatient(
            $appointment,
            (int) $patientRecord->id,
            $payload,
            (int) $request->user()->id,
        );

        return response()->json([
            'message' => 'Appointment rescheduled successfully.',
            'appointment' => $this->formatAppointmentResponse($updatedAppointment),
        ]);
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
            'service_id' => ['required_without:services', 'integer', 'exists:services,id'],
            'services' => ['required_without:service_id', 'array', 'min:1'],
            'services.*' => ['required', 'integer', 'exists:services,id'],
            'appointment_date' => ['required', 'date_format:Y-m-d'],
            'time_slot' => ['required', 'string'],
            'notes' => ['nullable', 'string', 'max:1000'],
        ];

        if ($requirePatientId) {
            $rules['patient_id'] = ['required', 'integer', 'exists:patient_records,id'];
        }

        $payload = $request->validate($rules);

        if (array_key_exists('services', $payload)) {
            $payload['service_ids'] = $payload['services'];
        }

        return $payload;
    }

    private function validateBookingAvailabilityForPatient(Request $request, int $patientId): JsonResponse
    {
        $payload = $request->validate([
            'appointment_date' => ['required', 'date_format:Y-m-d'],
            'appointment_time' => ['required_without:time_slot', 'string'],
            'time_slot' => ['required_without:appointment_time', 'string'],
            'service_id' => ['required_without_all:services,service_ids,service_type,service_types', 'integer', 'exists:services,id'],
            'services' => ['required_without_all:service_id,service_ids,service_type,service_types', 'array', 'min:1'],
            'services.*' => ['required', 'integer', 'exists:services,id'],
            'service_ids' => ['required_without_all:service_id,services,service_type,service_types', 'array', 'min:1'],
            'service_ids.*' => ['required', 'integer', 'exists:services,id'],
            'service_type' => ['required_without_all:service_id,services,service_ids,service_types', 'string', 'exists:services,name'],
            'service_types' => ['required_without_all:service_id,services,service_ids,service_type', 'array', 'min:1'],
            'service_types.*' => ['required', 'string', 'exists:services,name'],
        ]);

        if (array_key_exists('service_ids', $payload)) {
            $payload['services'] = $payload['service_ids'];
        } elseif (!array_key_exists('services', $payload)) {
            $payload['services'] = $this->resolveServiceIdsFromPayload($payload);
        }

        try {
            $validated = $this->appointmentService->validateBookingRequest($payload, $patientId);
        } catch (ValidationException $exception) {
            return response()->json([
                'valid' => false,
                'message' => $this->firstValidationMessage($exception),
                'errors' => $exception->errors(),
            ]);
        }

        return response()->json([
            'valid' => true,
            'message' => 'Schedule is available.',
            'data' => $validated,
        ]);
    }

    private function firstValidationMessage(ValidationException $exception): string
    {
        foreach ($exception->errors() as $messages) {
            if (is_array($messages) && $messages !== []) {
                return (string) $messages[0];
            }
        }

        return 'The selected appointment schedule is not available.';
    }

    private function validateMasterListSearch(Request $request): ?string
    {
        $payload = $request->validate([
            'search' => ['nullable', 'string', 'max:100'],
        ]);

        $search = trim((string) ($payload['search'] ?? ''));

        return $search !== '' ? $search : null;
    }

    private function formatAppointmentResponse(Appointment $appointment): array
    {
        $appointment->loadMissing('cancelledBy');

        return [
            'id' => (int) $appointment->id,
            'patient_id' => (int) $appointment->patient_id,
            'service_id' => (int) $appointment->service_id,
            'service_ids' => $appointment->selectedServiceIds(),
            'service_type' => $appointment->serviceSummary(),
            'services' => $this->formatSelectedServices($appointment),
            'appointment_date' => (string) $appointment->appointment_date,
            'appointment_time' => (string) $appointment->time_slot,
            'status' => AppointmentService::humanStatusLabel((string) $appointment->status),
            'queue_number' => $appointment->queue ? str_pad((string) $appointment->queue->queue_number, 2, '0', STR_PAD_LEFT) : null,
            'is_called' => (bool) ($appointment->queue?->is_called ?? false),
            'timestamp_created' => optional($appointment->created_at)?->toIso8601String(),
            'notes' => (string) $appointment->notes,
            'cancellation_reason' => $appointment->cancellation_reason,
            'cancelled_by' => $appointment->cancelled_by !== null ? (int) $appointment->cancelled_by : null,
            'cancelled_by_name' => $this->formatCancelledByName($appointment),
            'cancelled_at' => optional($appointment->cancelled_at)?->toIso8601String(),
            'logs' => $this->appointmentService->formatAppointmentLogs($appointment),
            'reschedule_reason' => $this->resolveRescheduleReason($appointment),
            'recycle_bin' => $this->appointmentService->buildRecycleBinState($appointment),
        ];
    }

    /**
     * @param  array<string, mixed>  $payload
     * @return list<int>
     */
    private function resolveServiceIdsFromPayload(array $payload): array
    {
        if (isset($payload['services']) && is_array($payload['services'])) {
            return collect($payload['services'])
                ->map(static fn (mixed $id): int => (int) $id)
                ->filter(static fn (int $id): bool => $id > 0)
                ->unique()
                ->values()
                ->all();
        }

        $serviceNames = [];
        if (isset($payload['service_types']) && is_array($payload['service_types'])) {
            $serviceNames = $payload['service_types'];
        } elseif (isset($payload['service_type'])) {
            $serviceNames = [(string) $payload['service_type']];
        }

        return Service::query()
            ->whereIn('name', $serviceNames)
            ->orderBy('id')
            ->pluck('id')
            ->map(static fn (mixed $id): int => (int) $id)
            ->values()
            ->all();
    }

    private function formatSelectedServices(Appointment $appointment): array
    {
        return $appointment->selectedServices()
            ->map(static fn (Service $service): array => [
                'id' => (int) $service->id,
                'name' => (string) $service->name,
            ])
            ->values()
            ->all();
    }

    private function formatCancelledByName(Appointment $appointment): ?string
    {
        if ($appointment->cancelledBy === null) {
            return null;
        }

        $name = trim(sprintf(
            '%s %s',
            (string) $appointment->cancelledBy->first_name,
            (string) $appointment->cancelledBy->last_name,
        ));

        return $name !== '' ? $name : (string) $appointment->cancelledBy->username;
    }

    private function resolveRescheduleReason(Appointment $appointment): ?string
    {
        if ((string) $appointment->status !== 'reschedule_required') {
            return null;
        }

        $notification = $appointment->patientNotifications
            ->firstWhere('type', 'appointment_reschedule_required');

        if ($notification === null) {
            return 'Your original appointment slot is no longer available.';
        }

        $message = trim((string) $notification->message);
        if ($message === '') {
            return 'Your original appointment slot is no longer available.';
        }

        $reasonMarker = 'Reason: ';
        $reasonStart = strpos($message, $reasonMarker);
        if ($reasonStart !== false) {
            $reasonText = substr($message, $reasonStart + strlen($reasonMarker));
            $reasonText = trim((string) preg_replace('/\s*Please choose a new appointment time\.?$/', '', $reasonText));
            $reasonText = trim($reasonText, " .\t\n\r\0\x0B");

            if ($reasonText !== '') {
                return $reasonText . '.';
            }
        }

        if (str_contains($message, 'clinic schedule changed')) {
            return 'The clinic schedule changed and your original slot is no longer available.';
        }

        if (str_contains($message, 'doctor is unavailable')) {
            return 'The doctor is unavailable at your original appointment time.';
        }

        return 'Your original appointment slot is no longer available.';
    }

    private function resolveAuthenticatedPatientRecord(Request $request): PatientRecord
    {
        /** @var \App\Models\User $user */
        $user = $request->user();

        $patientRecord = $user->patientRecord()->first();

        if ($patientRecord === null) {
            throw ValidationException::withMessages([
                'patient_id' => ['Authenticated patient must be linked to an existing patient record.'],
            ]);
        }

        return $patientRecord;
    }

    private function forbidInternWrites(Request $request): void
    {
        $roleName = strtolower((string) optional($request->user()?->role)->name);

        if ($roleName === 'intern') {
            throw new HttpResponseException(response()->json([
                'message' => 'Intern accounts have read-only access.',
            ], 403));
        }
    }

    private function resolvePagination(Request $request): ?array
    {
        if (!$request->hasAny(['page', 'per_page'])) {
            return null;
        }

        $payload = $request->validate([
            'page' => ['nullable', 'integer', 'min:1'],
            'per_page' => ['nullable', 'integer', 'min:1', 'max:100'],
        ]);

        return [
            'page' => (int) ($payload['page'] ?? 1),
            'per_page' => (int) ($payload['per_page'] ?? 25),
        ];
    }
}
