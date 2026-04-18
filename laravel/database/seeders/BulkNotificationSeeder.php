<?php

namespace Database\Seeders;

use App\Models\Appointment;
use App\Models\PatientNotification;
use App\Models\StaffNotification;
use App\Models\User;
use Database\Seeders\Concerns\InteractsWithBulkSeedData;
use Illuminate\Database\Seeder;
use Illuminate\Support\Carbon;

class BulkNotificationSeeder extends Seeder
{
    use InteractsWithBulkSeedData;

    public function run(): void
    {
        $appointments = Appointment::query()
            ->with(['patient', 'queue'])
            ->where('notes', 'like', $this->bulkSeedMarker() . '%')
            ->get();

        $registeredAppointments = $appointments
            ->filter(fn (Appointment $appointment): bool => (int) ($appointment->patient?->user_id ?? 0) > 0)
            ->values();

        $staffRecipients = User::query()
            ->where('email', 'like', 'bulk.admin.%@example.com')
            ->orWhere('email', 'like', 'bulk.staff.%@example.com')
            ->get(['id', 'first_name']);

        $patientTarget = max(0, (int) $this->bulkSeedConfig('patient_notifications', 1200));
        $staffTarget = max(0, (int) $this->bulkSeedConfig('staff_notifications', 450));

        $this->seedPatientNotifications($registeredAppointments, $patientTarget);
        $this->seedStaffNotifications($appointments->values(), $staffRecipients, $staffTarget);
    }

    private function seedPatientNotifications($appointments, int $target): void
    {
        if ($target === 0 || $appointments->isEmpty()) {
            return;
        }

        $created = 0;
        $cursor = 0;
        $types = [
            'appointment_created',
            'approved',
            'appointment_update',
            'reminder',
            'queue_next_up',
            'queue_now_serving',
        ];

        while ($created < $target) {
            /** @var Appointment $appointment */
            $appointment = $appointments[$cursor % $appointments->count()];
            $type = $types[$cursor % count($types)];
            $cursor++;

            if (! $this->patientNotificationEligible($appointment, $type)) {
                continue;
            }

            $createdAt = $this->notificationTimestampForAppointment($appointment, $type);

            PatientNotification::query()->create([
                'patient_id' => (int) $appointment->patient_id,
                'appointment_id' => (int) $appointment->id,
                'type' => $type,
                'title' => $this->patientNotificationTitle($type),
                'message' => $this->patientNotificationMessage($appointment, $type),
                'read_at' => random_int(1, 100) <= 45 ? $createdAt->copy()->addHours(random_int(1, 48)) : null,
                'created_at' => $createdAt,
                'updated_at' => $createdAt,
            ]);

            $created++;
        }
    }

    private function seedStaffNotifications($appointments, $staffRecipients, int $target): void
    {
        if ($target === 0 || $appointments->isEmpty() || $staffRecipients->isEmpty()) {
            return;
        }

        $created = 0;
        $cursor = 0;

        while ($created < $target) {
            /** @var Appointment $appointment */
            $appointment = $appointments[$cursor % $appointments->count()];
            $recipient = $staffRecipients[$cursor % $staffRecipients->count()];
            $cursor++;

            $createdAt = $this->notificationTimestampForAppointment($appointment, 'staff_appointment_created');

            StaffNotification::query()->create([
                'user_id' => (int) $recipient->id,
                'appointment_id' => (int) $appointment->id,
                'type' => 'staff_appointment_created',
                'title' => 'Bulk appointment activity',
                'message' => sprintf(
                    'Seeded appointment #%d for %s is scheduled on %s at %s.',
                    (int) $appointment->id,
                    (string) ($appointment->patient?->first_name ?? 'Patient'),
                    (string) $appointment->appointment_date,
                    (string) $appointment->time_slot,
                ),
                'read_at' => random_int(1, 100) <= 35 ? $createdAt->copy()->addHours(random_int(1, 36)) : null,
                'created_at' => $createdAt,
                'updated_at' => $createdAt,
            ]);

            $created++;
        }
    }

    private function patientNotificationEligible(Appointment $appointment, string $type): bool
    {
        return match ($type) {
            'approved' => in_array($appointment->status, ['confirmed', 'completed'], true),
            'reminder' => $appointment->status === 'confirmed',
            'queue_next_up', 'queue_now_serving' => $appointment->queue !== null,
            default => true,
        };
    }

    private function notificationTimestampForAppointment(Appointment $appointment, string $type): Carbon
    {
        $appointmentTime = Carbon::parse(
            sprintf('%s %s', $appointment->appointment_date, $appointment->time_slot),
            (string) config('app.timezone', 'UTC'),
        );

        return match ($type) {
            'appointment_created', 'staff_appointment_created' => Carbon::parse((string) $appointment->created_at),
            'approved', 'appointment_update' => Carbon::parse((string) $appointment->created_at)->addHours(random_int(4, 48)),
            'reminder' => $appointmentTime->copy()->subHours(random_int(12, 48)),
            'queue_next_up' => $appointmentTime->copy()->subMinutes(random_int(15, 45)),
            'queue_now_serving' => $appointmentTime->copy()->subMinutes(random_int(0, 15)),
            default => Carbon::parse((string) $appointment->created_at),
        };
    }

    private function patientNotificationTitle(string $type): string
    {
        return match ($type) {
            'appointment_created' => 'Appointment booked',
            'approved' => 'Appointment approved',
            'appointment_update' => 'Appointment updated',
            'reminder' => 'Upcoming appointment reminder',
            'queue_next_up' => 'Queue update',
            'queue_now_serving' => 'Now serving',
            default => 'Appointment notice',
        };
    }

    private function patientNotificationMessage(Appointment $appointment, string $type): string
    {
        return match ($type) {
            'appointment_created' => sprintf(
                'Your appointment for %s at %s has been added to the clinic schedule.',
                (string) $appointment->appointment_date,
                (string) $appointment->time_slot,
            ),
            'approved' => sprintf(
                'Your appointment on %s has been approved by the clinic.',
                (string) $appointment->appointment_date,
            ),
            'appointment_update' => sprintf(
                'Please review the latest schedule details for appointment #%d.',
                (int) $appointment->id,
            ),
            'reminder' => sprintf(
                'Reminder: you are scheduled on %s at %s.',
                (string) $appointment->appointment_date,
                (string) $appointment->time_slot,
            ),
            'queue_next_up' => sprintf(
                'Queue update: you are next after queue #%d.',
                max(1, ((int) ($appointment->queue?->queue_number ?? 1)) - 1),
            ),
            'queue_now_serving' => sprintf(
                'Queue update: queue #%d is now being served.',
                (int) ($appointment->queue?->queue_number ?? 0),
            ),
            default => 'Clinic update available.',
        };
    }
}
