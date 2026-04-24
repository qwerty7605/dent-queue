<?php

return [
    'admins' => (int) env('BULK_SEED_ADMIN_COUNT', 3),
    'staff' => (int) env('BULK_SEED_STAFF_COUNT', 15),
    'patients' => (int) env('BULK_SEED_PATIENT_COUNT', 220),
    'walk_in_patients' => (int) env('BULK_SEED_WALK_IN_PATIENT_COUNT', 40),
    'appointments' => (int) env('BULK_SEED_APPOINTMENT_COUNT', 50000),
    'appointments_per_day' => (int) env('BULK_SEED_APPOINTMENTS_PER_DAY', 40),
    'patient_notifications' => (int) env('BULK_SEED_PATIENT_NOTIFICATION_COUNT', 1200),
    'staff_notifications' => (int) env('BULK_SEED_STAFF_NOTIFICATION_COUNT', 450),
    'reports' => (int) env('BULK_SEED_REPORT_COUNT', 700),
    'past_days' => (int) env('BULK_SEED_PAST_DAYS', 180),
    'future_days' => (int) env('BULK_SEED_FUTURE_DAYS', 90),
    'default_password' => (string) env('BULK_SEED_DEFAULT_PASSWORD', 'password123'),
];
