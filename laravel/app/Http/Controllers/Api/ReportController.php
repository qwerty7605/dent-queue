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

    public function export(Request $request): Response|StreamedResponse
    {
        $filters = $this->validateReportFilters($request);
        $format = $this->normalizeExportFormat($request->query('format'));
        $records = $this->reportService->getDetailedRecordsForExport($filters);
        $headers = $this->exportHeaders();

        return match ($format) {
            self::EXPORT_FORMAT_EXCEL => $this->downloadExcel($headers, $records),
            self::EXPORT_FORMAT_PDF => $this->downloadPdf($headers, $records, $filters),
            default => $this->downloadCsv($headers, $records),
        };
    }

    private function downloadCsv(array $headers, array $records): StreamedResponse
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

    private function downloadExcel(array $headers, array $records): Response
    {
        $filename = 'report-records-'.now()->format('Ymd-His').'.xls';
        $xml = $this->buildExcelDocument($headers, $records);

        return response($xml, 200, [
            'Content-Type' => 'application/vnd.ms-excel; charset=UTF-8',
            'Content-Disposition' => sprintf('attachment; filename="%s"', $filename),
            'Access-Control-Expose-Headers' => 'Content-Disposition, Content-Type',
        ]);
    }

    private function downloadPdf(array $headers, array $records, array $filters): Response
    {
        $filename = 'report-records-'.now()->format('Ymd-His').'.pdf';
        $pdf = $this->buildPdfDocument($headers, $records, $filters);

        return response($pdf, 200, [
            'Content-Type' => 'application/pdf',
            'Content-Disposition' => sprintf('attachment; filename="%s"', $filename),
            'Access-Control-Expose-Headers' => 'Content-Disposition, Content-Type',
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
            $this->sanitizeExportValue($record['appointment_time']),
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

    private function buildExcelDocument(array $headers, array $records): string
    {
        $rows = [];
        $rows[] = $this->buildExcelRow($headers);

        foreach ($records as $record) {
            $rows[] = $this->buildExcelRow($this->exportRow($record));
        }

        return implode('', [
            '<?xml version="1.0" encoding="UTF-8"?>',
            '<?mso-application progid="Excel.Sheet"?>',
            '<Workbook xmlns="urn:schemas-microsoft-com:office:spreadsheet"',
            ' xmlns:o="urn:schemas-microsoft-com:office:office"',
            ' xmlns:x="urn:schemas-microsoft-com:office:excel"',
            ' xmlns:ss="urn:schemas-microsoft-com:office:spreadsheet">',
            '<Worksheet ss:Name="Reports"><Table>',
            implode('', $rows),
            '</Table></Worksheet></Workbook>',
        ]);
    }

    private function buildExcelRow(array $values): string
    {
        $cells = array_map(function (mixed $value): string {
            return sprintf(
                '<Cell><Data ss:Type="String">%s</Data></Cell>',
                htmlspecialchars($this->sanitizeExportValue($value), ENT_XML1 | ENT_QUOTES, 'UTF-8'),
            );
        }, $values);

        return '<Row>'.implode('', $cells).'</Row>';
    }

    private function buildPdfDocument(array $headers, array $records, array $filters): string
    {
        $tableRows = array_map(fn (array $record): array => $this->exportRow($record), $records);

        return $this->renderTablePdf($headers, $tableRows, $filters);
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

    private function renderTablePdf(array $headers, array $rows, array $filters): string
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
}
