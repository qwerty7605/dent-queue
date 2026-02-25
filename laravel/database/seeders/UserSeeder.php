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
                'full_name' => 'System Admin',
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
                'full_name' => 'Medical Staff',
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
                'full_name' => 'Generic Patient',
                'password' => Hash::make('password123'),
                'phone_number' => '2222222222',
                'role_id' => $patientRole->id,
                'is_active' => true,
            ]
        );
    }
}
