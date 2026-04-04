<?php

namespace App\Services;

use App\Models\Appointment;
use App\Support\AppointmentQueueOrder;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Support\Carbon;
use Illuminate\Support\Str;

class ReportService
{
    private const TREND_TYPE_DAILY = 'daily';
    private const TREND_TYPE_WEEKLY = 'weekly';
    private const TREND_TYPE_MONTHLY = 'monthly';
    private const STATUS_PENDING = 'pending';
    private const STATUS_CONFIRMED = 'confirmed';
    private const STATUS_COMPLETED = 'completed';
    private const STATUS_CANCELLED = 'cancelled';
    private const BOOKING_TYPE_ONLINE = 'Online Booking';
    private const BOOKING_TYPE_WALK_IN = 'Walk-In Booking';
    private const SUPPORTED_TREND_TYPES = [
        self::TREND_TYPE_DAILY,
        self::TREND_TYPE_WEEKLY,
        self::TREND_TYPE_MONTHLY,
    ];

    public function createReport(array $data)
    {
        //
    }

    public function getAppointmentReports(int $appointmentId)
    {
        //
    }

    public static function supportedTrendTypes(): array
    {
        return self::SUPPORTED_TREND_TYPES;
    }

    public static function normalizeStatusFilter(?string $status): ?string
    {
        if ($status === null || trim($status) === '') {
            return null;
        }

        return match (self::normalizeFilterToken($status)) {
            self::STATUS_PENDING => self::STATUS_PENDING,
            'approved', self::STATUS_CONFIRMED => self::STATUS_CONFIRMED,
            self::STATUS_COMPLETED => self::STATUS_COMPLETED,
            self::STATUS_CANCELLED, 'canceled' => self::STATUS_CANCELLED,
            default => null,
        };
    }

    public static function normalizeBookingTypeFilter(?string $bookingType): ?string
    {
        if ($bookingType === null || trim($bookingType) === '') {
            return null;
        }

        return match (self::normalizeFilterToken($bookingType)) {
            'online', 'online booking' => self::BOOKING_TYPE_ONLINE,
            'walk in', 'walk in booking' => self::BOOKING_TYPE_WALK_IN,
            default => null,
        };
    }

    public function getReportSummary(array $filters = []): array
    {
        $summary = $this->newFilteredAppointmentsQuery($filters)
            ->selectRaw('COUNT(*) as total_appointments')
            ->selectRaw(sprintf(
                "SUM(CASE WHEN appointments.status = '%s' THEN 1 ELSE 0 END) as pending_count",
                self::STATUS_PENDING,
            ))
            ->selectRaw(sprintf(
                "SUM(CASE WHEN appointments.status = '%s' THEN 1 ELSE 0 END) as approved_count",
                self::STATUS_CONFIRMED,
            ))
            ->selectRaw(sprintf(
                "SUM(CASE WHEN appointments.status = '%s' THEN 1 ELSE 0 END) as completed_count",
                self::STATUS_COMPLETED,
            ))
            ->selectRaw(sprintf(
                "SUM(CASE WHEN appointments.status = '%s' THEN 1 ELSE 0 END) as cancelled_count",
                self::STATUS_CANCELLED,
            ))
            ->first();

        return [
            'total_appointments' => (int) ($summary->total_appointments ?? 0),
            'pending_count' => (int) ($summary->pending_count ?? 0),
            'approved_count' => (int) ($summary->approved_count ?? 0),
            'completed_count' => (int) ($summary->completed_count ?? 0),
            'cancelled_count' => (int) ($summary->cancelled_count ?? 0),
        ];
    }

    public function getStatusDistribution(array $filters = []): array
    {
        $counts = $this->newFilteredAppointmentsQuery($filters)
            ->selectRaw('appointments.status, COUNT(*) as count')
            ->groupBy('appointments.status')
            ->get()
            ->pluck('count', 'status')
            ->all();

        $statuses = [
            self::STATUS_PENDING => self::STATUS_PENDING,
            self::STATUS_CONFIRMED => 'approved',
            self::STATUS_COMPLETED => self::STATUS_COMPLETED,
            self::STATUS_CANCELLED => self::STATUS_CANCELLED,
        ];

        $data = [];
        foreach ($statuses as $dbStatus => $label) {
            $data[] = [
                'status' => $label,
                'count' => (int) ($counts[$dbStatus] ?? 0),
            ];
        }

        return $data;
    }

