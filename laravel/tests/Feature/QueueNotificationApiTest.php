<?php

namespace Tests\Feature;

use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;
use App\Models\Appointment;
use App\Models\PatientRecord;
use Illuminate\Support\Str;
use App\Models\User;
use App\Models\Service;
use App\Models\PatientNotification;
use App\Services\QueueService;
use Carbon\Carbon;
use Illuminate\Support\Facades\Hash;
use App\Models\Role;

class QueueNotificationApiTest extends TestCase
{
    use RefreshDatabase;

    private function createPatient(): PatientRecord
    {
        $role = Role::firstOrCreate(['name' => 'Patient']);
        $user = User::create([
            'first_name' => 'Patient',
            'last_name' => 'User',
            'username' => 'pat_' . Str::random(8),
            'email' => 'pat_' . Str::random(8) . '@example.com',
            'password' => Hash::make('password123'),
            'role_id' => $role->id,
            'gender' => 'other',
            'location' => 'Test City',
            'phone_number' => '09123456789',
        ]);

        return PatientRecord::syncFromUser($user);
    }

    private function createService(): Service
    {
        return Service::create([
            'name' => 'Dental Checkup',
            'description' => 'Test service',
            'is_active' => true,
        ]);
    }

    public function test_it_generates_queue_notifications_when_calling_next_patient()
    {
        $service = $this->createService();
        $patient1 = $this->createPatient();
        $patient2 = $this->createPatient();

        $today = Carbon::today()->toDateString();

        $appointment1 = Appointment::create([
            'patient_id' => $patient1->id,
            'service_id' => $service->id,
            'appointment_date' => $today,
            'status' => 'confirmed',
            'time_slot' => '09:00:00',
        ]);

        $appointment2 = Appointment::create([
            'patient_id' => $patient2->id,
            'service_id' => $service->id,
            'appointment_date' => $today,
            'status' => 'confirmed',
            'time_slot' => '10:00:00',
        ]);

        $queueService = app(QueueService::class);
        $queueService->generateQueueNumber((int) $appointment1->id);
        $queueService->generateQueueNumber((int) $appointment2->id);

        $this->assertDatabaseCount('patient_notifications', 0);

        // Call Next (Calls appointment 1)
        $queueService->callNext($today);

        // verify Patient 1 got "Now serving"
        $this->assertDatabaseHas('patient_notifications', [
            'patient_id' => $patient1->id,
            'appointment_id' => $appointment1->id,
            'type' => 'queue_now_serving',
        ]);

        // verify Patient 2 got "Next up"
        $this->assertDatabaseHas('patient_notifications', [
            'patient_id' => $patient2->id,
            'appointment_id' => $appointment2->id,
            'type' => 'queue_next_up',
        ]);

        $appointment1->update(['status' => 'completed']);

        // Call Next again (Calls appointment 2)
        $queueService->callNext($today);

        // verify Patient 2 got "Now Serving"
        $this->assertDatabaseHas('patient_notifications', [
            'patient_id' => $patient2->id,
            'appointment_id' => $appointment2->id,
            'type' => 'queue_now_serving',
        ]);
        
        // Total notifications: 1 for pt1 (now serving), 2 for pt2 (next up -> now serving).
        $this->assertDatabaseCount('patient_notifications', 3);
    }

    public function test_it_prevents_duplicate_queue_notifications()
    {
        $service = $this->createService();
        $patient1 = $this->createPatient();
        $today = Carbon::today()->toDateString();
        
        $appointment1 = Appointment::create([
            'patient_id' => $patient1->id,
            'service_id' => $service->id,
            'appointment_date' => $today,
            'status' => 'confirmed',
            'time_slot' => '09:00:00',
        ]);
        
        $queueService = app(QueueService::class);
        $queueService->generateQueueNumber((int) $appointment1->id);

        // 1. Call Next
        $queueService->callNext($today);
        $this->assertDatabaseCount('patient_notifications', 1);

        // 2. Calling next again before completing the current patient should be rejected
        try {
            $queueService->callNext($today);
            $this->fail('Expected queue progression to be blocked while the current patient is not yet completed.');
        } catch (\Illuminate\Validation\ValidationException $exception) {
            $this->assertSame(
                'The current called appointment must be completed before calling the next patient.',
                $exception->errors()['queue'][0] ?? null,
            );
        }
        $this->assertDatabaseCount('patient_notifications', 1);
        
        // 3. Simulating concurrent invocation using firstOrCreate signature exactly matches the implementation strategy
        PatientNotification::firstOrCreate([
            'patient_id' => $appointment1->patient_id,
            'appointment_id' => $appointment1->id,
            'type' => 'queue_now_serving',
        ], [
            'title' => 'Queue Update',
            'message' => 'Now serving your queue number: 1. Please proceed to the clinic.',
        ]);

        $this->assertDatabaseCount('patient_notifications', 1);
    }
}
