<?php

namespace Database\Seeders;

use App\Models\Appointment;
use App\Models\PatientRecord;
use App\Models\Service;
use Database\Seeders\Concerns\InteractsWithBulkSeedData;
use Illuminate\Database\Eloquent\Collection;
use Illuminate\Database\Seeder;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;

class BulkAppointmentSeeder extends Seeder
{
    use InteractsWithBulkSeedData;

    /**
     * @var array<int, string>
     */
    private array $walkInFirstNames = [
        'Amelia',
        'Benjamin',
        'Camila',
        'Daniel',
        'Elena',
        'Francis',
        'Gabriela',
        'Harold',
        'Iris',
        'Julian',
        'Katrina',
        'Leonardo',
        'Marielle',
        'Nathaniel',
        'Ophelia',
        'Patrick',
        'Rosalie',
        'Samuel',
        'Therese',
        'Vincent',
    ];

    /**
     * @var array<int, string>
     */
    private array $walkInMiddleNames = [
        'Abad',
        'Belle',
        'Claire',
        'Domingo',
        'Elaine',
        'Flores',
        'Grace',
        'Herrera',
        'Isabel',
        'Juliet',
    ];

    /**
     * @var array<int, string>
     */
    private array $walkInLastNames = [
        'Alonzo',
        'Bernardo',
        'Castillo',
        'Dominguez',
        'Espinosa',
        'Fernandez',
        'Gutierrez',
        'Herrera',
        'Ibarra',
        'Lorenzo',
        'Marquez',
        'Natividad',
        'Ocampo',
        'Peralta',
        'Ramos',
        'Salazar',
        'Tan',
        'Villanueva',
        'Yap',
        'Zamora',
    ];

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
        'Doctor unavailable; patient needs schedule coordination.',
        'Patient requested rescheduling after clinic advisory.',
        'Cancelled after patient reported a conflict.',
        'Walk-in triage converted into a clinic queue record.',
        'Post-procedure recovery follow-up.',
        'Recurring family dental care visit.',
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
        $futureDays = max(0, (int) $this->bulkSeedConfig('future_days', 90));
        $requestedCount = max(1, (int) $this->bulkSeedConfig('appointments', 50000));
        $appointmentsPerDay = max(1, (int) $this->bulkSeedConfig('appointments_per_day', 40));
        $maxDailyCapacity = $patients->count() * count($slotOptions);

        if ($appointmentsPerDay > $maxDailyCapacity) {
            throw new \RuntimeException(sprintf(
                'Bulk seed appointments_per_day [%d] exceeds daily capacity [%d] for the available patients and time slots.',
                $appointmentsPerDay,
                $maxDailyCapacity,
            ));
        }

        $remainingAppointments = $requestedCount;

        foreach ($this->appointmentDates($today, $requestedCount, $appointmentsPerDay, $pastDays, $futureDays) as $date) {
            if ($remainingAppointments <= 0) {
                break;
            }

            $createdCount = $this->seedAppointmentsForDate(
                patients: $patients,
                services: $services,
                slotOptions: $slotOptions,
                today: $today,
                date: $date,
                targetCount: min($appointmentsPerDay, $remainingAppointments),
            );

            $remainingAppointments -= $createdCount;
        }

        if ($remainingAppointments > 0) {
            throw new \RuntimeException(sprintf(
                'Bulk appointment seeding stopped early with %d appointments remaining.',
                $remainingAppointments,
            ));
        }

