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
        Appointment::saved($this->flushDashboardAndReports(...));
        Appointment::deleted($this->flushDashboardAndReports(...));
        Appointment::restored($this->flushDashboardAndReports(...));
        Appointment::forceDeleted($this->flushDashboardAndReports(...));

        PatientRecord::saved($this->flushDashboardAndReports(...));
        PatientRecord::deleted($this->flushDashboardAndReports(...));
        PatientRecord::restored($this->flushDashboardAndReports(...));
        PatientRecord::forceDeleted($this->flushDashboardAndReports(...));

        User::saved($this->flushDashboardAndUserNotifications(...));
        User::deleted($this->flushDashboardAndUserNotifications(...));

        Service::saved($this->flushReports(...));
        Service::deleted($this->flushReports(...));

        Queue::saved($this->flushReports(...));
        Queue::deleted($this->flushReports(...));

        PatientNotification::saved($this->flushPatientNotifications(...));
        PatientNotification::deleted($this->flushPatientNotifications(...));

        StaffNotification::saved($this->flushStaffNotifications(...));
        StaffNotification::deleted($this->flushStaffNotifications(...));
    }

    private function flushDashboardAndReports(object $model): void
    {
        $cacheService = app(CentralizedCacheService::class);
        $cacheService->flushDashboard();
        $cacheService->flushReports();
    }

    private function flushDashboardAndUserNotifications(User $user): void
    {
        $cacheService = app(CentralizedCacheService::class);
        $cacheService->flushDashboard();
        $cacheService->flushNotificationsForUser($user);
    }

    private function flushReports(object $model): void
    {
        app(CentralizedCacheService::class)->flushReports();
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
