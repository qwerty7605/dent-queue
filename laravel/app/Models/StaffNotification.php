<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class StaffNotification extends Model
{
    protected $fillable = [
        'user_id',
        'appointment_id',
        'type',
        'title',
        'message',
        'read_at',
    ];

    protected $casts = [
        'read_at' => 'datetime',
    ];

    public function user()
    {
        return $this->belongsTo(User::class);
    }

    public function appointment()
    {
        return $this->belongsTo(Appointment::class);
    }
}
