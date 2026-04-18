<?php

namespace Database\Seeders;

use App\Models\Appointment;
use App\Models\PatientRecord;
use App\Models\Queue;
use App\Models\Service;
use Database\Seeders\Concerns\InteractsWithBulkSeedData;
use Illuminate\Database\Eloquent\Collection;
use Illuminate\Database\Seeder;
use Illuminate\Support\Carbon;

class BulkAppointmentSeeder extends Seeder
{
    use InteractsWithBulkSeedData;

    /**
     * @var array<int, string>
     */
    private array $noteFragments = [
        'Routine oral health review.',
        'Follow-up for recent discomfort.',
        'Needs treatment plan discussion.',
        'Preferred early clinic slot.',
        'Requested imaging before procedure.',
        'Monitoring post-treatment sensitivity.',
        'Annual preventive visit.',
        'Requested urgent assessment for pain.',
    ];

    public function run(): void
    {
        $this->deleteExistingBulkAppointments();
        $walkInRecords = $this->refreshWalkInRecords();

        $registeredPatients = $this->bulkPatientRecordsQuery()->get();
        $patients = $registeredPatients->concat($walkInRecords)->values();

        if ($patients->isEmpty()) {
            throw new \RuntimeException('No bulk patient records found. Run BulkUserSeeder first.');
        }

        $services = Service::query()
            ->where('is_active', true)
            ->get(['id', 'name']);

        if ($services->isEmpty()) {
            throw new \RuntimeException('No active services found. Run ServiceSeeder first.');
        }

        $slotOptions = $this->appointmentTimeSlots();
        $today = Carbon::today((string) config('app.timezone', 'UTC'));
        $pastDays = max(1, (int) $this->bulkSeedConfig('past_days', 180));
        $futureDays = max(1, (int) $this->bulkSeedConfig('future_days', 90));
        $requestedCount = max(1, (int) $this->bulkSeedConfig('appointments', 900));
        $appointments = [];
        $usedKeys = [];
        $attempts = 0;
        $maxAttempts = $requestedCount * 20;

        while (count($appointments) < $requestedCount && $attempts < $maxAttempts) {
            $attempts++;

            /** @var PatientRecord $patient */
            $patient = $patients->random();
            $service = $services->random();

            $date = $today->copy()
                ->subDays(random_int(0, $pastDays))
                ->addDays(random_int(0, $futureDays))
                ->toDateString();

            $timeSlot = $slotOptions[array_rand($slotOptions)];
            $key = implode('|', [(string) $patient->id, $date, $timeSlot]);

            if (isset($usedKeys[$key])) {
                continue;
            }

            $status = $this->determineStatus($date, $today);
            $createdAt = $this->determineCreatedAt($date, $timeSlot, $today);
            $isWalkIn = $patient->user_id === null;

            $appointment = Appointment::query()->create([
                'patient_id' => (int) $patient->id,
                'service_id' => (int) $service->id,
                'appointment_date' => $date,
                'time_slot' => $timeSlot,
                'status' => $status,
                'notes' => sprintf(
                    '%s [%s] %s',
                    $this->bulkSeedMarker(),
                    $isWalkIn ? 'walk-in' : 'online',
                    $this->noteFragments[array_rand($this->noteFragments)],
                ),
                'created_at' => $createdAt,
                'updated_at' => $createdAt,
            ]);

            if ($status === 'cancelled' && random_int(1, 100) <= 65) {
                $appointment->delete();
            }

            $usedKeys[$key] = true;
            $appointments[] = $appointment->id;
        }

        $this->syncQueuesForBulkAppointments();
    }

    private function deleteExistingBulkAppointments(): void
    {
        $this->bulkAppointmentsQuery()->withTrashed()->get()->each(function (Appointment $appointment): void {
            if ($appointment->trashed()) {
                $appointment->forceDelete();

                return;
            }

            $appointment->delete();
            $appointment->forceDelete();
        });
    }

