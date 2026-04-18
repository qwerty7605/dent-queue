<?php

namespace Database\Seeders;

use App\Models\Appointment;
use App\Models\Report;
use Database\Seeders\Concerns\InteractsWithBulkSeedData;
use Illuminate\Database\Seeder;
use Illuminate\Support\Carbon;

class BulkReportSeeder extends Seeder
{
    use InteractsWithBulkSeedData;

    /**
     * @var array<int, string>
     */
    private array $reportTypes = [
        'appointment_summary',
        'treatment_outcome',
        'follow_up_review',
        'queue_snapshot',
        'status_audit',
    ];

    public function run(): void
    {
        $target = max(0, (int) $this->bulkSeedConfig('reports', 700));

        if ($target === 0) {
            return;
        }

        $appointments = Appointment::query()
            ->with(['patient', 'queue', 'service'])
            ->where('notes', 'like', $this->bulkSeedMarker() . '%')
            ->get();

        if ($appointments->isEmpty()) {
            return;
        }

        $created = 0;
        $cursor = 0;

        while ($created < $target) {
            /** @var Appointment $appointment */
            $appointment = $appointments[$cursor % $appointments->count()];
            $reportType = $this->reportTypes[$cursor % count($this->reportTypes)];
            $cursor++;

            $reportDate = Carbon::parse((string) $appointment->appointment_date)
                ->addDays($reportType === 'follow_up_review' ? random_int(1, 10) : 0);

            Report::query()->create([
                'appointment_id' => (int) $appointment->id,
                'report_type' => $reportType,
                'report_date' => $reportDate->toDateString(),
                'data' => $this->reportPayload($appointment, $reportType),
                'created_at' => $reportDate->copy()->setTime(17, random_int(0, 59)),
                'updated_at' => $reportDate->copy()->setTime(17, random_int(0, 59)),
            ]);

            $created++;
        }
    }

    /**
     * @return array<string, mixed>
     */
    private function reportPayload(Appointment $appointment, string $reportType): array
    {
        $patientName = trim(sprintf(
            '%s %s',
            (string) ($appointment->patient?->first_name ?? 'Walk-in'),
            (string) ($appointment->patient?->last_name ?? 'Patient'),
        ));
        $isWalkIn = $appointment->patient?->user_id === null;

        return [
            'report_type' => $reportType,
            'appointment_id' => (int) $appointment->id,
            'patient_id' => (int) $appointment->patient_id,
            'patient_name' => $patientName,
            'service_type' => (string) ($appointment->service?->name ?? 'Unknown Service'),
            'appointment_date' => (string) $appointment->appointment_date,
            'appointment_time' => (string) $appointment->time_slot,
            'status' => (string) $appointment->status,
            'booking_type' => $isWalkIn ? 'Walk-In Booking' : 'Online Booking',
            'queue_number' => (int) ($appointment->queue?->queue_number ?? 0),
            'notes' => (string) ($appointment->notes ?? ''),
            'summary' => sprintf(
                'Bulk seeded %s report for appointment #%d.',
                str_replace('_', ' ', $reportType),
                (int) $appointment->id,
            ),
        ];
    }
}
