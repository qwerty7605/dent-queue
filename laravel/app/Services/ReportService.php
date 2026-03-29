<?php

namespace App\Services;

use App\Models\Appointment;
use Illuminate\Support\Carbon;

class ReportService
{
    private const TREND_TYPE_DAILY = 'daily';
    private const TREND_TYPE_WEEKLY = 'weekly';
    private const TREND_TYPE_MONTHLY = 'monthly';
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

    public function getAppointmentTrends(string $trendType): array
    {
        $appointments = Appointment::query()
            ->orderBy('appointment_date')
            ->get(['appointment_date']);

        return $appointments
            ->groupBy(function (Appointment $appointment) use ($trendType): string {
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
}
