<?php

namespace Database\Seeders;

use App\Models\Appointment;
use App\Models\Queue;
use App\Models\Role;
use App\Models\Service;
use App\Models\User;
use Illuminate\Database\Seeder;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\Hash;

class AppointmentQueueSeeder extends Seeder
{
    public function run(): void
    {
        $patientRole = Role::query()
            ->whereRaw('LOWER(name) = ?', ['patient'])
            ->first();

        if ($patientRole === null) {
            throw new \RuntimeException('Patient role not found. Run RoleSeeder first.');
        }

        $patients = $this->seedPatients((int) $patientRole->id);
        $serviceIdsByName = $this->resolveServiceIds();

        $queueDate = Carbon::today(config('app.timezone'))->toDateString();
        $templates = $this->todayAppointmentTemplates();

        $usedQueueNumbers = Queue::query()
            ->where('queue_date', $queueDate)
            ->pluck('queue_number')
            ->map(fn ($number) => (int) $number)
            ->all();

        $occupiedQueueNumbers = array_fill_keys($usedQueueNumbers, true);
        $nextQueueNumber = 1;

        foreach ($templates as $template) {
            $patient = $patients[$template['email']] ?? null;
            if ($patient === null) {
                continue;
            }

            $serviceId = $serviceIdsByName[$template['service_name']] ?? null;
            if ($serviceId === null) {
                continue;
            }

            $appointment = Appointment::query()->updateOrCreate(
                [
                    'patient_id' => (int) $patient->id,
                    'appointment_date' => $queueDate,
                    'time_slot' => $template['time_slot'],
                ],
                [
                    'service_id' => $serviceId,
                    'status' => $template['status'],
                    'notes' => $template['notes'],
                ],
            );

            $existingQueue = Queue::query()
                ->where('appointment_id', (int) $appointment->id)
                ->first();

            if ($existingQueue !== null) {
                $existingNumber = (int) $existingQueue->queue_number;
                $occupiedQueueNumbers[$existingNumber] = true;

                $existingQueue->update([
                    'queue_date' => $queueDate,
                    'is_called' => false,
                ]);

                continue;
            }

            while (isset($occupiedQueueNumbers[$nextQueueNumber])) {
                $nextQueueNumber++;
            }

            Queue::query()->create([
                'appointment_id' => (int) $appointment->id,
                'queue_date' => $queueDate,
                'queue_number' => $nextQueueNumber,
                'is_called' => false,
            ]);

            $occupiedQueueNumbers[$nextQueueNumber] = true;
            $nextQueueNumber++;
        }
    }

    /**
     * @return array<string, User>
     */
    private function seedPatients(int $patientRoleId): array
    {
        $password = Hash::make('password123');
        $patients = [
            ['first_name' => 'Generic', 'last_name' => 'Patient', 'email' => 'patient@example.com', 'username' => 'patient'],
            ['first_name' => 'Rhea', 'last_name' => 'Cruz', 'email' => 'seed.patient01@example.com', 'username' => 'seed_patient_01'],
            ['first_name' => 'Manika', 'last_name' => 'Lara', 'email' => 'seed.patient02@example.com', 'username' => 'seed_patient_02'],
            ['first_name' => 'Noel', 'last_name' => 'Santos', 'email' => 'seed.patient03@example.com', 'username' => 'seed_patient_03'],
            ['first_name' => 'Anne', 'last_name' => 'Torres', 'email' => 'seed.patient04@example.com', 'username' => 'seed_patient_04'],
            ['first_name' => 'Leah', 'last_name' => 'Ramos', 'email' => 'seed.patient05@example.com', 'username' => 'seed_patient_05'],
            ['first_name' => 'Mark', 'last_name' => 'Garcia', 'email' => 'seed.patient06@example.com', 'username' => 'seed_patient_06'],
            ['first_name' => 'Jude', 'last_name' => 'Mendoza', 'email' => 'seed.patient07@example.com', 'username' => 'seed_patient_07'],
            ['first_name' => 'Clare', 'last_name' => 'Navarro', 'email' => 'seed.patient08@example.com', 'username' => 'seed_patient_08'],
            ['first_name' => 'Miko', 'last_name' => 'Villanueva', 'email' => 'seed.patient09@example.com', 'username' => 'seed_patient_09'],
            ['first_name' => 'Lina', 'last_name' => 'Francisco', 'email' => 'seed.patient10@example.com', 'username' => 'seed_patient_10'],
            ['first_name' => 'Paul', 'last_name' => 'Domingo', 'email' => 'seed.patient11@example.com', 'username' => 'seed_patient_11'],
            ['first_name' => 'Tina', 'last_name' => 'Reyes', 'email' => 'seed.patient12@example.com', 'username' => 'seed_patient_12'],
        ];

        $result = [];

        foreach ($patients as $index => $patient) {
            $phone = sprintf('0917000%04d', $index + 1);

            $user = User::query()->updateOrCreate(
                ['email' => $patient['email']],
                [
                    'first_name' => $patient['first_name'],
                    'last_name' => $patient['last_name'],
                    'username' => $patient['username'],
                    'password' => $password,
                    'phone_number' => $phone,
                    'role_id' => $patientRoleId,
                    'is_active' => true,
                ],
            );

            $result[$patient['email']] = $user;
        }

        return $result;
    }

