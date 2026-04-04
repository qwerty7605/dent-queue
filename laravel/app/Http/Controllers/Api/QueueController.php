<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Appointment;
use App\Models\PatientRecord;
use App\Support\AppointmentQueueOrder;
use Illuminate\Http\Request;
use App\Services\QueueService;
use Illuminate\Http\JsonResponse;
use Illuminate\Validation\ValidationException;

class QueueController extends Controller
{
    public function __construct(protected QueueService $queueService)
    {
    }

    /**
     * Display a listing of the resource.
     */
    public function index(Request $request): JsonResponse
    {
        $payload = $request->validate([
            'date' => ['sometimes', 'date_format:Y-m-d'],
        ]);

        $isPatientRoute = $request->is('api/v1/patient/queues/*');
        $patientRecordId = $isPatientRoute
            ? (int) $this->resolveAuthenticatedPatientRecord($request)->id
            : null;

        $snapshot = $this->queueService->getQueueSnapshot(
            $patientRecordId,
            $payload['date'] ?? null,
        );

        return response()->json($snapshot);
    }

    /**
     * Store a newly created resource in storage (Generate next queue number).
     */
    public function store(Request $request): JsonResponse
    {
        $patientRecord = $this->resolveAuthenticatedPatientRecord($request);
        $appointment = Appointment::query()
            ->where('patient_id', (int) $patientRecord->id)
            ->whereDate('appointment_date', now(config('app.timezone'))->toDateString())
            ->whereIn('status', ['pending', 'confirmed', 'completed'])
            ->tap(static fn ($query) => AppointmentQueueOrder::apply($query, 'appointments'))
            ->first();

        if ($appointment === null) {
            return response()->json([
                'message' => 'No active appointment was found for today.',
            ], 404);
        }

        $queue = $this->queueService->generateQueueNumber((int) $appointment->id);
        $snapshot = $this->queueService->getQueueSnapshot(
            (int) $patientRecord->id,
            (string) $appointment->appointment_date,
        );

        return response()->json([
            'message' => 'Queue joined successfully.',
            'queue' => [
                'appointment_id' => (int) $queue->appointment_id,
                'queue_number' => (int) $queue->queue_number,
                'is_called' => (bool) $queue->is_called,
            ],
            ...$snapshot,
        ], 201);
    }

    /**
     * Call the next patient (Update next is_called to true).
     */
    public function callNext(Request $request): JsonResponse
    {
        $roleName = strtolower((string) optional($request->user()?->role)->name);
        if ($roleName === 'intern') {
            return response()->json([
                'message' => 'Intern accounts have read-only access.',
            ], 403);
        }

        $payload = $request->validate([
            'date' => ['sometimes', 'date_format:Y-m-d'],
        ]);

        $result = $this->queueService->callNext($payload['date'] ?? null);

        return response()->json([
            'message' => $result['called_queue'] !== null
                ? 'Next patient called successfully.'
                : 'No more approved patients waiting in queue.',
            ...$result,
        ]);
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
}
