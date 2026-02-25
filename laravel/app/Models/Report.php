<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class Report extends Model
{
    protected $fillable = [
        'appointment_id',
        'report_type',
        'report_date',
        'data',
    ];

    protected $casts = [
        'data' => 'array',
    ];

    public function appointment()
    {
        return $this->belongsTo(Appointment::class);
    }
}
