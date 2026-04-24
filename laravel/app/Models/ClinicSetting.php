<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class ClinicSetting extends Model
{
    protected $fillable = [
        'clinic_title',
        'practice_license_id',
        'operational_hotline',
        'clinic_headquarters',
        'opening_time',
        'closing_time',
        'working_days',
        'daily_operating_hours',
        'updated_by_user_id',
    ];

    /**
     * Get the user that last updated the clinic settings.
     */
    public function updatedBy(): BelongsTo
    {
        return $this->belongsTo(User::class, 'updated_by_user_id');
    }

    /**
     * Get the attribute cast definitions.
     *
     * @return array<string, string>
     */
    protected function casts(): array
    {
        return [
            'working_days' => 'array',
            'daily_operating_hours' => 'array',
        ];
    }
}
