<?php

namespace App\Services;

use App\Models\Appointment;
use App\Models\AuditTrail;
use App\Models\Report;
use App\Support\AppointmentQueueOrder;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Pagination\LengthAwarePaginator;
use Illuminate\Support\Facades\DB;
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
    private const STATUS_CANCELLED_BY_DOCTOR = 'cancelled_by_doctor';
    private const STATUS_RESCHEDULE_REQUIRED = 'reschedule_required';
    private const BOOKING_TYPE_ONLINE = 'Online Booking';
    private const BOOKING_TYPE_WALK_IN = 'Walk-In Booking';
    private const SUPPORTED_TREND_TYPES = [
        self::TREND_TYPE_DAILY,
        self::TREND_TYPE_WEEKLY,
        self::TREND_TYPE_MONTHLY,
    ];

    public function __construct(
        private readonly CentralizedCacheService $cacheService,
    ) {
    }

    public function createReport(array $data)
    {
        return Report::query()->create($data);
    }

    public function getAppointmentReports(int $appointmentId)
    {
        return Report::query()
            ->where('appointment_id', $appointmentId)
            ->orderByDesc('report_date')
            ->orderByDesc('id')
            ->get();
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
            'cancelled by doctor', self::STATUS_CANCELLED_BY_DOCTOR => self::STATUS_CANCELLED_BY_DOCTOR,
            'reschedule required', self::STATUS_RESCHEDULE_REQUIRED => self::STATUS_RESCHEDULE_REQUIRED,
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

    public function getReportSummary(array $filters = [], bool $forceRefresh = false): array
    {
        return $this->cacheService->rememberReportSummary($filters, function () use ($filters): array {
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
                ->selectRaw(sprintf(
                    "SUM(CASE WHEN appointments.status = '%s' THEN 1 ELSE 0 END) as cancelled_by_doctor_count",
                    self::STATUS_CANCELLED_BY_DOCTOR,
                ))
                ->selectRaw(sprintf(
                    "SUM(CASE WHEN appointments.status = '%s' THEN 1 ELSE 0 END) as reschedule_required_count",
                    self::STATUS_RESCHEDULE_REQUIRED,
                ))
                ->first();

            return [
                'total_appointments' => (int) ($summary->total_appointments ?? 0),
                'pending_count' => (int) ($summary->pending_count ?? 0),
                'approved_count' => (int) ($summary->approved_count ?? 0),
                'completed_count' => (int) ($summary->completed_count ?? 0),
                'cancelled_count' => (int) ($summary->cancelled_count ?? 0),
                'cancelled_by_doctor_count' => (int) ($summary->cancelled_by_doctor_count ?? 0),
                'reschedule_required_count' => (int) ($summary->reschedule_required_count ?? 0),
                'total_report_records' => $this->getReportRecordCount($filters),
            ];
        }, $forceRefresh);
    }

    public function getStatusDistribution(array $filters = [], bool $forceRefresh = false): array
    {
        return $this->cacheService->rememberReportStatusDistribution($filters, function () use ($filters): array {
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
                self::STATUS_CANCELLED_BY_DOCTOR => self::STATUS_CANCELLED_BY_DOCTOR,
                self::STATUS_RESCHEDULE_REQUIRED => self::STATUS_RESCHEDULE_REQUIRED,
            ];

            $data = [];
            foreach ($statuses as $dbStatus => $label) {
                $data[] = [
                    'status' => $label,
                    'count' => (int) ($counts[$dbStatus] ?? 0),
                ];
            }

            return $data;
        }, $forceRefresh);
    }

    public function getAppointmentTrends(string $trendType, array $filters = [], bool $forceRefresh = false): array
    {
        return $this->cacheService->rememberReportTrends($trendType, $filters, function () use ($trendType, $filters): array {
            $labelExpression = $this->trendLabelExpression($trendType);

            return $this->newFilteredAppointmentsQuery($filters)
                ->selectRaw($labelExpression . ' as trend_label')
                ->selectRaw('COUNT(*) as aggregate_count')
                ->groupByRaw($labelExpression)
                ->orderByRaw('MIN(appointments.appointment_date)')
                ->get()
                ->map(function (object $row) use ($trendType): array {
                    return [
                        'trend_type' => $trendType,
                        'label' => (string) $row->trend_label,
                        'count' => (int) $row->aggregate_count,
                    ];
                })
                ->values()
                ->all();
        }, $forceRefresh);
    }

    public function getDetailedRecords(array $filters = [], bool $forceRefresh = false): array
    {
        return $this->cacheService->rememberReportDetailedRecords($filters, function () use ($filters): array {
            $appointments = $this->getDetailedRecordRows($filters);

            return $appointments
                ->map(fn ($appointment): array => $this->serializeDetailedRecord($appointment))
                ->values()
                ->all();
        }, $forceRefresh);
    }

    public function getDetailedRecordsPage(array $filters = [], int $page = 1, int $perPage = 25): array
    {
        $paginator = $this->detailedRecordsQuery($filters)->paginate(
            $perPage,
            ['*'],
            'page',
            $page,
        );

        return [
            'data' => $paginator->getCollection()
                ->map(fn ($appointment): array => $this->serializeDetailedRecord($appointment))
                ->values()
                ->all(),
            'meta' => $this->paginationMeta($paginator),
        ];
    }

    public function getDetailedRecordsForExport(array $filters = [], bool $forceRefresh = false): array
    {
        return $this->cacheService->rememberReportExportRecords($filters, function () use ($filters): array {
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
        }, $forceRefresh);
    }

    public function streamDetailedRecordsForExport(array $filters = []): \Generator
    {
        foreach ($this->detailedRecordsQuery($filters)->cursor() as $appointment) {
            $record = $this->mapDetailedRecord($appointment);

            yield [
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
        }
    }

    public function getDetailedRecordsForPdfExport(array $filters = [], int $limit = 1000): array
    {
        return $this->detailedRecordsQuery($filters)
            ->limit($limit)
            ->get()
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
        return $this->detailedRecordsQuery($filters)->get();
    }

    private function detailedRecordsQuery(array $filters): Builder
    {
        $query = $this->newFilteredAppointmentsQuery($filters)
            ->leftJoin('services as legacy_services', 'legacy_services.id', '=', 'appointments.service_id')
            ->leftJoin('queues', 'queues.appointment_id', '=', 'appointments.id')
            ->leftJoin('users as cancelled_by_users', 'cancelled_by_users.id', '=', 'appointments.cancelled_by');

        if (!empty($filters['search'])) {
            $this->applyDetailedRecordSearch($query, (string) $filters['search']);
        }

        return $query
            ->tap(static fn (Builder $query): Builder => AppointmentQueueOrder::apply($query))
            ->select([
                'appointments.id as appointment_id',
                'patient_records.first_name',
                'patient_records.middle_name',
                'patient_records.last_name',
                'appointments.appointment_date',
                'appointments.time_slot',
                'appointments.created_at',
                'patient_records.contact_number as contact',
                'appointments.status',
                'appointments.notes',
                'appointments.cancellation_reason',
                'appointments.cancelled_by',
                'appointments.cancelled_at',
                'cancelled_by_users.first_name as cancelled_by_first_name',
                'cancelled_by_users.last_name as cancelled_by_last_name',
                'patient_records.user_id',
                'queues.queue_number',
            ])
            ->selectRaw($this->serviceNamesSelectExpression() . ' as service_type');
    }

    private function applyDetailedRecordSearch(Builder $query, string $search): void
    {
        $normalized = Str::lower(trim($search));
        if ($normalized === '') {
            return;
        }

        $tokens = preg_split('/\s+/', $normalized) ?: [];
        $tokens = array_values(array_filter(
            $tokens,
            static fn (string $token): bool => $token !== '',
        ));
        if ($tokens === []) {
            return;
        }

        $appointmentIdExpression = $this->textCastExpression('appointments.id');
        $queueNumberExpression = $this->textCastExpression('queues.queue_number');
        $patientNameExpression = $this->patientNameSearchExpression();

        foreach ($tokens as $token) {
            $like = '%' . $token . '%';

            $query->where(function (Builder $builder) use (
                $appointmentIdExpression,
                $like,
                $patientNameExpression,
                $queueNumberExpression,
            ): void {
                $builder
                    ->whereRaw("LOWER($patientNameExpression) LIKE ?", [$like])
                    ->orWhereRaw("LOWER(COALESCE(patient_records.first_name, '')) LIKE ?", [$like])
                    ->orWhereRaw("LOWER(COALESCE(patient_records.middle_name, '')) LIKE ?", [$like])
                    ->orWhereRaw("LOWER(COALESCE(patient_records.last_name, '')) LIKE ?", [$like])
                    ->orWhereRaw("LOWER(COALESCE((" . $this->serviceNamesSubquery() . "), legacy_services.name, '')) LIKE ?", [$like])
                    ->orWhereExists(function ($serviceQuery) use ($like): void {
                        $serviceQuery
                            ->selectRaw('1')
                            ->from('appointment_service')
                            ->join('services as selected_services', 'selected_services.id', '=', 'appointment_service.service_id')
                            ->whereColumn('appointment_service.appointment_id', 'appointments.id')
                            ->whereRaw("LOWER(COALESCE(selected_services.name, '')) LIKE ?", [$like]);
                    })
                    ->orWhereRaw("LOWER(COALESCE(patient_records.contact_number, '')) LIKE ?", [$like])
                    ->orWhereRaw("LOWER(COALESCE($appointmentIdExpression, '')) LIKE ?", [$like])
                    ->orWhereRaw("LOWER(COALESCE($queueNumberExpression, '')) LIKE ?", [$like]);
            });
        }
    }

    private function patientNameSearchExpression(): string
    {
        $driver = DB::connection()->getDriverName();

        if ($driver === 'pgsql' || $driver === 'sqlite') {
            return "COALESCE(patient_records.first_name, '') || ' ' || COALESCE(patient_records.middle_name, '') || ' ' || COALESCE(patient_records.last_name, '')";
        }

        return "CONCAT_WS(' ', patient_records.first_name, patient_records.middle_name, patient_records.last_name)";
    }

    private function textCastExpression(string $column): string
    {
        $driver = DB::connection()->getDriverName();

        return $driver === 'pgsql'
            ? "CAST($column AS TEXT)"
            : "CAST($column AS CHAR)";
    }

    private function serviceNamesSelectExpression(): string
    {
        return "COALESCE((" . $this->serviceNamesSubquery() . "), legacy_services.name)";
    }

    private function serviceNamesSubquery(): string
    {
        $driver = DB::connection()->getDriverName();

        $aggregate = match ($driver) {
            'pgsql' => "STRING_AGG(DISTINCT selected_services.name, ', ' ORDER BY selected_services.name)",
            'sqlite' => "GROUP_CONCAT(DISTINCT selected_services.name)",
            default => "GROUP_CONCAT(DISTINCT selected_services.name ORDER BY selected_services.name SEPARATOR ', ')",
        };

        return "SELECT $aggregate
            FROM appointment_service
            INNER JOIN services selected_services ON selected_services.id = appointment_service.service_id
            WHERE appointment_service.appointment_id = appointments.id";
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
            'cancellation_reason' => $appointment->cancellation_reason,
            'cancelled_by' => $appointment->cancelled_by !== null ? (int) $appointment->cancelled_by : null,
            'cancelled_by_name' => $this->formatCancelledByName($appointment),
            'cancelled_at' => $appointment->cancelled_at !== null
                ? Carbon::parse((string) $appointment->cancelled_at)->toIso8601String()
                : null,
        ];
    }

    private function getReportRecordCount(array $filters): int
    {
        return Report::query()
            ->whereIn(
                'appointment_id',
                $this->newFilteredAppointmentsQuery($filters)->select('appointments.id'),
            )
            ->count();
    }

    private function formatCancelledByName(object $appointment): ?string
    {
        $firstName = trim((string) ($appointment->cancelled_by_first_name ?? ''));
        $lastName = trim((string) ($appointment->cancelled_by_last_name ?? ''));
        $name = trim($firstName . ' ' . $lastName);

        return $name !== '' ? $name : null;
    }

    private function serializeDetailedRecord(object $appointment): array
    {
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
            'cancellation_reason' => $record['cancellation_reason'],
            'cancelled_by' => $record['cancelled_by'],
            'cancelled_by_name' => $record['cancelled_by_name'],
            'cancelled_at' => $record['cancelled_at'],
            'logs' => $this->appointmentLogs((int) $record['appointment_id']),
        ];
    }

    private function appointmentLogs(int $appointmentId): array
    {
        return AuditTrail::query()
            ->with('user')
            ->where('auditable_type', Appointment::class)
            ->where('auditable_id', $appointmentId)
            ->latest()
            ->get()
            ->map(function (AuditTrail $trail): array {
                $metadata = is_array($trail->metadata) ? $trail->metadata : [];
                $newStatus = (string) ($metadata['new_status'] ?? '');
                $oldStatus = (string) ($metadata['old_status'] ?? '');
                $reason = trim((string) ($metadata['reason'] ?? ''));

                return [
                    'id' => (int) $trail->id,
                    'appointment_id' => (int) $trail->auditable_id,
                    'action' => $this->historyActionLabel((string) $trail->event, $newStatus, $reason),
                    'old_status' => $oldStatus !== '' ? $this->formatStatusLabel($oldStatus) : null,
                    'new_status' => $newStatus !== '' ? $this->formatStatusLabel($newStatus) : null,
                    'action_status' => $newStatus !== '' ? $this->formatStatusLabel($newStatus) : null,
                    'performed_by' => $this->formatAuditUserName($trail),
                    'performed_by_id' => $trail->user_id !== null ? (int) $trail->user_id : null,
                    'action_at' => optional($trail->created_at)?->toIso8601String(),
                    'created_at' => optional($trail->created_at)?->toIso8601String(),
                    'reason' => $reason !== '' ? $reason : null,
                    'cancellation_reason' => $reason !== '' ? $reason : null,
                ];
            })
            ->all();
    }

    private function historyActionLabel(string $event, string $newStatus, ?string $reason = null): string
    {
        return match ($event) {
            'appointment_created' => $newStatus === self::STATUS_PENDING
                ? 'Pending appointment created'
                : 'Appointment created',
            'appointment_approved' => 'Approved appointment',
            'appointment_cancelled' => trim((string) $reason) !== ''
                ? 'Staff/Admin cancellation with reason'
                : 'Patient cancellation while still pending',
            'appointment_completed' => 'Completed appointment',
            'appointment_rescheduled' => 'Rescheduled appointment',
            default => 'Appointment status updated',
        };
    }

    private function formatAuditUserName(AuditTrail $trail): ?string
    {
        if ($trail->user === null) {
            return null;
        }

        $name = trim(sprintf(
            '%s %s',
            (string) $trail->user->first_name,
            (string) $trail->user->last_name,
        ));

        return $name !== '' ? $name : (string) $trail->user->username;
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
        return AppointmentService::humanStatusLabel($status);
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

    private function trendLabelExpression(string $trendType): string
    {
        $driver = DB::connection()->getDriverName();

        if ($driver === 'sqlite') {
            return match ($trendType) {
                self::TREND_TYPE_DAILY => "strftime('%Y-%m-%d', appointments.appointment_date)",
                self::TREND_TYPE_WEEKLY => "strftime('%Y', date(appointments.appointment_date, '-3 days', 'weekday 4')) || '-W' || printf('%02d', ((CAST(strftime('%j', date(appointments.appointment_date, '-3 days', 'weekday 4')) AS INTEGER) - 1) / 7) + 1)",
                self::TREND_TYPE_MONTHLY => "strftime('%Y-%m', appointments.appointment_date)",
                default => throw new \InvalidArgumentException('Unsupported trend type.'),
            };
        }

        if ($driver === 'pgsql') {
            return match ($trendType) {
                self::TREND_TYPE_DAILY => "TO_CHAR(appointments.appointment_date, 'YYYY-MM-DD')",
                self::TREND_TYPE_WEEKLY => "TO_CHAR(appointments.appointment_date, 'IYYY-\"W\"IW')",
                self::TREND_TYPE_MONTHLY => "TO_CHAR(appointments.appointment_date, 'YYYY-MM')",
                default => throw new \InvalidArgumentException('Unsupported trend type.'),
            };
        }

        return match ($trendType) {
            self::TREND_TYPE_DAILY => "DATE_FORMAT(appointments.appointment_date, '%Y-%m-%d')",
            self::TREND_TYPE_WEEKLY => "DATE_FORMAT(appointments.appointment_date, '%x-W%v')",
            self::TREND_TYPE_MONTHLY => "DATE_FORMAT(appointments.appointment_date, '%Y-%m')",
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
                return Carbon::createFromFormat($format, $normalized)->format('H:i');
            } catch (\Throwable) {
                continue;
            }
        }

        return $normalized;
    }

    private function paginationMeta(LengthAwarePaginator $paginator): array
    {
        return [
            'current_page' => $paginator->currentPage(),
            'last_page' => $paginator->lastPage(),
            'per_page' => $paginator->perPage(),
            'total' => $paginator->total(),
            'from' => $paginator->firstItem(),
            'to' => $paginator->lastItem(),
            'has_more_pages' => $paginator->hasMorePages(),
        ];
    }
}
