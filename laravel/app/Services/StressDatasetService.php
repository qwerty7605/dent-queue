<?php

namespace App\Services;

use App\Models\Appointment;
use App\Models\Report;
use App\Models\Role;
use App\Models\Service;
use App\Models\User;
use Illuminate\Support\Carbon;
use Illuminate\Support\Collection;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;
use Illuminate\Validation\ValidationException;

class StressDatasetService
{
    public const DEFAULT_PATIENT_POOL_SIZE = 240;
    public const DEFAULT_SIMULATION_DAYS = 12;
    public const DEFAULT_BOOKINGS_PER_DAY = 42;
    public const DEFAULT_OVERLAP_ATTEMPTS = 180;
    public const DEFAULT_REPORT_COUNT = 200000;
    public const DEFAULT_REPORT_CHUNK_SIZE = 2000;

    private const DEFAULT_OPEN_TIME = '07:30';
    private const DEFAULT_CLOSE_TIME = '18:00';
    private const DEFAULT_WORKING_DAYS = [
        'Monday',
        'Tuesday',
        'Wednesday',
        'Thursday',
        'Friday',
        'Saturday',
    ];
    private const STRESS_APPOINTMENT_NOTE_PREFIX = '[stress-booking]';
    private const STRESS_REPORT_TYPE_PREFIX = 'stress:';
    private const STRESS_PASSWORD = 'password123';
    private const REPORT_TYPES = [
        'stress:clinical-summary',
        'stress:follow-up-note',
        'stress:treatment-plan',
        'stress:xray-review',
        'stress:post-procedure-check',
    ];
    private const WEEK_DAYS = [
        'Sunday',
        'Monday',
        'Tuesday',
        'Wednesday',
        'Thursday',
        'Friday',
        'Saturday',
    ];

    public function __construct(
        protected AppointmentService $appointmentService,
        protected ClinicSettingService $clinicSettingService,
    )
    {
    }

    public function seedBookingSimulation(
        int $patientPoolSize = self::DEFAULT_PATIENT_POOL_SIZE,
        int $simulationDays = self::DEFAULT_SIMULATION_DAYS,
        int $bookingsPerDay = self::DEFAULT_BOOKINGS_PER_DAY,
        int $overlapAttempts = self::DEFAULT_OVERLAP_ATTEMPTS,
    ): array {
        $this->assertBookingSimulationOptions($patientPoolSize, $simulationDays, $bookingsPerDay, $overlapAttempts);

        $patientRoleId = $this->resolvePatientRoleId();
        $serviceIds = $this->resolveActiveServiceIds();

        $this->clearExistingStressAppointments();

        $patients = $this->ensureStressPatients($patientRoleId, $patientPoolSize);
        $clinicSchedule = $this->resolveClinicSchedule();
        $simulationDates = $this->resolveSimulationDates($simulationDays, $clinicSchedule['working_days']);
        $primarySlots = $this->buildSimulationTimeSlots(
            $bookingsPerDay,
            $clinicSchedule['opening_time'],
            $clinicSchedule['closing_time'],
        );
        $patientDateConflictSlot = $this->resolvePatientDateConflictSlot(
            $primarySlots,
            $clinicSchedule['opening_time'],
            $clinicSchedule['closing_time'],
        );
        $patientsByDate = [];
        $createdAppointmentIds = [];

        foreach ($simulationDates as $dateIndex => $simulationDate) {
            $patientsByDate[$simulationDate] = $this->rotatePatients($patients, $dateIndex);

            for ($slotIndex = 0; $slotIndex < $bookingsPerDay; $slotIndex++) {
                /** @var User $patient */
                $patient = $patientsByDate[$simulationDate][$slotIndex];
                $serviceId = $serviceIds[($dateIndex + $slotIndex) % count($serviceIds)];
                $status = ($dateIndex + $slotIndex) % 3 === 0 ? 'pending' : 'approved';

                $appointment = $this->appointmentService->createAppointment([
                    'patient_id' => (int) $patient->patientRecord->id,
                    'service_id' => $serviceId,
                    'appointment_date' => $simulationDate,
                    'time_slot' => $primarySlots[$slotIndex],
                    'status' => $status,
                    'notes' => sprintf(
                        '%s Seeded user simulation for %s slot %s.',
                        self::STRESS_APPOINTMENT_NOTE_PREFIX,
                        $simulationDate,
                        $primarySlots[$slotIndex],
                    ),
                ]);

                $createdAppointmentIds[] = (int) $appointment->id;
            }
        }

        $conflictSummary = $this->simulateConflicts(
            $simulationDates,
            $primarySlots,
            $patientsByDate,
            $serviceIds,
            $bookingsPerDay,
            $overlapAttempts,
            $patientDateConflictSlot,
        );

        $statusBreakdown = $this->applyStatusDistribution($createdAppointmentIds);

        return [
            'patients_seeded' => $patients->count(),
            'dates_simulated' => count($simulationDates),
            'bookings_per_day' => $bookingsPerDay,
            'bookings_created' => count($createdAppointmentIds),
            'time_slot_conflicts_prevented' => $conflictSummary['time_slot_conflicts_prevented'],
            'patient_date_conflicts_prevented' => $conflictSummary['patient_date_conflicts_prevented'],
            'appointment_ids' => $createdAppointmentIds,
            'status_breakdown' => $statusBreakdown,
        ];
    }

