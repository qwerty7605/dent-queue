<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\SoftDeletes;

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
    ];

    public function patient()
    {
        return $this->belongsTo(PatientRecord::class, 'patient_id')->withTrashed();
    }

    public function service()
    {
        return $this->belongsTo(Service::class);
    }

    public function queue()
    {
        return $this->hasOne(Queue::class);
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
