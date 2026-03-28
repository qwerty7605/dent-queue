<?php

namespace App\Console\Commands;

use Illuminate\Console\Command;
use App\Models\Appointment;
use App\Models\PatientNotification;
use Carbon\Carbon;

class GenerateAppointmentReminders extends Command
{
    /**
     * The name and signature of the console command.
     *
     * @var string
     */
    protected $signature = 'appointments:generate-reminders';

    /**
     * The console command description.
     *
     * @var string
     */
    protected $description = 'Generate reminder notifications for upcoming eligible appointments';

    /**
     * Execute the console command.
     */
    public function handle()
    {
        $tomorrow = Carbon::tomorrow()->toDateString();

        $appointments = Appointment::with('service')
            ->where('appointment_date', $tomorrow)
            ->where('status', 'approved')
            ->get();

        $generatedCount = 0;

        foreach ($appointments as $appointment) {
            // Check if a reminder notification already exists for this appointment
            $exists = PatientNotification::where('appointment_id', $appointment->id)
                ->where('type', 'reminder')
                ->exists();

            if (!$exists) {
                // Format the time snippet
                $timeSlot = $appointment->time_slot;
                try {
                    $formattedTime = Carbon::createFromFormat('H:i:s', $timeSlot)->format('g:i A');
                } catch (\Exception $e) {
                    try {
                        $formattedTime = Carbon::createFromFormat('H:i', $timeSlot)->format('g:i A');
                    } catch (\Exception $e) {
                        $formattedTime = $timeSlot;
                    }
                }

                $serviceName = $appointment->service ? $appointment->service->name : 'your appointment';

                PatientNotification::create([
                    'patient_id' => $appointment->patient_id,
                    'appointment_id' => $appointment->id,
                    'type' => 'reminder',
                    'title' => 'Appointment Reminder',
                    'message' => "Reminder: You have an upcoming appointment for $serviceName tomorrow at $formattedTime.",
                ]);

                $generatedCount++;
            }
        }

        $this->info("Generated $generatedCount reminder notifications for $tomorrow.");
    }
}
