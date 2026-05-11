<?php

namespace Database\Seeders;

use App\Models\User;
use App\Models\Role;
use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\Hash;

class UserSeeder extends Seeder
{
    public function run(): void
    {
        $adminRole = Role::firstOrCreate(['name' => 'Admin']);
        $staffRole = Role::firstOrCreate(['name' => 'Staff']);
        $patientRole = Role::firstOrCreate(['name' => 'Patient']);

        User::updateOrCreate(
            ['email' => 'admin@example.com'],
            [
                'first_name' => 'System',
                'last_name' => 'Admin',
                'username' => 'admin',
                'password' => Hash::make('password123'),
                'phone_number' => '0000000000',
                'role_id' => $adminRole->id,
                'is_active' => true,
            ]
        );

        User::updateOrCreate(
            ['email' => 'staff@example.com'],
            [
                'first_name' => 'Clinic',
                'last_name' => 'Staff',
                'username' => 'staff',
                'password' => Hash::make('password123'),
                'phone_number' => '09170000001',
                'location' => 'Main Clinic',
                'gender' => 'female',
                'role_id' => $staffRole->id,
                'is_active' => true,
            ]
        );

        User::updateOrCreate(
            ['email' => 'patient@example.com'],
            [
                'first_name' => 'Sample',
                'last_name' => 'Patient',
                'username' => 'patient',
                'password' => Hash::make('password123'),
                'phone_number' => '09170000002',
                'location' => 'Sample Address',
                'gender' => 'male',
                'role_id' => $patientRole->id,
                'is_active' => true,
            ]
        );
    }
}