    public function seedReportDataset(
        int $targetReportCount = self::DEFAULT_REPORT_COUNT,
        int $chunkSize = self::DEFAULT_REPORT_CHUNK_SIZE,
        ?array $appointmentIds = null,
    ): array {
        if ($targetReportCount < 1) {
            throw new \InvalidArgumentException('Target report count must be at least 1.');
        }

        if ($chunkSize < 1) {
            throw new \InvalidArgumentException('Report chunk size must be at least 1.');
        }

        $this->clearExistingStressReports();

        $appointments = $this->resolveStressReportAppointments($appointmentIds);

        if ($appointments->isEmpty()) {
            throw new \RuntimeException('No stress-test appointments are available for report generation.');
        }

        $now = Carbon::now();
        $inserted = 0;
        $batch = [];

        while ($inserted < $targetReportCount) {
            $appointment = $appointments[$inserted % $appointments->count()];
            $sequence = $inserted + 1;

            $batch[] = [
                'appointment_id' => (int) $appointment->id,
                'report_type' => self::REPORT_TYPES[$inserted % count(self::REPORT_TYPES)],
                'report_date' => Carbon::parse((string) $appointment->appointment_date)
                    ->addDays($inserted % 5)
                    ->toDateString(),
                'data' => json_encode([
                    'source' => 'stress_dataset',
                    'sequence' => $sequence,
                    'appointment_status' => (string) $appointment->status,
                    'summary' => sprintf('Stress-generated report row %d.', $sequence),
                    'risk_score' => ($sequence % 5) + 1,
                ], JSON_THROW_ON_ERROR),
                'created_at' => $now,
                'updated_at' => $now,
            ];

            $inserted++;

            if (count($batch) < $chunkSize && $inserted < $targetReportCount) {
                continue;
            }

            DB::table('reports')->insert($batch);
            $batch = [];
        }

        return [
            'reports_created' => $targetReportCount,
            'appointments_linked' => $appointments->count(),
            'chunk_size' => $chunkSize,
        ];
    }

    public function clearExistingStressAppointments(): void
    {
        Appointment::withTrashed()
            ->where('notes', 'like', self::STRESS_APPOINTMENT_NOTE_PREFIX . '%')
            ->get()
            ->each(function (Appointment $appointment): void {
                $appointment->forceDelete();
            });
    }

    public function clearExistingStressReports(): void
    {
        Report::query()
            ->where('report_type', 'like', self::STRESS_REPORT_TYPE_PREFIX . '%')
            ->delete();
    }

