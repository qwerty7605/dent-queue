<?php

namespace Database\Seeders;

use App\Models\Role;
use App\Models\User;
use Database\Seeders\Concerns\InteractsWithBulkSeedData;
use Illuminate\Database\Seeder;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\Hash;

class BulkUserSeeder extends Seeder
{
    use InteractsWithBulkSeedData;

    /**
     * @var array<int, string>
     */
    private array $firstNames = [
        'Avery',
        'Bianca',
        'Carlos',
        'Daphne',
        'Elijah',
        'Farrah',
        'Gavin',
        'Hannah',
        'Isla',
        'Jared',
        'Kiara',
        'Liam',
        'Mika',
        'Noah',
        'Olivia',
        'Paolo',
        'Quinn',
        'Rafael',
        'Sofia',
        'Theo',
    ];

    /**
     * @var array<int, string>
     */
    private array $middleNames = [
        'Anne',
        'Bea',
        'Claire',
        'Dawn',
        'Elaine',
        'Faith',
        'Grace',
        'Hope',
        'Ivy',
        'Jane',
    ];

    /**
     * @var array<int, string>
     */
    private array $lastNames = [
        'Aguilar',
        'Bautista',
        'Cruz',
        'Delos Santos',
        'Enriquez',
        'Flores',
        'Garcia',
        'Hernandez',
        'Ignacio',
        'Jimenez',
        'Lopez',
        'Mendoza',
        'Navarro',
        'Ortega',
        'Pascual',
        'Quintos',
        'Reyes',
        'Santiago',
        'Torres',
        'Valencia',
    ];

    /**
     * @var array<int, string>
     */
    private array $locations = [
        'Quezon City',
        'Makati City',
        'Pasig City',
        'Taguig City',
        'Mandaluyong City',
        'Caloocan City',
        'Marikina City',
        'Las Pinas City',
        'Paranaque City',
        'Manila City',
    ];

    public function run(): void
    {
        $password = Hash::make((string) $this->bulkSeedConfig('default_password', 'password123'));

        $roles = Role::query()
            ->whereIn('name', ['Admin', 'Staff', 'Patient'])
            ->get()
            ->keyBy(fn (Role $role): string => mb_strtolower($role->name));

        foreach ([
            'admin' => (int) $this->bulkSeedConfig('admins', 3),
            'staff' => (int) $this->bulkSeedConfig('staff', 15),
            'patient' => (int) $this->bulkSeedConfig('patients', 220),
        ] as $group => $count) {
            $role = $roles[$group] ?? null;

            if ($role === null) {
                throw new \RuntimeException(sprintf('Role [%s] was not found. Run RoleSeeder first.', ucfirst($group)));
            }

            for ($index = 1; $index <= $count; $index++) {
                $profile = $this->profileDataFor($group, $index);

                $user = User::query()->updateOrCreate(
                    ['email' => $this->bulkUserEmail($group, $index)],
                    [
                        'first_name' => $profile['first_name'],
                        'middle_name' => $profile['middle_name'],
                        'last_name' => $profile['last_name'],
                        'username' => $this->bulkUsername($group, $index),
                        'password' => $password,
                        'phone_number' => $this->bulkUserPhone($group, $index),
                        'location' => $profile['location'],
                        'gender' => $profile['gender'],
                        'role_id' => (int) $role->id,
                        'is_active' => true,
                    ],
                );

                $birthdate = Carbon::now()
                    ->subYears(18 + (($index + strlen($group)) % 35))
                    ->subDays($index % 180)
                    ->toDateString();

                $user->forceFill([
                    'birthdate' => $birthdate,
                ])->save();

                if ($user->patientRecord !== null) {
                    $user->patientRecord->update([
                        'birthdate' => $birthdate,
                    ]);
                }

                if ($user->staffRecord !== null) {
                    $user->staffRecord->update([
                        'birthdate' => $birthdate,
                    ]);
                }
            }
        }
    }

    /**
     * @return array{first_name: string, middle_name: ?string, last_name: string, location: string, gender: string}
     */
    private function profileDataFor(string $group, int $index): array
    {
        $firstName = $this->firstNames[($index - 1) % count($this->firstNames)];
        $lastName = $this->lastNames[($index + strlen($group)) % count($this->lastNames)];
        $middleName = $index % 3 === 0
            ? null
            : $this->middleNames[($index + 1) % count($this->middleNames)];

        return [
            'first_name' => $firstName,
            'middle_name' => $middleName,
            'last_name' => $lastName,
            'location' => $this->locations[($index + 2) % count($this->locations)],
            'gender' => ['male', 'female', 'other'][$index % 3],
        ];
    }
}
