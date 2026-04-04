<?php

namespace App\Support;

use Illuminate\Database\Eloquent\Builder;

final class AppointmentQueueOrder
{
    public static function apply(Builder $query, string $appointmentsTable = 'appointments'): Builder
    {
        return $query
            ->orderBy($appointmentsTable . '.appointment_date')
            ->orderBy($appointmentsTable . '.time_slot')
            ->orderBy($appointmentsTable . '.created_at')
            ->orderBy($appointmentsTable . '.id');
    }

    public static function applyDescending(Builder $query, string $appointmentsTable = 'appointments'): Builder
    {
        return $query
            ->orderByDesc($appointmentsTable . '.appointment_date')
            ->orderByDesc($appointmentsTable . '.time_slot')
            ->orderByDesc($appointmentsTable . '.created_at')
            ->orderByDesc($appointmentsTable . '.id');
    }
}
