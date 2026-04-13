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
        Appointment::saved($this->flushDashboardReportsAndQueue(...));
        Appointment::deleted($this->flushDashboardReportsAndQueue(...));
        Appointment::restored($this->flushDashboardReportsAndQueue(...));
        Appointment::forceDeleted($this->flushDashboardReportsAndQueue(...));

        PatientRecord::saved($this->flushDashboardReportsAndQueue(...));
        PatientRecord::deleted($this->flushDashboardReportsAndQueue(...));
        PatientRecord::restored($this->flushDashboardReportsAndQueue(...));
        PatientRecord::forceDeleted($this->flushDashboardReportsAndQueue(...));

        User::saved($this->flushDashboardAndUserNotifications(...));
        User::deleted($this->flushDashboardAndUserNotifications(...));

        Service::saved($this->flushReportsAndQueue(...));
        Service::deleted($this->flushReportsAndQueue(...));

        Queue::saved($this->flushReportsAndQueue(...));
        Queue::deleted($this->flushReportsAndQueue(...));

        PatientNotification::saved($this->afterCommitListener($this->flushPatientNotifications(...)));
        PatientNotification::deleted($this->afterCommitListener($this->flushPatientNotifications(...)));

        StaffNotification::saved($this->afterCommitListener($this->flushStaffNotifications(...)));
        StaffNotification::deleted($this->afterCommitListener($this->flushStaffNotifications(...)));
    }

    private function afterCommitListener(callable $listener): Closure
    {
        return function (object $model) use ($listener): void {
            if (DB::transactionLevel() === 0) {
                $listener($model);

                return;
            }

            DB::afterCommit(function () use ($listener, $model): void {
                $listener($model);
            });
        };
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