    public function getAppointmentTrends(string $trendType, array $filters = []): array
    {
        $appointments = $this->newFilteredAppointmentsQuery($filters)
            ->orderBy('appointments.appointment_date')
            ->get(['appointments.appointment_date']);

        return $appointments
            ->groupBy(function ($appointment) use ($trendType): string {
                return $this->formatTrendLabel(
                    Carbon::parse((string) $appointment->appointment_date),
                    $trendType,
                );
            })
            ->sortKeys()
            ->map(function ($group, string $label) use ($trendType): array {
                return [
                    'trend_type' => $trendType,
                    'label' => $label,
                    'count' => $group->count(),
                ];
            })
            ->values()
            ->all();
    }

    public function getDetailedRecords(array $filters = []): array
    {
        $appointments = $this->getDetailedRecordRows($filters);

        return $appointments
            ->map(function ($appointment): array {
                $record = $this->mapDetailedRecord($appointment);

                return [
                    'appointment_id' => $record['appointment_id'],
                    'patient_name' => $record['patient_name'],
                    'service' => $record['service_type'],
                    'service_type' => $record['service_type'],
                    'date' => $record['appointment_date'],
                    'appointment_date' => $record['appointment_date'],
                    'appointment_time' => $record['appointment_time'],
                    'contact' => $record['contact'],
                    'status' => $record['status'],
                    'booking_type' => $record['booking_type'],
                    'queue_number' => $record['queue_number'],
                    'created_at' => $record['created_at'],
                ];
            })
            ->values()
            ->all();
    }

    public function getDetailedRecordsForExport(array $filters = []): array
    {
        return $this->getDetailedRecordRows($filters)
            ->map(function ($appointment): array {
                $record = $this->mapDetailedRecord($appointment);

                return [
                    'appointment_id' => $record['appointment_id'],
                    'patient_name' => $record['patient_name'],
                    'service_type' => $record['service_type'],
                    'appointment_date' => $record['appointment_date'],
                    'appointment_time' => $record['appointment_time'],
                    'status' => $record['status'],
                    'booking_type' => $record['booking_type'],
                    'queue_number' => $record['queue_number'],
                    'created_at' => $record['created_at'],
                ];
            })
            ->values()
            ->all();
    }

    private function getDetailedRecordRows(array $filters)
    {
        return $this->newFilteredAppointmentsQuery($filters)
            ->leftJoin('services', 'services.id', '=', 'appointments.service_id')
            ->leftJoin('queues', 'queues.appointment_id', '=', 'appointments.id')
            ->tap(static fn (Builder $query) => AppointmentQueueOrder::apply($query))
            ->select([
                'appointments.id as appointment_id',
                'patient_records.first_name',
                'patient_records.middle_name',
                'patient_records.last_name',
                'services.name as service_type',
                'appointments.appointment_date',
                'appointments.time_slot',
                'appointments.created_at',
                'patient_records.contact_number as contact',
                'appointments.status',
                'appointments.notes',
                'patient_records.user_id',
                'queues.queue_number',
            ])
            ->get();
    }

