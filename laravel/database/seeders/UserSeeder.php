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
        $adminRole = Role::where('name', 'admin')->orWhere('name', 'Admin')->first();

        if (!$adminRole) {
            throw new \Exception("Admin role not found. Please run RoleSeeder first.");
        }

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
    }
}
