<?php
use App\Models\Appointment;
use App\Models\PatientRecord;
use App\Models\Service;
use App\Services\AppointmentService;
use Carbon\Carbon;

$service = app(AppointmentService::class);
$patient = PatientRecord::first();
$serviceModel = Service::first();

if (!$patient || !$serviceModel) {
    echo "Missing patient or service. Cannot test.\n";
    exit;
}

$date = Carbon::now()->addDays(5)->toDateString();
$time = '02:00 PM - 03:00 PM';

// 1. Create
$appointment = Appointment::create([
    'patient_id' => $patient->id,
    'service_id' => $serviceModel->id,
    'appointment_date' => $date,
    'time_slot' => $time,
    'status' => 'pending',
]);
echo "Created Appointment ID: {$appointment->id}\n";

// 2. Cancel
$appointment = $service->cancelByPatient($appointment, $patient->id);
echo "Cancelled! Trashed: " . ($appointment->trashed() ? 'YES' : 'NO') . " Status: {$appointment->status}\n";

// 3. Restore
try {
    $restored = $service->restoreAppointment($appointment);
    echo "Restored successfully!\n";
    echo "New Status: {$restored->status}\n";
    echo "Trashed: " . ($restored->trashed() ? 'YES' : 'NO') . "\n";
} catch (\Exception $e) {
    echo "Failed to restore: " . $e->getMessage() . "\n";
}

// Clean up
// Force delete to leave DB clean
$restored->forceDelete();
echo "Cleaned up.\n";
