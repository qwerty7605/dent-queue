<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class Appointment extends Model
{
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
}
