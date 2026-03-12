<?php

namespace App\Models;

// use Illuminate\Contracts\Auth\MustVerifyEmail;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Relations\HasManyThrough;
use Illuminate\Database\Eloquent\Relations\HasOne;
use Illuminate\Foundation\Auth\User as Authenticatable;
use Illuminate\Notifications\Notifiable;
use Laravel\Sanctum\HasApiTokens;

class User extends Authenticatable
{
    /** @use HasFactory<\Database\Factories\UserFactory> */
    use HasFactory, Notifiable, HasApiTokens;

    protected static function booted(): void
    {
        static::saved(function (self $user): void {
            $user->syncPatientRecord();
        });
    }

    /**
     * The attributes that are mass assignable.
     *
     * @var list<string>
     */
    protected $fillable = [
        'first_name',
        'middle_name',
        'last_name',
        'username',
        'email',
        'password',
        'phone_number',
        'birthdate',
        'location',
        'gender',
        'profile_picture',
        'role_id',
        'is_active',
    ];

    /**
     * Get the role associated with the user.
     */
    public function role()
    {
        return $this->belongsTo(Role::class);
    }

    public function patientRecord(): HasOne
    {
        return $this->hasOne(PatientRecord::class);
    }

    /**
     * Get the appointments for the user (as a patient).
     */
    public function appointments(): HasManyThrough
    {
        return $this->hasManyThrough(
            Appointment::class,
            PatientRecord::class,
            'user_id',
            'patient_id',
            'id',
            'id',
        );
    }

    public function patientNotifications(): HasManyThrough
    {
        return $this->hasManyThrough(
            PatientNotification::class,
            PatientRecord::class,
            'user_id',
            'patient_id',
            'id',
            'id',
        );
    }

    /**
     * The attributes that should be hidden for serialization.
     *
     * @var list<string>
     */
    protected $hidden = [
        'password',
        'remember_token',
    ];

    /**
     * Get the attributes that should be cast.
     *
     * @return array<string, string>
     */
    protected function casts(): array
    {
        return [
            'email_verified_at' => 'datetime',
            'birthdate' => 'date',
            'password' => 'hashed',
        ];
    }

    private function syncPatientRecord(): ?PatientRecord
    {
        if (!$this->shouldMaintainPatientRecord()) {
            return null;
        }

        return PatientRecord::syncFromUser($this);
    }

    private function shouldMaintainPatientRecord(): bool
    {
        if ($this->role_id === null) {
            return false;
        }

        return $this->role()
            ->whereRaw('LOWER(name) = ?', ['patient'])
            ->exists();
    }
}
