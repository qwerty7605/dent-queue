<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Collection as EloquentCollection;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\BelongsToMany;
use Illuminate\Database\Eloquent\Relations\MorphMany;
use Illuminate\Database\Eloquent\SoftDeletes;
use Illuminate\Support\Collection;

class Appointment extends Model
{
    use SoftDeletes;

    protected $fillable = [
        'patient_id',
        'service_id',
        'appointment_date',
        'time_slot',
        'status',
        'notes',
        'cancellation_reason',
        'cancelled_by',
        'cancelled_at',
    ];

    protected function casts(): array
    {
        return [
            'cancelled_at' => 'datetime',
        ];
    }

    protected static function booted(): void
    {
        static::created(function (Appointment $appointment): void {
            if (
                (int) $appointment->service_id > 0
                && Service::query()->whereKey((int) $appointment->service_id)->exists()
            ) {
                $appointment->services()->syncWithoutDetaching([(int) $appointment->service_id]);
            }
        });
    }

    public function patient()
    {
        return $this->belongsTo(PatientRecord::class, 'patient_id')->withTrashed();
    }

    public function service(): BelongsTo
    {
        return $this->belongsTo(Service::class);
    }

    public function services(): BelongsToMany
    {
        return $this->belongsToMany(Service::class, 'appointment_service')
            ->withTimestamps();
    }

    public function selectedServices(): EloquentCollection
    {
        $services = $this->relationLoaded('services')
            ? $this->services
            : $this->services()->get();

        if ($services->isNotEmpty()) {
            return $services;
        }

        $service = $this->relationLoaded('service')
            ? $this->service
            : $this->service()->first();

        return $service !== null
            ? new EloquentCollection([$service])
            : new EloquentCollection();
    }

    public function selectedServiceIds(): array
    {
        return $this->selectedServices()
            ->pluck('id')
            ->map(static fn (mixed $id): int => (int) $id)
            ->values()
            ->all();
    }

    public function selectedServiceNames(): Collection
    {
        return $this->selectedServices()
            ->pluck('name')
            ->filter(static fn (mixed $name): bool => trim((string) $name) !== '')
            ->map(static fn (mixed $name): string => (string) $name)
            ->values();
    }

    public function serviceSummary(): string
    {
        $names = $this->selectedServiceNames();

        return $names->isNotEmpty()
            ? $names->implode(', ')
            : $this->fallbackServiceType();
    }

    public function fallbackServiceType(): string
    {
        return match ((int) $this->service_id) {
            1 => 'Dental Check-up',
            2 => 'Dental Panoramic X-ray',
            3 => 'Root Canal',
            4 => 'Teeth Cleaning',
            5 => 'Teeth Whitening',
            6 => 'Tooth Extraction',
            default => 'Unknown Service',
        };
    }

    public function queue()
    {
        return $this->hasOne(Queue::class);
    }

    public function cancelledBy(): BelongsTo
    {
        return $this->belongsTo(User::class, 'cancelled_by');
    }

    public function auditTrails(): MorphMany
    {
        return $this->morphMany(AuditTrail::class, 'auditable');
    }

    public function reports()
    {
        return $this->hasMany(Report::class);
    }

    public function patientNotifications()
    {
        return $this->hasMany(PatientNotification::class, 'appointment_id');
    }

    public function scopeRecycleBinEligible(Builder $query): Builder
    {
        return $query->onlyTrashed()
            ->where('status', 'cancelled');
    }
}
