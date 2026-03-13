<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class PatientRecord extends Model
{
    private const WALK_IN_ID_START = 9000000000000;
    private const WALK_IN_ID_END = 9999999999999;

    public $incrementing = false;

    protected $keyType = 'int';

    protected $fillable = [
        'id',
        'patient_id',
        'user_id',
        'first_name',
        'middle_name',
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
        static::creating(function (self $patientRecord): void {
            if ($patientRecord->getKey() === null) {
                $patientRecord->id = $patientRecord->user_id !== null
                    ? (int) $patientRecord->user_id
                    : self::generateWalkInRecordKey();
            }

            if (blank($patientRecord->patient_id)) {
                $patientRecord->patient_id = self::formatPatientIdentifier((int) $patientRecord->id);
            }
        });
    }

    public static function syncFromUser(User $user): self
    {
        $patientRecord = static::query()->firstOrNew([
            'user_id' => (int) $user->id,
        ]);

        if (!$patientRecord->exists) {
            $patientRecord->id = (int) $user->id;
        }

        $patientRecord->fill([
            'first_name' => $user->first_name,
            'middle_name' => $user->middle_name,
            'last_name' => $user->last_name,
            'gender' => $user->gender,
            'address' => $user->location,
            'contact_number' => $user->phone_number,
            'birthdate' => $user->birthdate,
        ]);

        if (blank($patientRecord->patient_id)) {
            $patientRecord->patient_id = self::formatPatientIdentifier((int) $patientRecord->id);
        }

        $patientRecord->save();

        return $patientRecord;
    }

    public static function resolveForUser(User $user): self
    {
        $user->loadMissing('patientRecord');

        return $user->patientRecord ?? static::syncFromUser($user);
    }

    public static function formatPatientIdentifier(int $recordKey): string
    {
        return 'PAT-' . str_pad((string) $recordKey, 13, '0', STR_PAD_LEFT);
    }

    public function user()
    {
        return $this->belongsTo(User::class);
    }

    public function appointments()
    {
        return $this->hasMany(Appointment::class, 'patient_id');
    }

    public function notifications()
    {
        return $this->hasMany(PatientNotification::class, 'patient_id');
    }

    private static function generateWalkInRecordKey(): int
    {
        do {
            $candidate = random_int(self::WALK_IN_ID_START, self::WALK_IN_ID_END);
        } while (static::query()->whereKey($candidate)->exists());

        return $candidate;
    }
}