    private function assertBookingSimulationOptions(
        int $patientPoolSize,
        int $simulationDays,
        int $bookingsPerDay,
        int $overlapAttempts,
    ): void {
        if ($patientPoolSize < 2) {
            throw new \InvalidArgumentException('Patient pool size must be at least 2.');
        }

        if ($simulationDays < 1) {
            throw new \InvalidArgumentException('Simulation days must be at least 1.');
        }

        if ($bookingsPerDay < 1 || $bookingsPerDay > 50) {
            throw new \InvalidArgumentException('Bookings per day must be between 1 and 50.');
        }

        if ($patientPoolSize <= $bookingsPerDay) {
            throw new \InvalidArgumentException('Patient pool size must exceed bookings per day to simulate overlaps safely.');
        }

        if ($overlapAttempts < 0) {
            throw new \InvalidArgumentException('Overlap attempts cannot be negative.');
        }
    }

    private function resolvePatientRoleId(): int
    {
        $patientRoleId = Role::query()
            ->whereRaw('LOWER(name) = ?', ['patient'])
            ->value('id');

        if ($patientRoleId === null) {
            throw new \RuntimeException('Patient role not found. Run RoleSeeder first.');
        }

        return (int) $patientRoleId;
    }

    /**
     * @return array<int, int>
     */
    private function resolveActiveServiceIds(): array
    {
        $serviceIds = Service::query()
            ->where('is_active', true)
            ->orderBy('id')
            ->pluck('id')
            ->map(static fn (mixed $id): int => (int) $id)
            ->all();

        if ($serviceIds === []) {
            throw new \RuntimeException('No active services found. Run ServiceSeeder first.');
        }

        return $serviceIds;
    }

    /**
     * @return Collection<int, User>
     */
    private function ensureStressPatients(int $patientRoleId, int $patientPoolSize): Collection
    {
        $patients = new Collection();
        $password = Hash::make(self::STRESS_PASSWORD);

        for ($index = 1; $index <= $patientPoolSize; $index++) {
            $identifier = str_pad((string) $index, 4, '0', STR_PAD_LEFT);

            $patient = User::query()->updateOrCreate(
                ['email' => sprintf('stress.patient.%s@example.test', $identifier)],
                [
                    'first_name' => 'Stress',
                    'middle_name' => null,
                    'last_name' => sprintf('Patient %s', $identifier),
                    'username' => sprintf('stress_patient_%s', $identifier),
                    'password' => $password,
                    'phone_number' => '09' . str_pad((string) $index, 9, '0', STR_PAD_LEFT),
                    'location' => 'Seeded Simulation City',
                    'gender' => $index % 2 === 0 ? 'female' : 'male',
                    'role_id' => $patientRoleId,
                    'is_active' => true,
                ],
            );

            $patient->loadMissing('patientRecord');
            $patients->push($patient);
        }

        return $patients;
    }

    /**
     * @return array<int, string>
     */
    private function resolveSimulationDates(int $simulationDays, array $workingDays): array
    {
        $dates = [];
        $cursor = Carbon::today((string) config('app.timezone', 'UTC'));

        while (count($dates) < $simulationDays) {
            if (in_array($cursor->englishDayOfWeek, $workingDays, true)) {
                $dates[] = $cursor->toDateString();
            }

            $cursor = $cursor->copy()->addDay();
        }

        return $dates;
    }

    /**
     * @return array<int, string>
     */
    private function buildSimulationTimeSlots(
        int $bookingsPerDay,
        string $openingTime,
        string $closingTime,
    ): array
    {
        $slots = [];
        $current = Carbon::createFromFormat('H:i', $openingTime);
        $closing = Carbon::createFromFormat('H:i', $closingTime);
        $totalMinutes = $current->diffInMinutes($closing);
        $stepMinutes = max(1, (int) floor($totalMinutes / max($bookingsPerDay - 1, 1)));

        while (count($slots) < $bookingsPerDay) {
            $slots[] = $current->format('H:i');
            $current = $current->copy()->addMinutes($stepMinutes);
        }

        return $slots;
    }

