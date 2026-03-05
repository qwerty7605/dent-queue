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
        // Use case-insensitive lookup to be safe
        $adminRole = Role::where('name', 'admin')->orWhere('name', 'Admin')->first();
        $staffRole = Role::where('name', 'staff')->orWhere('name', 'Staff')->first();
        $patientRole = Role::where('name', 'patient')->orWhere('name', 'Patient')->first();

        // Ensure roles exist before seeding users
        if (!$adminRole || !$staffRole || !$patientRole) {
            throw new \Exception("Roles not found. Please run RoleSeeder first.");
        }

        // Admin Account
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

        // Staff Account
        User::updateOrCreate(
            ['email' => 'staff@example.com'],
            [
                'first_name' => 'Medical',
                'last_name' => 'Staff',
                'username' => 'staff',
                'password' => Hash::make('password123'),
                'phone_number' => '1111111111',
                'role_id' => $staffRole->id,
                'is_active' => true,
            ]
        );

        // Patient Account
        User::updateOrCreate(
            ['email' => 'patient@example.com'],
            [
                'first_name' => 'Generic',
                'last_name' => 'Patient',
                'username' => 'patient',
                'password' => Hash::make('password123'),
                'phone_number' => '2222222222',
                'role_id' => $patientRole->id,
                'is_active' => true,
            ]
        );
    }
}