    /**
     * @return Collection<int, PatientRecord>
     */
    private function refreshWalkInRecords(): Collection
    {
        $this->bulkWalkInRecordsQuery()->get()->each(function (PatientRecord $record): void {
            $record->delete();
            $record->forceDelete();
        });

        $count = max(0, (int) $this->bulkSeedConfig('walk_in_patients', 40));
        $records = [];

        for ($index = 1; $index <= $count; $index++) {
            $firstName = sprintf('WalkIn%03d', $index);
            $record = PatientRecord::query()->create([
                'id' => $this->bulkWalkInRecordId($index),
                'patient_id' => $this->bulkWalkInIdentifier($index),
                'user_id' => null,
                'first_name' => $firstName,
                'middle_name' => $index % 2 === 0 ? 'Bulk' : null,
                'last_name' => 'Guest',
                'gender' => ['male', 'female', 'other'][$index % 3],
                'address' => 'Walk-in Registration Desk',
                'contact_number' => sprintf('0944%07d', $index),
                'birthdate' => Carbon::now()->subYears(20 + ($index % 35))->toDateString(),
            ]);

            $records[] = $record;
        }

        return new Collection($records);
    }

    private function determineStatus(string $date, Carbon $today): string
    {
        $appointmentDate = Carbon::parse($date, (string) config('app.timezone', 'UTC'));

        if ($appointmentDate->lt($today)) {
            return $this->weightedRandom([
                'completed' => 45,
                'confirmed' => 20,
                'cancelled' => 25,
                'pending' => 10,
            ]);
        }

        if ($appointmentDate->equalTo($today)) {
            return $this->weightedRandom([
                'confirmed' => 35,
                'pending' => 35,
                'completed' => 15,
                'cancelled' => 15,
            ]);
        }

        return $this->weightedRandom([
            'pending' => 45,
            'confirmed' => 35,
            'cancelled' => 15,
            'completed' => 5,
        ]);
    }

    private function determineCreatedAt(string $date, string $timeSlot, Carbon $today): Carbon
    {
        $appointmentDateTime = Carbon::parse(
            sprintf('%s %s', $date, $timeSlot),
            (string) config('app.timezone', 'UTC'),
        );

        if ($appointmentDateTime->lessThanOrEqualTo($today->copy()->endOfDay())) {
            return $appointmentDateTime->copy()->subDays(random_int(1, 30))->subMinutes(random_int(0, 720));
        }

        return $appointmentDateTime->copy()->subDays(random_int(2, 45))->subMinutes(random_int(0, 720));
    }

    private function syncQueuesForBulkAppointments(): void
    {
        Queue::query()
            ->whereIn(
                'appointment_id',
                $this->bulkAppointmentsQuery()->withTrashed()->pluck('id'),
            )
            ->delete();

        $dates = $this->bulkAppointmentsQuery()
            ->whereNull('deleted_at')
            ->whereIn('status', ['pending', 'confirmed', 'completed'])
            ->distinct()
            ->orderBy('appointment_date')
            ->pluck('appointment_date');

        foreach ($dates as $date) {
            $appointments = $this->bulkAppointmentsQuery()
                ->whereDate('appointment_date', (string) $date)
                ->whereNull('deleted_at')
                ->whereIn('status', ['pending', 'confirmed', 'completed'])
                ->orderBy('time_slot')
                ->orderBy('created_at')
                ->orderBy('id')
                ->get(['id', 'status']);

            foreach ($appointments as $index => $appointment) {
                Queue::query()->create([
                    'appointment_id' => (int) $appointment->id,
                    'queue_date' => (string) $date,
                    'queue_number' => $index + 1,
                    'is_called' => in_array($appointment->status, ['completed'], true) && random_int(1, 100) <= 60,
                ]);
            }
        }
    }

    /**
     * @param  array<string, int>  $weights
     */
    private function weightedRandom(array $weights): string
    {
        $total = array_sum($weights);
        $pick = random_int(1, max(1, $total));

        foreach ($weights as $value => $weight) {
            $pick -= $weight;

            if ($pick <= 0) {
                return $value;
            }
        }

        return array_key_first($weights) ?? 'pending';
    }
}
