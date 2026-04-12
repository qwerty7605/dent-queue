<?php

namespace App\Services;

use App\Models\PatientRecord;
use App\Models\User;
use Carbon\CarbonInterface;
use Illuminate\Support\Facades\Cache;

class CentralizedCacheService
{
    private const DASHBOARD_NAMESPACE = 'dashboard';
    private const REPORTS_NAMESPACE = 'reports';
    private const VERSION_SUFFIX = 'version';

    public function rememberDashboardStats(callable $resolver): array
    {
        return $this->remember(
            self::DASHBOARD_NAMESPACE,
            'stats',
            $this->ttlFor('dashboard'),
            $resolver,
        );
    }

    public function rememberReportSummary(array $filters, callable $resolver): array
    {
        return $this->remember(
            self::REPORTS_NAMESPACE,
            'summary:' . $this->filtersHash($filters),
            $this->ttlFor('reports'),
            $resolver,
        );
    }

    public function rememberReportStatusDistribution(array $filters, callable $resolver): array
    {
        return $this->remember(
            self::REPORTS_NAMESPACE,
            'status_distribution:' . $this->filtersHash($filters),
            $this->ttlFor('reports'),
            $resolver,
        );
    }

    public function rememberReportTrends(string $trendType, array $filters, callable $resolver): array
    {
        return $this->remember(
            self::REPORTS_NAMESPACE,
            'trends:' . $trendType . ':' . $this->filtersHash($filters),
            $this->ttlFor('reports'),
            $resolver,
        );
    }

    public function rememberReportDetailedRecords(array $filters, callable $resolver): array
    {
        return $this->remember(
            self::REPORTS_NAMESPACE,
            'detailed_records:' . $this->filtersHash($filters),
            $this->ttlFor('reports'),
            $resolver,
        );
    }

    public function rememberReportExportRecords(array $filters, callable $resolver): array
    {
        return $this->remember(
            self::REPORTS_NAMESPACE,
            'export_records:' . $this->filtersHash($filters),
            $this->ttlFor('reports'),
            $resolver,
        );
    }

    public function rememberNotificationsListForUser(User $user, callable $resolver): array
    {
        return $this->remember(
            $this->notificationsNamespace($user),
            'list',
            $this->ttlFor('notifications'),
            $resolver,
        );
    }

    public function rememberNotificationsUnreadCountForUser(User $user, callable $resolver): int
    {
        return (int) $this->remember(
            $this->notificationsNamespace($user),
            'unread_count',
            $this->ttlFor('notifications'),
            $resolver,
        );
    }

    public function flushDashboard(): void
    {
        $this->bumpVersion(self::DASHBOARD_NAMESPACE);
    }

    public function flushReports(): void
    {
        $this->bumpVersion(self::REPORTS_NAMESPACE);
    }

    public function flushNotificationsForPatientRecord(int $patientRecordId): void
    {
        $this->bumpVersion($this->patientNotificationsNamespace($patientRecordId));
    }

    public function flushNotificationsForStaffUser(int $userId): void
    {
        $this->bumpVersion($this->staffNotificationsNamespace($userId));
    }

    public function flushNotificationsForUser(User $user): void
    {
        $roleName = $this->normalizeRoleName($user);

        if ($roleName === 'patient' && $user->patientRecord !== null) {
            $this->flushNotificationsForPatientRecord((int) $user->patientRecord->getKey());

            return;
        }

        if (in_array($roleName, ['staff', 'admin'], true)) {
            $this->flushNotificationsForStaffUser((int) $user->getKey());
        }
    }

    private function remember(string $namespace, string $suffix, mixed $ttl, callable $resolver): mixed
    {
        $key = sprintf(
            'central_cache:%s:v%s:%s',
            $namespace,
            $this->currentVersion($namespace),
            $suffix,
        );

        return Cache::remember($key, $ttl, $resolver);
    }

    private function ttlFor(string $module): CarbonInterface
    {
        $seconds = max(
            1,
            (int) config('cache.centralized_ttl_seconds.' . $module, 300),
        );

        return now()->addSeconds($seconds);
    }

    private function currentVersion(string $namespace): int
    {
        return (int) Cache::get($this->versionKey($namespace), 1);
    }

    private function bumpVersion(string $namespace): void
    {
        Cache::forever(
            $this->versionKey($namespace),
            $this->currentVersion($namespace) + 1,
        );
    }

    private function versionKey(string $namespace): string
    {
        return 'central_cache:' . $namespace . ':' . self::VERSION_SUFFIX;
    }

    private function filtersHash(array $filters): string
    {
        $normalized = $filters;
        ksort($normalized);

        return sha1((string) json_encode($normalized));
    }

    private function notificationsNamespace(User $user): string
    {
        $roleName = $this->normalizeRoleName($user);

        if ($roleName === 'patient') {
            $patientRecordId = (int) PatientRecord::resolveForUser($user)->getKey();

            return $this->patientNotificationsNamespace($patientRecordId);
        }

        return $this->staffNotificationsNamespace((int) $user->getKey());
    }

    private function patientNotificationsNamespace(int $patientRecordId): string
    {
        return 'notifications:patient:' . $patientRecordId;
    }

    private function staffNotificationsNamespace(int $userId): string
    {
        return 'notifications:staff:' . $userId;
    }

    private function normalizeRoleName(User $user): string
    {
        $user->loadMissing('role');

        return mb_strtolower((string) optional($user->role)->name);
    }
}
