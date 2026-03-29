<?php

namespace App\Http\Controllers\Api\Concerns;

use App\Services\ReportService;
use Illuminate\Http\Request;

trait InteractsWithReportFilters
{
    private function validateReportFilters(Request $request): array
    {
        $payload = $request->validate([
            'start_date' => ['nullable', 'date_format:Y-m-d'],
            'end_date' => ['nullable', 'date_format:Y-m-d', 'after_or_equal:start_date'],
            'status' => [
                'nullable',
                'string',
                function (string $attribute, mixed $value, \Closure $fail): void {
                    if (ReportService::normalizeStatusFilter((string) $value) === null) {
                        $fail("The {$attribute} field is invalid.");
                    }
                },
            ],
            'booking_type' => [
                'nullable',
                'string',
                function (string $attribute, mixed $value, \Closure $fail): void {
                    if (ReportService::normalizeBookingTypeFilter((string) $value) === null) {
                        $fail("The {$attribute} field is invalid.");
                    }
                },
            ],
        ]);

        return [
            'start_date' => $payload['start_date'] ?? null,
            'end_date' => $payload['end_date'] ?? null,
            'status' => array_key_exists('status', $payload)
                ? ReportService::normalizeStatusFilter((string) $payload['status'])
                : null,
            'booking_type' => array_key_exists('booking_type', $payload)
                ? ReportService::normalizeBookingTypeFilter((string) $payload['booking_type'])
                : null,
        ];
    }
}
