<?php

namespace Database\Seeders\Concerns;

use App\Models\Appointment;
use App\Models\PatientRecord;
use App\Models\User;
use Illuminate\Database\Eloquent\Builder;

trait InteractsWithBulkSeedData
{
    protected const BULK_SEED_MARKER = '[bulk-seeded]';
    protected const BULK_WALK_IN_ID_PREFIX = 'BULK-WALK-';
    private const BULK_WALK_IN_RECORD_ID_START = 8500000000000;

    protected function bulkSeedConfig(string $key, mixed $default = null): mixed
    {
        return config('bulk_seed.' . $key, $default);
    }

    protected function bulkSeedMarker(): string
    {
        return self::BULK_SEED_MARKER;
    }

    protected function bulkUserEmail(string $group, int $index): string
    {
        return sprintf('bulk.%s.%04d@example.com', $group, $index);
    }

    protected function bulkUsername(string $group, int $index): string
    {
        return sprintf('bulk_%s_%04d', $group, $index);
    }

    protected function bulkUserPhone(string $group, int $index): string
    {
        $groupDigits = match ($group) {
            'admin' => '11',
            'staff' => '22',
            default => '33',
        };

        return sprintf('09%s%07d', $groupDigits, $index);
    }

    protected function bulkWalkInIdentifier(int $index): string
    {
        return sprintf('%s%05d', self::BULK_WALK_IN_ID_PREFIX, $index);
    }

    protected function bulkWalkInRecordId(int $index): int
    {
        return self::BULK_WALK_IN_RECORD_ID_START + $index;
    }

    protected function bulkUsersQuery(): Builder
    {
        return User::query()->where('email', 'like', 'bulk.%@example.com');
    }

    protected function bulkPatientRecordsQuery(): Builder
    {
        return PatientRecord::query()
            ->whereHas('user', function (Builder $query): void {
                $query->where('email', 'like', 'bulk.patient.%@example.com');
            });
    }

    protected function bulkWalkInRecordsQuery(): Builder
    {
        return PatientRecord::query()
            ->whereNull('user_id')
            ->where('patient_id', 'like', self::BULK_WALK_IN_ID_PREFIX . '%');
    }

    protected function bulkAppointmentsQuery(): Builder
    {
        return Appointment::query()->where('notes', 'like', self::BULK_SEED_MARKER . '%');
    }

    /**
     * @return array<int, string>
     */
    protected function appointmentTimeSlots(): array
    {
        return [
            '08:00',
            '08:30',
            '09:00',
            '09:30',
            '10:00',
            '10:30',
            '11:00',
            '11:30',
            '13:00',
            '13:30',
            '14:00',
            '14:30',
            '15:00',
            '15:30',
            '16:00',
            '16:30',
        ];
    }
}
