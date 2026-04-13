<?php

namespace App\Providers;

use App\Models\Appointment;
use App\Models\PatientNotification;
use App\Models\PatientRecord;
use App\Models\Queue;
use App\Models\Service;
use App\Models\StaffNotification;
use App\Models\User;
use App\Services\CentralizedCacheService;
use Closure;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\ServiceProvider;

class AppServiceProvider extends ServiceProvider
{
    /**
     * Register any application services.
     */
    public function register(): void
    {
        //
    }

    /**
     * Bootstrap any application services.
     */
    public function boot(): void
    {
        Appointment::saved($this->afterCommitListener($this->flushDashboardReportsAndQueue(...)));
        Appointment::deleted($this->afterCommitListener($this->flushDashboardReportsAndQueue(...)));
        Appointment::restored($this->afterCommitListener($this->flushDashboardReportsAndQueue(...)));
        Appointment::forceDeleted($this->afterCommitListener($this->flushDashboardReportsAndQueue(...)));

        PatientRecord::saved($this->afterCommitListener($this->flushDashboardReportsAndQueue(...)));
        PatientRecord::deleted($this->afterCommitListener($this->flushDashboardReportsAndQueue(...)));
        PatientRecord::restored($this->afterCommitListener($this->flushDashboardReportsAndQueue(...)));
        PatientRecord::forceDeleted($this->afterCommitListener($this->flushDashboardReportsAndQueue(...)));

        User::saved($this->afterCommitListener($this->flushDashboardAndUserNotifications(...)));
        User::deleted($this->afterCommitListener($this->flushDashboardAndUserNotifications(...)));

        Service::saved($this->afterCommitListener($this->flushReportsAndQueue(...)));
        Service::deleted($this->afterCommitListener($this->flushReportsAndQueue(...)));

        Queue::saved($this->afterCommitListener($this->flushReportsAndQueue(...)));
        Queue::deleted($this->afterCommitListener($this->flushReportsAndQueue(...)));

        PatientNotification::saved($this->afterCommitListener($this->flushPatientNotifications(...)));
        PatientNotification::deleted($this->afterCommitListener($this->flushPatientNotifications(...)));

        StaffNotification::saved($this->afterCommitListener($this->flushStaffNotifications(...)));
        StaffNotification::deleted($this->afterCommitListener($this->flushStaffNotifications(...)));
    }

    private function afterCommitListener(callable $listener): Closure
    {
        return function (object $model) use ($listener): void {
            $this->deferUntilAfterCommit(function () use ($listener, $model): void {
                $listener($model);
            });
        };
    }

    private function deferUntilAfterCommit(callable $callback): void
    {
        if (DB::transactionLevel() === 0) {
            $callback();

            return;
        }

        DB::afterCommit($callback);
    }

    private function flushDashboardReportsAndQueue(object $model): void
    {
        $cacheService = app(CentralizedCacheService::class);
        $cacheService->flushDashboard();
        $cacheService->flushReports();
        $cacheService->flushQueue();
    }

    private function flushDashboardAndUserNotifications(User $user): void
    {
        $cacheService = app(CentralizedCacheService::class);
        $cacheService->flushDashboard();
        $cacheService->flushNotificationsForUser($user);
    }

    private function flushReportsAndQueue(object $model): void
    {
        $cacheService = app(CentralizedCacheService::class);
        $cacheService->flushReports();
        $cacheService->flushQueue();
    }

    private function flushPatientNotifications(PatientNotification $notification): void
    {
        app(CentralizedCacheService::class)
            ->flushNotificationsForPatientRecord((int) $notification->patient_id);
    }

    private function flushStaffNotifications(StaffNotification $notification): void
    {
        app(CentralizedCacheService::class)
            ->flushNotificationsForStaffUser((int) $notification->user_id);
    }
}
