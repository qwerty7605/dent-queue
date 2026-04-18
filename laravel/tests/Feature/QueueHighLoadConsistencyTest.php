<?php

namespace Tests\Feature;

use App\Models\Appointment;
use App\Models\PatientRecord;
use App\Models\Queue;
use App\Models\Role;
use App\Models\Service;
use App\Models\User;
use App\Services\QueueService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Str;
use Tests\TestCase;

class QueueHighLoadConsistencyTest extends TestCase
{
    use RefreshDatabase;

    public function test_high_load_queue_sync_keeps_numbers_sequential_and_orders_same_time_records_consistently(): void
    {
        $service = $this->createService('High Load Queue Coverage');
        $date = '2026-04-22';
        $appointments = [];
        $baseCreatedAt = Carbon::parse('2026-04-01 07:30:00', 'UTC');

        for ($index = 0; $index < 50; $index++) {
            $patientRecord = PatientRecord::syncFromUser($this->createUserWithRole('Patient'));
            $timeSlot = Carbon::createFromTime(7, 30)
                ->addMinutes(intdiv($index, 5) * 30)
                ->format('H:i');
            $createdAt = $baseCreatedAt->copy()->addMinutes(intdiv($index, 2));

            $appointments[] = $this->createAppointment(
                (int) $patientRecord->id,
                (int) $service->id,
                $date,
                $timeSlot,
                $index % 3 === 0 ? 'pending' : 'confirmed',
                $createdAt,
            );
        }

        foreach ($appointments as $index => $appointment) {
            $this->createQueue((int) $appointment->id, $date, 50 - $index);
        }

        app(QueueService::class)->syncQueueNumbersForDate($date);

        $expectedAppointments = $appointments;
        usort($expectedAppointments, fn (Appointment $left, Appointment $right): int => $this->compareAppointments($left, $right));

        $queues = Queue::query()
            ->where('queue_date', $date)
            ->orderBy('queue_number')
            ->get();

        $queueNumbers = $queues->pluck('queue_number')->map(
            static fn (mixed $queueNumber): int => (int) $queueNumber,
        )->all();
        $queueAppointmentIds = $queues->pluck('appointment_id')->map(
            static fn (mixed $appointmentId): int => (int) $appointmentId,
        )->all();
        $expectedAppointmentIds = array_map(
            static fn (Appointment $appointment): int => (int) $appointment->id,
            $expectedAppointments,
        );

        $this->assertCount(50, $queues);
        $this->assertSame(range(1, 50), $queueNumbers);
        $this->assertCount(50, array_unique($queueNumbers));
        $this->assertSame($expectedAppointmentIds, $queueAppointmentIds);
    }

    public function test_high_load_queue_sync_resequences_without_gaps_when_multiple_appointments_drop_out(): void
    {
        $service = $this->createService('High Load Gap Removal');
        $date = '2026-04-23';
        $appointments = [];
        $baseCreatedAt = Carbon::parse('2026-04-02 07:30:00', 'UTC');

        for ($index = 0; $index < 50; $index++) {
            $patientRecord = PatientRecord::syncFromUser($this->createUserWithRole('Patient'));
            $timeSlot = Carbon::createFromTime(7, 30)
                ->addMinutes($index * 10)
                ->format('H:i');
            $createdAt = $baseCreatedAt->copy()->addMinutes($index);

            $appointments[] = $this->createAppointment(
                (int) $patientRecord->id,
                (int) $service->id,
                $date,
                $timeSlot,
                $index % 2 === 0 ? 'confirmed' : 'completed',
                $createdAt,
            );
        }

        foreach ($appointments as $index => $appointment) {
            $this->createQueue((int) $appointment->id, $date, $index + 1);
        }

        foreach ([4, 11, 19, 28, 41] as $removedIndex) {
            $appointments[$removedIndex]->forceFill([
                'status' => 'cancelled',
                'deleted_at' => Carbon::parse('2026-04-10 08:00:00', 'UTC'),
            ])->saveQuietly();
        }

        app(QueueService::class)->syncQueueNumbersForDate($date);

        $expectedAppointments = array_values(array_filter(
            $appointments,
            static fn (Appointment $appointment): bool => $appointment->deleted_at === null,
        ));
        usort($expectedAppointments, fn (Appointment $left, Appointment $right): int => $this->compareAppointments($left, $right));

        $queues = Queue::query()
            ->where('queue_date', $date)
            ->orderBy('queue_number')
            ->get();

        $queueNumbers = $queues->pluck('queue_number')->map(
            static fn (mixed $queueNumber): int => (int) $queueNumber,
        )->all();
        $queueAppointmentIds = $queues->pluck('appointment_id')->map(
            static fn (mixed $appointmentId): int => (int) $appointmentId,
        )->all();
        $expectedAppointmentIds = array_map(
            static fn (Appointment $appointment): int => (int) $appointment->id,
            $expectedAppointments,
        );

        $this->assertCount(45, $queues);
        $this->assertSame(range(1, 45), $queueNumbers);
        $this->assertCount(45, array_unique($queueNumbers));
        $this->assertSame($expectedAppointmentIds, $queueAppointmentIds);
    }

    private function compareAppointments(Appointment $left, Appointment $right): int
    {
        $timeComparison = strcmp((string) $left->time_slot, (string) $right->time_slot);
        if ($timeComparison !== 0) {
            return $timeComparison;
        }

        $leftCreatedAt = $left->created_at?->getTimestamp() ?? 0;
        $rightCreatedAt = $right->created_at?->getTimestamp() ?? 0;
        $createdAtComparison = $leftCreatedAt <=> $rightCreatedAt;
        if ($createdAtComparison !== 0) {
            return $createdAtComparison;
        }

        return (int) $left->id <=> (int) $right->id;
    }

    private function createAppointment(
        int $patientRecordId,
        int $serviceId,
        string $date,
        string $timeSlot,
        string $status,
        Carbon $createdAt,
    ): Appointment {
        $appointment = Appointment::query()->create([
            'patient_id' => $patientRecordId,
            'service_id' => $serviceId,
            'appointment_date' => $date,
            'time_slot' => $timeSlot,
            'status' => $status,
        ]);

        $appointment->forceFill([
            'created_at' => $createdAt->toDateTimeString(),
            'updated_at' => $createdAt->toDateTimeString(),
        ])->saveQuietly();

        return $appointment->fresh();
    }

    private function createQueue(int $appointmentId, string $date, int $queueNumber): Queue
    {
        return Queue::query()->create([
            'appointment_id' => $appointmentId,
            'queue_date' => $date,
            'queue_number' => $queueNumber,
            'is_called' => false,
        ]);
    }

    private function createService(string $name): Service
    {
        return Service::query()->create([
            'name' => $name,
            'description' => 'Queue high-load consistency test service.',
            'is_active' => true,
        ]);
    }

    private function createUserWithRole(string $roleName): User
    {
        $role = Role::query()->firstOrCreate(['name' => $roleName]);
        $suffix = Str::lower($roleName) . '_' . Str::lower(Str::random(8));

        return User::query()->create([
            'first_name' => $roleName,
            'middle_name' => null,
            'last_name' => 'User',
            'username' => $suffix,
            'email' => $suffix . '@example.com',
            'password' => Hash::make('password123'),
            'phone_number' => '09123456789',
            'location' => 'Test City',
            'gender' => 'other',
            'role_id' => $role->id,
            'is_active' => true,
        ]);
    }
}