        $this->syncQueuesForBulkAppointments();
    }

    private function deleteExistingBulkAppointments(): void
    {
        DB::table('queues')
            ->whereIn('appointment_id', function ($query): void {
                $query->select('id')
                    ->from('appointments')
                    ->where('notes', 'like', $this->bulkSeedMarker() . '%');
            })
            ->delete();

        DB::table('appointments')
            ->where('notes', 'like', $this->bulkSeedMarker() . '%')
            ->delete();
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
            $firstName = $this->walkInFirstNames[($index - 1) % count($this->walkInFirstNames)];
            $middleName = $index % 3 === 0
                ? null
                : $this->walkInMiddleNames[($index + 1) % count($this->walkInMiddleNames)];
            $lastName = $this->walkInLastNames[($index + 2) % count($this->walkInLastNames)];
            $record = PatientRecord::query()->create([
                'id' => $this->bulkWalkInRecordId($index),
                'patient_id' => $this->bulkWalkInIdentifier($index),
                'user_id' => null,
                'first_name' => $firstName,
                'middle_name' => $middleName,
                'last_name' => $lastName,
                'gender' => ['male', 'female', 'other'][$index % 3],
                'address' => sprintf('%d Dental Avenue, %s', 100 + $index, $this->walkInLastNames[($index + 6) % count($this->walkInLastNames)] . ' City'),
                'contact_number' => sprintf('0944%07d', $index),
                'birthdate' => Carbon::now()->subYears(20 + ($index % 35))->toDateString(),
            ]);

            $records[] = $record;
        }

        return new Collection($records);
    }

    /**
     * @param  Collection<int, PatientRecord>  $patients
     * @param  Collection<int, Service>  $services
     * @param  array<int, string>  $slotOptions
     */
    private function seedAppointmentsForDate(
        Collection $patients,
        Collection $services,
        array $slotOptions,
        Carbon $today,
        string $date,
        int $targetCount,
    ): int {
        $createdCount = 0;
        $usedKeys = [];
        $attempts = 0;
        $maxAttempts = $targetCount * 20;
        $appointmentRows = [];

        while ($createdCount < $targetCount && $attempts < $maxAttempts) {
            $attempts++;

            /** @var PatientRecord $patient */
            $patient = $patients->random();
            /** @var Service $service */
            $service = $services->random();
            $timeSlot = $slotOptions[array_rand($slotOptions)];
            $key = implode('|', [(string) $patient->id, $date, $timeSlot]);

            if (isset($usedKeys[$key])) {
                continue;
            }

            $status = $this->determineStatus($date, $today);
            $createdAt = $this->determineCreatedAt($date, $timeSlot, $today);
            $isWalkIn = $patient->user_id === null;
            $deletedAt = $status === 'cancelled' && random_int(1, 100) <= 65
                ? $createdAt->copy()->addDays(random_int(1, 7))->toDateTimeString()
                : null;

            $appointmentRows[] = [
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
                'created_at' => $createdAt->toDateTimeString(),
                'updated_at' => $createdAt->toDateTimeString(),
                'deleted_at' => $deletedAt,
            ];

            $usedKeys[$key] = true;
            $createdCount++;
        }

        if ($createdCount < $targetCount) {
            throw new \RuntimeException(sprintf(
                'Unable to seed %d appointments for [%s]; created %d after %d attempts.',
                $targetCount,
                $date,
                $createdCount,
                $attempts,
            ));
        }

        DB::table('appointments')->insert($appointmentRows);

        return $createdCount;
    }

    /**
     * @return array<int, string>
     */
    private function appointmentDates(
        Carbon $today,
        int $requestedCount,
        int $appointmentsPerDay,
        int $pastDays,
        int $futureDays,
    ): array {
        $requiredDays = (int) ceil($requestedCount / $appointmentsPerDay);
        $windowWeight = max(0, $pastDays) + max(0, $futureDays);
        $pastCoverage = $requiredDays > 1 && $windowWeight > 0
            ? (int) floor(($requiredDays - 1) * (max(0, $pastDays) / $windowWeight))
            : 0;
        $startDate = $today->copy()->subDays($pastCoverage);
        $dates = [];

        for ($offset = 0; $offset < $requiredDays; $offset++) {
            $dates[] = $startDate->copy()->addDays($offset)->toDateString();
        }

        return $dates;
    }

    private function determineStatus(string $date, Carbon $today): string
    {
        $appointmentDate = Carbon::parse($date, (string) config('app.timezone', 'UTC'));

        if ($appointmentDate->lt($today)) {
            return $this->weightedRandom([
                'completed' => 56,
                'confirmed' => 8,
                'cancelled' => 18,
                'cancelled_by_doctor' => 7,
                'reschedule_required' => 6,
                'pending' => 5,
            ]);
        }

        if ($appointmentDate->equalTo($today)) {
            return $this->weightedRandom([
                'confirmed' => 36,
                'pending' => 32,
                'completed' => 12,
                'cancelled' => 10,
                'cancelled_by_doctor' => 5,
                'reschedule_required' => 5,
            ]);
        }

        return $this->weightedRandom([
            'pending' => 45,
            'confirmed' => 35,
            'cancelled' => 15,
            'cancelled_by_doctor' => 3,
            'reschedule_required' => 2,
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
        DB::table('queues')
            ->whereIn('appointment_id', function ($query): void {
                $query->select('id')
                    ->from('appointments')
                    ->where('notes', 'like', $this->bulkSeedMarker() . '%');
            })
            ->delete();

        $queueRows = [];
        $currentDate = null;
        $queueNumber = 0;
        $now = Carbon::now()->toDateTimeString();
        $existingQueueOffsets = DB::table('queues')
            ->select('queue_date', DB::raw('MAX(queue_number) as max_queue_number'))
            ->groupBy('queue_date')
            ->pluck('max_queue_number', 'queue_date')
            ->map(fn (mixed $queueNumber): int => (int) $queueNumber)
            ->all();

        DB::table('appointments')
            ->select(['id', 'appointment_date', 'status'])
            ->where('notes', 'like', $this->bulkSeedMarker() . '%')
            ->whereNull('deleted_at')
            ->whereIn('status', ['pending', 'confirmed', 'completed'])
            ->orderBy('appointment_date')
            ->orderBy('time_slot')
            ->orderBy('created_at')
            ->orderBy('id')
            ->cursor()
            ->each(function (object $appointment) use (&$queueRows, &$currentDate, &$queueNumber, $existingQueueOffsets, $now): void {
                $appointmentDate = (string) $appointment->appointment_date;

                if ($currentDate !== $appointmentDate) {
                    $currentDate = $appointmentDate;
                    $queueNumber = $existingQueueOffsets[$appointmentDate] ?? 0;
                }

                $queueNumber++;
                $queueRows[] = [
                    'appointment_id' => (int) $appointment->id,
                    'queue_date' => $appointmentDate,
                    'queue_number' => $queueNumber,
                    'is_called' => (string) $appointment->status === 'completed' && random_int(1, 100) <= 60,
                    'created_at' => $now,
                    'updated_at' => $now,
                ];

                if (count($queueRows) >= 5000) {
                    DB::table('queues')->insert($queueRows);
                    $queueRows = [];
                }
            });

        if ($queueRows !== []) {
            DB::table('queues')->insert($queueRows);
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
