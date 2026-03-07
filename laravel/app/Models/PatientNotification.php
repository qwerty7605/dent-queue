<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class PatientNotification extends Model
{
    protected $fillable = [
        'patient_id',
        'appointment_id',
        'type',
        'title',
        'message',
        'read_at',
    ];

    protected $casts = [
        'read_at' => 'datetime',
    ];

    public function patient()
    {
        return $this->belongsTo(User::class, 'patient_id');
    }

    public function appointment()
    {
        return $this->belongsTo(Appointment::class, 'appointment_id');
    }
}