    /**
     * @return array<string, int>
     */
    private function resolveServiceIds(): array
    {
        $serviceNames = [
            'Dental Check-up',
            'Dental Panoramic X-ray',
            'Root Canal',
            'Teeth Cleaning',
            'Teeth Whitening',
            'Tooth Extraction',
        ];

        $services = Service::query()
            ->whereIn('name', $serviceNames)
            ->get(['id', 'name'])
            ->keyBy('name');

        $result = [];
        foreach ($serviceNames as $name) {
            if (!isset($services[$name])) {
                continue;
            }
            $result[$name] = (int) $services[$name]->id;
        }

        return $result;
    }

    /**
     * @return array<int, array{email: string, service_name: string, time_slot: string, status: string, notes: string}>
     */
    private function todayAppointmentTemplates(): array
    {
        return [
            ['email' => 'seed.patient01@example.com', 'service_name' => 'Root Canal', 'time_slot' => '08:00', 'status' => 'pending', 'notes' => 'First-time patient consultation.'],
            ['email' => 'seed.patient02@example.com', 'service_name' => 'Teeth Whitening', 'time_slot' => '08:30', 'status' => 'pending', 'notes' => 'Wants same-day whitening if possible.'],
            ['email' => 'seed.patient03@example.com', 'service_name' => 'Dental Panoramic X-ray', 'time_slot' => '09:00', 'status' => 'confirmed', 'notes' => 'Requested X-ray prior to treatment plan.'],
            ['email' => 'seed.patient04@example.com', 'service_name' => 'Dental Check-up', 'time_slot' => '09:30', 'status' => 'completed', 'notes' => 'Routine six-month check-up.'],
            ['email' => 'seed.patient05@example.com', 'service_name' => 'Teeth Cleaning', 'time_slot' => '10:00', 'status' => 'pending', 'notes' => 'Mild sensitivity reported.'],
            ['email' => 'seed.patient06@example.com', 'service_name' => 'Tooth Extraction', 'time_slot' => '10:30', 'status' => 'cancelled', 'notes' => 'Cancelled due to schedule conflict.'],
            ['email' => 'seed.patient07@example.com', 'service_name' => 'Root Canal', 'time_slot' => '11:00', 'status' => 'confirmed', 'notes' => 'Follow-up from previous pain complaint.'],
            ['email' => 'seed.patient08@example.com', 'service_name' => 'Dental Check-up', 'time_slot' => '11:30', 'status' => 'pending', 'notes' => 'General consultation.'],
            ['email' => 'seed.patient09@example.com', 'service_name' => 'Teeth Cleaning', 'time_slot' => '13:00', 'status' => 'pending', 'notes' => 'Prefers afternoon slot.'],
            ['email' => 'seed.patient10@example.com', 'service_name' => 'Dental Panoramic X-ray', 'time_slot' => '13:30', 'status' => 'pending', 'notes' => 'Orthodontic assessment request.'],
            ['email' => 'seed.patient11@example.com', 'service_name' => 'Teeth Whitening', 'time_slot' => '14:00', 'status' => 'confirmed', 'notes' => 'Second whitening session.'],
            ['email' => 'seed.patient12@example.com', 'service_name' => 'Tooth Extraction', 'time_slot' => '14:30', 'status' => 'pending', 'notes' => 'Wisdom tooth discomfort.'],
            ['email' => 'patient@example.com', 'service_name' => 'Dental Check-up', 'time_slot' => '15:00', 'status' => 'pending', 'notes' => 'Seeded sample appointment for dashboard testing.'],
        ];
    }
}