    private function mapDetailedRecord(object $appointment): array
    {
        $middleName = $appointment->middle_name !== null && $appointment->middle_name !== ''
            ? ' ' . mb_substr((string) $appointment->middle_name, 0, 1) . '.'
            : '';

        $patientName = trim(sprintf(
            '%s%s %s',
            (string) $appointment->first_name,
            $middleName,
            (string) $appointment->last_name,
        ));

        $bookingType = $this->isWalkInAppointment(
            $appointment->user_id,
            $appointment->notes !== null ? (string) $appointment->notes : null,
        )
            ? self::BOOKING_TYPE_WALK_IN
            : self::BOOKING_TYPE_ONLINE;

        $appointmentDate = Carbon::parse((string) $appointment->appointment_date)->format('Y-m-d');
        $appointmentTime = $this->formatAppointmentTime(
            $appointment->time_slot !== null ? (string) $appointment->time_slot : null,
        );
        $createdAt = $appointment->created_at !== null
            ? Carbon::parse((string) $appointment->created_at)->format('Y-m-d H:i:s')
            : '-';

        return [
            'appointment_id' => (int) $appointment->appointment_id,
            'patient_name' => $patientName,
            'service_type' => $appointment->service_type !== null
                ? (string) $appointment->service_type
                : 'Unknown Service',
            'appointment_date' => $appointmentDate,
            'appointment_time' => $appointmentTime,
            'contact' => (string) $appointment->contact,
            'status' => $this->formatStatusLabel((string) $appointment->status),
            'booking_type' => $bookingType,
            'queue_number' => $appointment->queue_number
                ? str_pad((string) $appointment->queue_number, 2, '0', STR_PAD_LEFT)
                : '-',
            'created_at' => $createdAt,
        ];
    }

    private function newFilteredAppointmentsQuery(array $filters): Builder
    {
        $query = Appointment::withTrashed()
            ->join('patient_records', 'patient_records.id', '=', 'appointments.patient_id');

        if (!empty($filters['start_date'])) {
            $query->whereDate('appointments.appointment_date', '>=', (string) $filters['start_date']);
        }

        if (!empty($filters['end_date'])) {
            $query->whereDate('appointments.appointment_date', '<=', (string) $filters['end_date']);
        }

        if (!empty($filters['status'])) {
            $query->where('appointments.status', (string) $filters['status']);
        }

        if (!empty($filters['booking_type'])) {
            $this->applyBookingTypeFilter($query, (string) $filters['booking_type']);
        }

        return $query;
    }

    private function applyBookingTypeFilter(Builder $query, string $bookingType): void
    {
        if ($bookingType === self::BOOKING_TYPE_WALK_IN) {
            $query->where(function (Builder $builder): void {
                $builder->whereNull('patient_records.user_id')
                    ->orWhereRaw(
                        "LOWER(COALESCE(appointments.notes, '')) LIKE ?",
                        ['%walk-in%'],
                    );
            });

            return;
        }

        if ($bookingType === self::BOOKING_TYPE_ONLINE) {
            $query->whereNotNull('patient_records.user_id')
                ->whereRaw(
                    "LOWER(COALESCE(appointments.notes, '')) NOT LIKE ?",
                    ['%walk-in%'],
                );
        }
    }

    private function isWalkInAppointment(mixed $patientUserId, ?string $notes): bool
    {
        return $patientUserId === null
            || str_contains(Str::lower($notes ?? ''), 'walk-in');
    }

    private function formatStatusLabel(string $status): string
    {
        return $status === self::STATUS_CONFIRMED
            ? 'Approved'
            : ucfirst($status);
    }

    private function formatTrendLabel(Carbon $date, string $trendType): string
    {
        return match ($trendType) {
            self::TREND_TYPE_DAILY => $date->toDateString(),
            self::TREND_TYPE_WEEKLY => sprintf(
                '%s-W%02d',
                $date->format('o'),
                (int) $date->format('W'),
            ),
            self::TREND_TYPE_MONTHLY => $date->format('Y-m'),
            default => throw new \InvalidArgumentException('Unsupported trend type.'),
        };
    }

    private static function normalizeFilterToken(string $value): string
    {
        $normalized = str_replace(['-', '_'], ' ', Str::lower(trim($value)));

        return trim((string) preg_replace('/\s+/', ' ', $normalized));
    }

    private function formatAppointmentTime(?string $timeSlot): string
    {
        if ($timeSlot === null || trim($timeSlot) === '') {
            return '-';
        }

        $normalized = trim($timeSlot);

        foreach (['H:i:s', 'H:i'] as $format) {
            try {
                return Carbon::createFromFormat($format, $normalized)->format('g:i A');
            } catch (\Throwable) {
                continue;
            }
        }

        return $normalized;
    }
}