    /**
     * @param  Collection<int, User>  $patients
     * @return array<int, User>
     */
    private function rotatePatients(Collection $patients, int $offset): array
    {
        $count = $patients->count();
        $rotated = [];

        for ($index = 0; $index < $count; $index++) {
            $rotated[] = $patients[($index + $offset) % $count];
        }

        return $rotated;
    }

    /**
     * @param  array<int, string>  $simulationDates
     * @param  array<int, string>  $primarySlots
     * @param  array<string, array<int, User>>  $patientsByDate
     * @param  array<int, int>  $serviceIds
     * @return array{time_slot_conflicts_prevented: int, patient_date_conflicts_prevented: int}
     */
    private function simulateConflicts(
        array $simulationDates,
        array $primarySlots,
        array $patientsByDate,
        array $serviceIds,
        int $bookingsPerDay,
        int $overlapAttempts,
        string $patientDateConflictSlot,
    ): array {
        $timeSlotConflictsPrevented = 0;
        $patientDateConflictsPrevented = 0;

        for ($attempt = 0; $attempt < $overlapAttempts; $attempt++) {
            $dateIndex = $attempt % count($simulationDates);
            $simulationDate = $simulationDates[$dateIndex];
            $patients = $patientsByDate[$simulationDate];
            $serviceId = $serviceIds[$attempt % count($serviceIds)];
            $isTimeSlotProbe = $attempt % 2 === 0;

            if ($isTimeSlotProbe) {
                $patientOffset = $bookingsPerDay + ($attempt % (count($patients) - $bookingsPerDay));
                $patient = $patients[$patientOffset];
                $timeSlot = $primarySlots[$attempt % count($primarySlots)];
                $expectedField = 'time_slot';
            } else {
                $patient = $patients[$attempt % $bookingsPerDay];
                $timeSlot = $patientDateConflictSlot;
                $expectedField = 'appointment_date';
            }

            try {
                $unexpectedAppointment = $this->appointmentService->createAppointment([
                    'patient_id' => (int) $patient->patientRecord->id,
                    'service_id' => $serviceId,
                    'appointment_date' => $simulationDate,
                    'time_slot' => $timeSlot,
                    'status' => 'pending',
                    'notes' => sprintf(
                        '%s Conflict probe for %s at %s.',
                        self::STRESS_APPOINTMENT_NOTE_PREFIX,
                        $simulationDate,
                        $timeSlot,
                    ),
                ]);

                $unexpectedAppointment->forceDelete();

                throw new \RuntimeException(sprintf(
                    'Booking conflict probe unexpectedly succeeded for %s on %s at %s.',
                    $expectedField,
                    $simulationDate,
                    $timeSlot,
                ));
            }
            catch (ValidationException $exception) {
                $errors = $exception->errors();

                if (!array_key_exists($expectedField, $errors)) {
                    throw $exception;
                }

                if ($expectedField === 'time_slot') {
                    $timeSlotConflictsPrevented++;
                    continue;
                }

                $patientDateConflictsPrevented++;
            }
        }

        return [
            'time_slot_conflicts_prevented' => $timeSlotConflictsPrevented,
            'patient_date_conflicts_prevented' => $patientDateConflictsPrevented,
        ];
    }

    /**
     * @param  array<int, int>  $appointmentIds
     * @return array<string, int>
     */
    private function applyStatusDistribution(array $appointmentIds): array
    {
        $actorId = (int) User::query()->value('id');

        Appointment::query()
            ->whereIn('id', $appointmentIds)
            ->orderBy('appointment_date')
            ->orderBy('time_slot')
            ->get()
            ->each(function (Appointment $appointment, int $index) use ($actorId): void {
                $position = $index + 1;
                $currentStatus = (string) $appointment->status;

                if ($position % 11 === 0 && $currentStatus === 'pending') {
                    $this->appointmentService->updateStatus($appointment, 'cancelled', $actorId);
                    return;
                }

                if ($position % 7 === 0 && $currentStatus === 'confirmed') {
                    $this->appointmentService->updateStatus($appointment, 'completed', $actorId);
                }
            });

        return Appointment::withTrashed()
            ->whereIn('id', $appointmentIds)
            ->selectRaw('status, COUNT(*) as aggregate_count')
            ->groupBy('status')
            ->pluck('aggregate_count', 'status')
            ->map(static fn (mixed $count): int => (int) $count)
            ->all();
    }

