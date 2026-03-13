<?php

namespace Database\Seeders;

use App\Models\Appointment;
use App\Models\PatientRecord;
use App\Models\Role;
use App\Models\Service;
use App\Models\User;
use Illuminate\Database\Seeder;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\Hash;

class PatientRecordPreviewSeeder extends Seeder
{
    public function run(): void
    {
        $patientRole = Role::query()
            ->whereRaw('LOWER(name) = ?', ['patient'])
            ->first();

        if ($patientRole === null) {
            throw new \RuntimeException('Patient role not found. Run RoleSeeder first.');
        }

        $services = Service::query()
            ->whereIn('name', [
                'Dental Check-up',
                'Dental Panoramic X-ray',
                'Root Canal',
                'Teeth Cleaning',
                'Teeth Whitening',
                'Tooth Extraction',
            ])
            ->get()
            ->keyBy('name');

        $today = Carbon::today((string) config('app.timezone', 'UTC'));

        foreach ($this->previewPatients() as $index => $patientData) {
            $user = User::query()->updateOrCreate(
                ['email' => (string) $patientData['email']],
                [
                    'first_name' => (string) $patientData['first_name'],
                    'middle_name' => $patientData['middle_name'],
                    'last_name' => (string) $patientData['last_name'],
                    'username' => (string) $patientData['username'],
                    'password' => Hash::make('password123'),
                    'phone_number' => (string) $patientData['phone_number'],
                    'birthdate' => (string) $patientData['birthdate'],
                    'location' => (string) $patientData['location'],
                    'gender' => (string) $patientData['gender'],
                    'role_id' => (int) $patientRole->id,
                    'is_active' => true,
                ],
            );

            $patientRecord = PatientRecord::resolveForUser($user);

            if (!blank($patientData['patient_id'] ?? null)) {
                $patientRecord->forceFill([
                    'patient_id' => (string) $patientData['patient_id'],
                ])->save();
            }

            foreach (($patientData['appointments'] ?? []) as $appointmentOffset => $appointmentData) {
                $service = $services->get((string) $appointmentData['service_name']);
                if ($service === null) {
                    continue;
                }

                $appointmentDate = $today
                    ->copy()
                    ->addDays((int) $appointmentData['day_offset'])
                    ->toDateString();

                Appointment::query()->updateOrCreate(
                    [
                        'patient_id' => (int) $patientRecord->id,
                        'appointment_date' => $appointmentDate,
                        'time_slot' => (string) $appointmentData['time_slot'],
                    ],
                    [
                        'service_id' => (int) $service->id,
                        'status' => (string) $appointmentData['status'],
                        'notes' => sprintf(
                            'Preview seed for records UI (%d-%d).',
                            $index + 1,
                            $appointmentOffset + 1,
                        ),
                    ],
                );
            }
        }
    }

    /**
     * @return array<int, array<string, mixed>>
     */
    private function previewPatients(): array
    {
        return [
            [
                'first_name' => 'Kyle',
                'middle_name' => null,
                'last_name' => 'Aldea',
                'email' => 'preview.kyle.aldea@example.com',
                'username' => 'preview_kyle_aldea',
                'phone_number' => '09169014483',
                'birthdate' => '1998-03-05',
                'location' => '111',
                'gender' => 'male',
                'patient_id' => 'SDQ-0003',
                'appointments' => [
                    [
                        'service_name' => 'Root Canal',
                        'day_offset' => 0,
                        'time_slot' => '09:00',
                        'status' => 'confirmed',
                    ],
                    [
                        'service_name' => 'Dental Check-up',
                        'day_offset' => -12,
                        'time_slot' => '10:00',
                        'status' => 'completed',
                    ],
                ],
            ],
            [
                'first_name' => 'Janine',
                'middle_name' => null,
                'last_name' => 'Cruz',
                'email' => 'preview.janine.cruz@example.com',
                'username' => 'preview_janine_cruz',
                'phone_number' => '09123456789',
                'birthdate' => '2000-11-16',
                'location' => '24 Mahogany Street',
                'gender' => 'female',
                'patient_id' => 'SDQ-0004',
                'appointments' => [
                    [
                        'service_name' => 'Dental Panoramic X-ray',
                        'day_offset' => 1,
                        'time_slot' => '08:30',
                        'status' => 'confirmed',
                    ],
                    [
                        'service_name' => 'Teeth Cleaning',
                        'day_offset' => 14,
                        'time_slot' => '10:00',
                        'status' => 'pending',
                    ],
                    [
                        'service_name' => 'Tooth Extraction',
                        'day_offset' => -31,
                        'time_slot' => '11:00',
                        'status' => 'completed',
                    ],
                ],
            ],
            [
                'first_name' => 'Bianca',
                'middle_name' => null,
                'last_name' => 'Soriano',
                'email' => 'preview.bianca.soriano@example.com',
                'username' => 'preview_bianca_soriano',
                'phone_number' => '09181234567',
                'birthdate' => '1996-04-09',
                'location' => '17 Sampaguita Street',
                'gender' => 'female',
                'patient_id' => 'SDQ-0006',
                'appointments' => [
                    [
                        'service_name' => 'Dental Check-up',
                        'day_offset' => 5,
                        'time_slot' => '11:30',
                        'status' => 'pending',
                    ],
                    [
                        'service_name' => 'Teeth Cleaning',
                        'day_offset' => -40,
                        'time_slot' => '09:30',
                        'status' => 'completed',
                    ],
                    [
                        'service_name' => 'Dental Panoramic X-ray',
                        'day_offset' => -82,
                        'time_slot' => '14:00',
                        'status' => 'completed',
                    ],
                ],
            ],
            [
                'first_name' => 'Gabriel',
                'middle_name' => null,
                'last_name' => 'Mercado',
                'email' => 'preview.gabriel.mercado@example.com',
                'username' => 'preview_gabriel_mercado',
                'phone_number' => '09668880000',
                'birthdate' => '1987-08-11',
                'location' => '72 Laurel Compound',
                'gender' => 'male',
                'patient_id' => 'SDQ-0011',
                'appointments' => [
                    [
                        'service_name' => 'Root Canal',
                        'day_offset' => 8,
                        'time_slot' => '10:30',
                        'status' => 'confirmed',
                    ],
                    [
                        'service_name' => 'Tooth Extraction',
                        'day_offset' => -24,
                        'time_slot' => '15:30',
                        'status' => 'completed',
                    ],
                    [
                        'service_name' => 'Dental Check-up',
                        'day_offset' => -189,
                        'time_slot' => '13:30',
                        'status' => 'completed',
                    ],
                ],
            ],
            [
                'first_name' => 'Francesca',
                'middle_name' => null,
                'last_name' => 'Lim',
                'email' => 'preview.francesca.lim@example.com',
                'username' => 'preview_francesca_lim',
                'phone_number' => '09557779999',
                'birthdate' => '1999-01-21',
                'location' => '301 Orchid Homes',
                'gender' => 'female',
                'patient_id' => 'SDQ-0010',
                'appointments' => [
                    [
                        'service_name' => 'Dental Panoramic X-ray',
                        'day_offset' => 11,
                        'time_slot' => '15:00',
                        'status' => 'pending',
                    ],
                ],
            ],
        ];
    }
}
