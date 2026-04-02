<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Api\Concerns\InteractsWithReportFilters;
use App\Http\Controllers\Controller;
use App\Services\ReportService;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\StreamedResponse;

class ReportController extends Controller
{
    use InteractsWithReportFilters;

    protected $reportService;

    public function __construct(ReportService $reportService)
    {
        $this->reportService = $reportService;
    }

    /**
     * Display a listing of the resource.
     */
    public function index()
    {
        return response()->json([
            'data' => $this->reportService->getDetailedRecords(),
        ]);
    }

    public function exportCsv(Request $request): StreamedResponse
    {
        $filters = $this->validateReportFilters($request);
        $records = $this->reportService->getDetailedRecordsForExport($filters);
        $headers = [
            'Appointment ID',
            'Patient Name',
            'Service Type',
            'Appointment Date',
            'Appointment Time',
            'Status',
            'Booking Type',
            'Queue Number',
            'Created At',
        ];
        $filename = 'report-records-' . now()->format('Ymd-His') . '.csv';

        return response()->streamDownload(function () use ($headers, $records): void {
            $handle = fopen('php://output', 'wb');

            if ($handle === false) {
                return;
            }

            fputcsv($handle, $headers);

            foreach ($records as $record) {
                fputcsv($handle, [
                    $record['appointment_id'],
                    $this->sanitizeCsvValue($record['patient_name']),
                    $this->sanitizeCsvValue($record['service_type']),
                    $this->sanitizeCsvValue($record['appointment_date']),
                    $this->sanitizeCsvValue($record['appointment_time']),
                    $this->sanitizeCsvValue($record['status']),
                    $this->sanitizeCsvValue($record['booking_type']),
                    $this->sanitizeCsvValue($record['queue_number']),
                    $this->sanitizeCsvValue($record['created_at']),
                ]);
            }

            fclose($handle);
        }, $filename, [
            'Content-Type' => 'text/csv; charset=UTF-8',
        ]);
    }

    /**
     * Store a newly created resource in storage.
     */
    public function store(Request $request)
    {
        //
    }

    /**
     * Display the specified resource.
     */
    public function show(string $id)
    {
        //
    }

    /**
     * Update the specified resource in storage.
     */
    public function update(Request $request, string $id)
    {
        //
    }

    /**
     * Remove the specified resource from storage.
     */
    public function destroy(string $id)
    {
        //
    }

    private function sanitizeCsvValue(mixed $value): string
    {
        $string = trim((string) ($value ?? ''));

        return (string) preg_replace('/[\x00-\x1F\x7F]+/u', ' ', $string);
    }
}