    /**
     * @param  array<int, int>|null  $appointmentIds
     * @return Collection<int, Appointment>
     */
    private function resolveStressReportAppointments(?array $appointmentIds): Collection
    {
        $query = Appointment::withTrashed()
            ->where('notes', 'like', self::STRESS_APPOINTMENT_NOTE_PREFIX . '%')
            ->where('status', '!=', 'cancelled')
            ->orderBy('id');

        if ($appointmentIds !== null) {
            $query->whereIn('id', $appointmentIds);
        }

        return $query->get(['id', 'appointment_date', 'status']);
    }

    /**
     * @return array{opening_time: string, closing_time: string, working_days: array<int, string>}
     */
    private function resolveClinicSchedule(): array
    {
        $settings = $this->clinicSettingService->getCurrentSettings();
        $openingTime = $this->normalizeScheduleTime($settings['opening_time'] ?? null) ?? self::DEFAULT_OPEN_TIME;
        $closingTime = $this->normalizeScheduleTime($settings['closing_time'] ?? null) ?? self::DEFAULT_CLOSE_TIME;

        if (!$this->hasValidTimeRange($openingTime, $closingTime)) {
            $openingTime = self::DEFAULT_OPEN_TIME;
            $closingTime = self::DEFAULT_CLOSE_TIME;
        }

        $workingDays = $this->normalizeWorkingDays($settings['working_days'] ?? null);

        if ($workingDays === []) {
            $workingDays = self::DEFAULT_WORKING_DAYS;
        }

        return [
            'opening_time' => $openingTime,
            'closing_time' => $closingTime,
            'working_days' => $workingDays,
        ];
    }

    private function resolvePatientDateConflictSlot(
        array $primarySlots,
        string $openingTime,
        string $closingTime,
    ): string {
        $opening = Carbon::createFromFormat('H:i', $openingTime);
        $candidate = Carbon::createFromFormat('H:i', $closingTime)->subMinute();

        while ($candidate->greaterThanOrEqualTo($opening)) {
            $timeSlot = $candidate->format('H:i');

            if (!in_array($timeSlot, $primarySlots, true)) {
                return $timeSlot;
            }

            $candidate = $candidate->copy()->subMinute();
        }

        throw new \RuntimeException('Unable to resolve a spare conflict-probe time slot within clinic hours.');
    }

    private function normalizeScheduleTime(mixed $value): ?string
    {
        if ($value === null || trim((string) $value) === '') {
            return null;
        }

        foreach (['H:i', 'H:i:s', 'g:i A', 'g:i a', 'h:i A', 'h:i a'] as $format) {
            try {
                return Carbon::createFromFormat($format, trim((string) $value))->format('H:i');
            }
            catch (\Throwable) {
                continue;
            }
        }

        return null;
    }

    private function hasValidTimeRange(string $openingTime, string $closingTime): bool
    {
        try {
            $opening = Carbon::createFromFormat('H:i', $openingTime);
            $closing = Carbon::createFromFormat('H:i', $closingTime);

            return $closing->greaterThan($opening);
        }
        catch (\Throwable) {
            return false;
        }
    }

    /**
     * @return array<int, string>
     */
    private function normalizeWorkingDays(mixed $workingDays): array
    {
        if (!is_array($workingDays)) {
            return [];
        }

        $selectedLookup = [];

        foreach ($workingDays as $workingDay) {
            $selectedLookup[mb_strtolower(trim((string) $workingDay))] = true;
        }

        $normalized = [];

        foreach (self::WEEK_DAYS as $weekDay) {
            if (isset($selectedLookup[mb_strtolower($weekDay)])) {
                $normalized[] = $weekDay;
            }
        }

        return $normalized;
    }
}
