<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Api\Concerns\InteractsWithReportFilters;
use App\Http\Controllers\Controller;
use App\Services\ReportService;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;
use Symfony\Component\HttpFoundation\StreamedResponse;

class ReportController extends Controller
{
    use InteractsWithReportFilters;

    private const EXPORT_FORMAT_CSV = 'csv';

    private const EXPORT_FORMAT_EXCEL = 'excel';

    private const EXPORT_FORMAT_PDF = 'pdf';

    private const PDF_EXPORT_MAX_RECORDS = 1000;

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
        $filters = request()->query();
        unset($filters['force_refresh']);

        return response()->json([
            'data' => $this->reportService->getDetailedRecords(
                $filters,
                request()->boolean('force_refresh'),
            ),
        ]);
    }

    public function export(Request $request): Response|StreamedResponse
    {
        $filters = $this->validateReportFilters($request);
        $format = $this->normalizeExportFormat($request->query('format'));
        $headers = $this->exportHeaders();

        return match ($format) {
            self::EXPORT_FORMAT_EXCEL => $this->downloadExcel(
                $headers,
                $this->reportService->streamDetailedRecordsForExport($filters),
            ),
            self::EXPORT_FORMAT_PDF => $this->downloadPdf(
                $headers,
                $this->reportService->getDetailedRecordsForPdfExport(
                    $filters,
                    self::PDF_EXPORT_MAX_RECORDS,
                ),
                $filters,
                $this->reportService->getReportSummary(
                    $filters,
                    $request->boolean('force_refresh'),
                )['total_appointments'] ?? 0,
            ),
            default => $this->downloadCsv(
                $headers,
                $this->reportService->streamDetailedRecordsForExport($filters),
            ),
        };
    }

    private function downloadCsv(array $headers, iterable $records): StreamedResponse
    {
        $filename = 'report-records-'.now()->format('Ymd-His').'.csv';

        return response()->streamDownload(function () use ($headers, $records): void {
            $handle = fopen('php://output', 'wb');

            if ($handle === false) {
                return;
            }

            fputcsv($handle, $headers);

            foreach ($records as $record) {
                fputcsv($handle, $this->exportRow($record));
            }

            fclose($handle);
        }, $filename, [
            'Content-Type' => 'text/csv; charset=UTF-8',
            'Access-Control-Expose-Headers' => 'Content-Disposition, Content-Type',
        ]);
    }

    private function downloadExcel(array $headers, iterable $records): StreamedResponse
    {
        $filename = 'report-records-'.now()->format('Ymd-His').'.xls';
        return response()->streamDownload(function () use ($headers, $records): void {
            echo '<html><head><meta charset="UTF-8"></head><body><table border="1"><tr>';
            foreach ($headers as $header) {
                echo '<th>'.htmlspecialchars($this->sanitizeExportValue($header), ENT_QUOTES, 'UTF-8').'</th>';
            }
            echo '</tr>';

            foreach ($records as $record) {
                echo '<tr>';
                foreach ($this->exportRow($record) as $value) {
                    echo '<td>'.htmlspecialchars($this->sanitizeExportValue($value), ENT_QUOTES, 'UTF-8').'</td>';
                }
                echo '</tr>';
            }

            echo '</table></body></html>';
        }, $filename, [
            'Content-Type' => 'application/vnd.ms-excel; charset=UTF-8',
            'Access-Control-Expose-Headers' => 'Content-Disposition, Content-Type',
        ]);
    }

    private function downloadPdf(array $headers, array $records, array $filters, int $totalMatchingRecords): Response
    {
        $filename = 'report-records-'.now()->format('Ymd-His').'.pdf';
        $pdf = $this->buildPdfDocument($headers, $records, $filters, $totalMatchingRecords);
        $exportedCount = count($records);
        $limited = $totalMatchingRecords > $exportedCount;

        return response($pdf, 200, [
            'Content-Type' => 'application/pdf',
            'Content-Disposition' => sprintf('attachment; filename="%s"', $filename),
            'Access-Control-Expose-Headers' => 'Content-Disposition, Content-Type, X-Export-Limited, X-Export-Record-Count, X-Export-Total-Count',
            'X-Export-Limited' => $limited ? 'true' : 'false',
            'X-Export-Record-Count' => (string) $exportedCount,
            'X-Export-Total-Count' => (string) $totalMatchingRecords,
        ]);
    }

    private function exportHeaders(): array
    {
        return [
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

    private function exportRow(array $record): array
    {
        return [
            $this->sanitizeExportValue($record['appointment_id']),
            $this->sanitizeExportValue($record['patient_name']),
            $this->sanitizeExportValue($record['service_type']),
            $this->sanitizeExportValue($record['appointment_date']),
            $this->sanitizeExportValue($this->formatExportAppointmentTime($record['appointment_time'] ?? null)),
            $this->sanitizeExportValue($record['status']),
            $this->sanitizeExportValue($record['booking_type']),
            $this->sanitizeExportValue($record['queue_number']),
            $this->sanitizeExportValue($record['created_at']),
        ];
    }

    private function normalizeExportFormat(mixed $format): string
    {
        $normalized = strtolower(trim((string) $format));

        return match ($normalized) {
            'xlsx', 'xls', 'excel' => self::EXPORT_FORMAT_EXCEL,
            'pdf' => self::EXPORT_FORMAT_PDF,
            default => self::EXPORT_FORMAT_CSV,
        };
    }

    private function sanitizeExportValue(mixed $value): string
    {
        $string = trim((string) ($value ?? ''));

        return (string) preg_replace('/[\x00-\x1F\x7F]+/u', ' ', $string);
    }

    private function formatExportAppointmentTime(mixed $value): string
    {
        $time = trim((string) ($value ?? ''));
        if ($time === '' || $time === '-') {
            return $time;
        }

        foreach (['H:i:s', 'H:i', 'g:i A'] as $format) {
            try {
                return \Illuminate\Support\Carbon::createFromFormat($format, $time)->format('g:i A');
            } catch (\Throwable) {
                continue;
            }
        }

        return $time;
    }

    private function buildPdfDocument(array $headers, array $records, array $filters, int $totalMatchingRecords): string
    {
        $tableRows = array_map(fn (array $record): array => $this->exportRow($record), $records);

        return $this->renderTablePdf($headers, $tableRows, $filters, $totalMatchingRecords);
    }

    private function formatPdfFilters(array $filters): string
    {
        if ($filters === []) {
            return 'All records';
        }

        $parts = [];
        foreach ($filters as $key => $value) {
            $parts[] = ucfirst(str_replace('_', ' ', $key)).': '.$this->sanitizeExportValue($value);
        }

        return implode(', ', $parts);
    }

    private function renderTablePdf(array $headers, array $rows, array $filters, int $totalMatchingRecords): string
    {
        $pageWidth = 792;
        $pageHeight = 612;
        $leftMargin = 28;
        $rightMargin = 28;
        $topMargin = 34;
        $bottomMargin = 26;
        $tableTop = 500;
        $rowHeight = 18;
        $headerHeight = 24;
        $tableWidth = $pageWidth - $leftMargin - $rightMargin;
        $columnWidths = [55, 100, 110, 78, 74, 62, 86, 52, 119];
        $maxRowsPerPage = max(1, (int) floor(($tableTop - $bottomMargin - $headerHeight) / $rowHeight));
        $pages = $rows === [] ? [[]] : array_chunk($rows, $maxRowsPerPage);
        $objects = [];
        $pageObjectNumbers = [];
        $fontObjectNumber = 3 + (count($pages) * 2);

        foreach ($pages as $pageIndex => $pageRows) {
            $pageObjectNumber = 3 + ($pageIndex * 2);
            $contentObjectNumber = $pageObjectNumber + 1;
            $pageObjectNumbers[] = $pageObjectNumber;

            $objects[$pageObjectNumber] = sprintf(
                '<< /Type /Page /Parent 2 0 R /MediaBox [0 0 %d %d] /Resources << /Font << /F1 %d 0 R /F2 %d 0 R >> >> /Contents %d 0 R >>',
                $pageWidth,
                $pageHeight,
                $fontObjectNumber,
                $fontObjectNumber + 1,
                $contentObjectNumber,
            );

            $content = $this->buildPdfTablePageContent(
                headers: $headers,
                rows: $pageRows,
                filters: $filters,
                totalMatchingRecords: $totalMatchingRecords,
                exportedRecordCount: count($rows),
                pageNumber: $pageIndex + 1,
                pageCount: count($pages),
                leftMargin: $leftMargin,
                topMargin: $topMargin,
                tableTop: $tableTop,
                tableWidth: $tableWidth,
                headerHeight: $headerHeight,
                rowHeight: $rowHeight,
                columnWidths: $columnWidths,
            );
            $objects[$contentObjectNumber] = sprintf(
                "<< /Length %d >>\nstream\n%s\nendstream",
                strlen($content),
                $content,
            );
        }

        $objects[1] = '<< /Type /Catalog /Pages 2 0 R >>';
        $objects[2] = sprintf(
            '<< /Type /Pages /Kids [%s] /Count %d >>',
            implode(' ', array_map(static fn (int $number): string => sprintf('%d 0 R', $number), $pageObjectNumbers)),
            count($pageObjectNumbers),
        );
        $objects[$fontObjectNumber] = '<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>';
        $objects[$fontObjectNumber + 1] = '<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica-Bold >>';

        ksort($objects);

        $pdf = "%PDF-1.4\n";
        $offsets = [0];

        foreach ($objects as $number => $body) {
            $offsets[$number] = strlen($pdf);
            $pdf .= sprintf("%d 0 obj\n%s\nendobj\n", $number, $body);
        }

        $xrefOffset = strlen($pdf);
        $pdf .= sprintf("xref\n0 %d\n", count($objects) + 1);
        $pdf .= "0000000000 65535 f \n";

        foreach (array_keys($objects) as $number) {
            $pdf .= sprintf("%010d 00000 n \n", $offsets[$number]);
        }

        $pdf .= sprintf(
            "trailer << /Size %d /Root 1 0 R >>\nstartxref\n%d\n%%%%EOF",
            count($objects) + 1,
            $xrefOffset,
        );

        return $pdf;
    }

    private function buildPdfTablePageContent(
        array $headers,
        array $rows,
        array $filters,
        int $totalMatchingRecords,
        int $exportedRecordCount,
        int $pageNumber,
        int $pageCount,
        int $leftMargin,
        int $topMargin,
        int $tableTop,
        int $tableWidth,
        int $headerHeight,
        int $rowHeight,
        array $columnWidths,
    ): string {
        $contentLines = [];
        $titleY = 580;
        $metaY = 560;
        $filtersY = 545;
        $scopeY = 530;
        $pageLabelY = 580;
        $tableBottom = $tableTop - $headerHeight - (count($rows) * $rowHeight);

        $contentLines[] = '0.2 w';
        $contentLines[] = '0.93 0.95 0.93 rg';
        $contentLines[] = sprintf('%d %d %d %d re f', $leftMargin, $tableTop - $headerHeight, $tableWidth, $headerHeight);
        $contentLines[] = '0 0 0 RG';
        $contentLines[] = '0 0 0 rg';

        $contentLines[] = 'BT';
        $contentLines[] = '/F2 16 Tf';
        $contentLines[] = sprintf('1 0 0 1 %d %d Tm', $leftMargin, $titleY);
        $contentLines[] = sprintf('(%s) Tj', $this->escapePdfText('Detailed Reports Export'));
        $contentLines[] = '/F1 9 Tf';
        $contentLines[] = sprintf('1 0 0 1 %d %d Tm', $leftMargin, $metaY);
        $contentLines[] = sprintf('(%s) Tj', $this->escapePdfText('Generated at: '.now()->format('Y-m-d H:i:s')));
        $contentLines[] = sprintf('1 0 0 1 %d %d Tm', $leftMargin, $filtersY);
        $contentLines[] = sprintf('(%s) Tj', $this->escapePdfText('Filters: '.$this->truncatePdfCell($this->formatPdfFilters($filters), 110)));
        $contentLines[] = sprintf('1 0 0 1 %d %d Tm', $leftMargin, $scopeY);
        $contentLines[] = sprintf(
            '(%s) Tj',
            $this->escapePdfText($this->formatPdfScopeLabel($exportedRecordCount, $totalMatchingRecords)),
        );
        $contentLines[] = sprintf('1 0 0 1 %d %d Tm', $leftMargin + $tableWidth - 52, $pageLabelY);
        $contentLines[] = sprintf('(%s) Tj', $this->escapePdfText(sprintf('Page %d/%d', $pageNumber, $pageCount)));
        $contentLines[] = 'ET';

        $currentX = $leftMargin;
        foreach ($columnWidths as $width) {
            $contentLines[] = sprintf('%d %d m %d %d l S', $currentX, $tableTop, $currentX, $tableBottom);
            $currentX += $width;
        }
        $contentLines[] = sprintf('%d %d m %d %d l S', $leftMargin + $tableWidth, $tableTop, $leftMargin + $tableWidth, $tableBottom);
        $contentLines[] = sprintf('%d %d m %d %d l S', $leftMargin, $tableTop, $leftMargin + $tableWidth, $tableTop);
        $contentLines[] = sprintf('%d %d m %d %d l S', $leftMargin, $tableTop - $headerHeight, $leftMargin + $tableWidth, $tableTop - $headerHeight);

        for ($rowIndex = 0; $rowIndex <= count($rows); $rowIndex++) {
            $y = $tableTop - $headerHeight - ($rowIndex * $rowHeight);
            $contentLines[] = sprintf('%d %d m %d %d l S', $leftMargin, $y, $leftMargin + $tableWidth, $y);
        }

        $contentLines[] = 'BT';
        $contentLines[] = '/F2 8 Tf';
        $currentX = $leftMargin;
        foreach ($headers as $index => $header) {
            $contentLines[] = sprintf(
                '1 0 0 1 %d %d Tm',
                $currentX + 3,
                $tableTop - 15,
            );
            $contentLines[] = sprintf('(%s) Tj', $this->escapePdfText($this->truncatePdfCell($header, $this->maxPdfCharsForColumn($columnWidths[$index]))));
            $currentX += $columnWidths[$index];
        }
        $contentLines[] = 'ET';

        if ($rows === []) {
            $contentLines[] = 'BT';
            $contentLines[] = '/F1 10 Tf';
            $contentLines[] = sprintf('1 0 0 1 %d %d Tm', $leftMargin + 8, $tableTop - $headerHeight - 14);
            $contentLines[] = sprintf('(%s) Tj', $this->escapePdfText('No matching records.'));
            $contentLines[] = 'ET';
        } else {
            foreach ($rows as $rowIndex => $row) {
                $textY = $tableTop - $headerHeight - 13 - ($rowIndex * $rowHeight);
                $currentX = $leftMargin;

                $contentLines[] = 'BT';
                $contentLines[] = '/F1 8 Tf';
                foreach ($row as $index => $value) {
                    $contentLines[] = sprintf(
                        '1 0 0 1 %d %d Tm',
                        $currentX + 3,
                        $textY,
                    );
                    $contentLines[] = sprintf(
                        '(%s) Tj',
                        $this->escapePdfText(
                            $this->truncatePdfCell($value, $this->maxPdfCharsForColumn($columnWidths[$index])),
                        ),
                    );
                    $currentX += $columnWidths[$index];
                }
                $contentLines[] = 'ET';
            }
        }

        return implode("\n", $contentLines);
    }

    private function maxPdfCharsForColumn(int $columnWidth): int
    {
        return max(4, (int) floor(($columnWidth - 6) / 4.5));
    }

    private function truncatePdfCell(string $value, int $maxChars): string
    {
        $sanitized = $this->sanitizeExportValue($value);

        if (mb_strlen($sanitized) <= $maxChars) {
            return $sanitized;
        }

        return rtrim(mb_substr($sanitized, 0, max(1, $maxChars - 3))).'...';
    }

    private function escapePdfText(string $text): string
    {
        return str_replace(
            ['\\', '(', ')'],
            ['\\\\', '\\(', '\\)'],
            $this->sanitizeExportValue($text),
        );
    }

    private function formatPdfScopeLabel(int $exportedRecordCount, int $totalMatchingRecords): string
    {
        if ($totalMatchingRecords > $exportedRecordCount) {
            return sprintf(
                'Showing first %d of %d matching records for PDF export.',
                $exportedRecordCount,
                $totalMatchingRecords,
            );
        }

        return sprintf('Showing all %d matching records.', $exportedRecordCount);
    }
}
