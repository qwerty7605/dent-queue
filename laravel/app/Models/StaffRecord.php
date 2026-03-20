<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class StaffRecord extends Model
{
    public $incrementing = false;

    protected $keyType = 'int';

    protected $fillable = [
        'id',
        'staff_id',
        'user_id',
        'first_name',
        'last_name',
        'gender',
        'address',
        'contact_number',
        'birthdate',
    ];

    protected $casts = [
        'birthdate' => 'date',
    ];

    protected static function booted(): void
    {
        static::creating(function (self $staffRecord): void {
            if ($staffRecord->getKey() === null) {
                $staffRecord->id = (int) $staffRecord->user_id;
            }

            if (blank($staffRecord->staff_id)) {
                $staffRecord->staff_id = self::formatStaffIdentifier((int) $staffRecord->id);
            }
        });
    }

    public static function syncFromUser(User $user): self
    {
        $staffRecord = static::query()->firstOrNew([
            'user_id' => (int) $user->id,
        ]);

        if (!$staffRecord->exists) {
            $staffRecord->id = (int) $user->id;
        }

        $staffRecord->fill([
            'first_name' => $user->first_name,
            'last_name' => $user->last_name,
            'gender' => $user->gender,
            'address' => $user->location,
            'contact_number' => $user->phone_number,
            'birthdate' => $user->birthdate,
        ]);

        if (blank($staffRecord->staff_id)) {
            $staffRecord->staff_id = self::formatStaffIdentifier((int) $staffRecord->id);
        }

        $staffRecord->save();

        return $staffRecord;
    }

    public static function formatStaffIdentifier(int $recordKey): string
    {
        return 'STF-' . str_pad((string) $recordKey, 13, '0', STR_PAD_LEFT);
    }

    public function user()
    {
        return $this->belongsTo(User::class);
    }
}
