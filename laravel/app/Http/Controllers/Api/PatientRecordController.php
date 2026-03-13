<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Appointment;
use App\Models\PatientRecord;
use App\Services\AppointmentService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class PatientRecordController extends Controller
{
    public function __construct(protected AppointmentService $appointmentService)
    {
    }

    /**
     * Search patient records by name or contact number.
     *
     * @param Request $request
     * @return \Illuminate\Http\JsonResponse
     */
    public function search(Request $request): JsonResponse
    {
        $query = $request->query('query');

        if (blank($query)) {
            return response()->json([
                'data' => []
            ]);
        }

        $searchTerm = '%' . $query . '%';
        $terms = array_filter(explode(' ', trim($query)));

        $patients = PatientRecord::query()
            ->where(function ($q) use ($terms, $searchTerm) {
                // If there are multiple words (like "Kyle Aldea"), we want to make sure
                // all words appear in either first, last or middle name.
                foreach ($terms as $term) {
                    $termLike = '%' . $term . '%';
                    $q->where(function ($subQ) use ($termLike) {
                        $subQ->where('first_name', 'LIKE', $termLike)
                             ->orWhere('last_name', 'LIKE', $termLike)
                             ->orWhere('middle_name', 'LIKE', $termLike);
                    });
                }
                
                // Allow patient ID and contact number matching for the full string.
                $q->orWhere('patient_id', 'LIKE', $searchTerm)
                    ->orWhere('contact_number', 'LIKE', $searchTerm);
            })
            ->limit(20)
            ->get();

        // Map to return only the requested fields
        $mappedPatients = $patients->map(function ($patient) {
            $middleInitial = $patient->middle_name ? ' ' . substr($patient->middle_name, 0, 1) . '.' : '';
            $fullName = trim("{$patient->first_name}{$middleInitial} {$patient->last_name}");
            
            return [
                'patient_id' => $patient->patient_id,
                'full_name' => $fullName,
                'contact_number' => $patient->contact_number,
            ];
        });

        return response()->json([
            'data' => $mappedPatients
        ]);
    }

    public function show(string $patientId): JsonResponse
    {
        $patientRecord = PatientRecord::query()
            ->where('patient_id', $patientId)
            ->firstOrFail();

        $upcomingAppointments = $this->appointmentService->getPatientUpcomingAppointments(
            (int) $patientRecord->id,
        );
        $clinicalHistory = $this->appointmentService->getPatientCompletedAppointments(
            (int) $patientRecord->id,
        );

        return response()->json([
            'patient' => $this->formatPatientResponse($patientRecord),
            'upcoming_appointments' => $upcomingAppointments->map(
                fn (Appointment $appointment) => $this->formatAppointmentResponse($appointment),
            ),
            'clinical_history' => $clinicalHistory->map(
                fn (Appointment $appointment) => $this->formatAppointmentResponse($appointment),
            ),
        ]);
    }

    private function formatPatientResponse(PatientRecord $patientRecord): array
    {
        return [
            'id' => (int) $patientRecord->id,
            'patient_id' => (string) $patientRecord->patient_id,
            'user_id' => $patientRecord->user_id !== null ? (int) $patientRecord->user_id : null,
            'first_name' => (string) $patientRecord->first_name,
            'middle_name' => $patientRecord->middle_name,
            'last_name' => (string) $patientRecord->last_name,
            'full_name' => $this->fullName($patientRecord),
            'gender' => $patientRecord->gender !== null ? ucfirst((string) $patientRecord->gender) : null,
            'birthdate' => optional($patientRecord->birthdate)?->toDateString(),
            'address' => $patientRecord->address,
            'contact_number' => $patientRecord->contact_number,
        ];
    }

    private function formatAppointmentResponse(Appointment $appointment): array
    {
        return [
            'id' => (int) $appointment->id,
            'service_id' => (int) $appointment->service_id,
            'service_type' => $appointment->service?->name ?? $this->fallbackServiceType((int) $appointment->service_id),
            'appointment_date' => (string) $appointment->appointment_date,
            'appointment_time' => (string) $appointment->time_slot,
            'status' => $this->displayStatus((string) $appointment->status),
        ];
    }

    private function fullName(PatientRecord $patientRecord): string
    {
        $middleInitial = $patientRecord->middle_name !== null && $patientRecord->middle_name !== ''
            ? ' ' . mb_substr((string) $patientRecord->middle_name, 0, 1) . '.'
            : '';

        return trim(sprintf(
            '%s%s %s',
            (string) $patientRecord->first_name,
            $middleInitial,
            (string) $patientRecord->last_name,
        ));
    }

    private function displayStatus(string $status): string
    {
        return match (mb_strtolower(trim($status))) {
            'confirmed' => 'Approved',
            default => ucfirst(mb_strtolower(trim($status))),
        };
    }

    private function fallbackServiceType(int $serviceId): string
    {
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
}
