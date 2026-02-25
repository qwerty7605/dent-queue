<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class Queue extends Model
{
    protected $fillable = [
        'appointment_id',
        'queue_date',
        'queue_number',
        'is_called',
    ];

    public function appointment()
    {
        return $this->belongsTo(Appointment::class);
    }
}
