<?php

namespace App\Services;

use App\Models\User;
use App\Models\Role;
use Illuminate\Support\Facades\Hash;
use Illuminate\Validation\ValidationException;

class AuthService
{
    /**
     * Register a new user with the default Patient role.
     */
    public function register(array $data): User
    {
        $patientRole = Role::where('name', 'Patient')->first();

        return User::create([
            'full_name' => $data['full_name'],
            'email' => $data['email'],
            'password' => Hash::make($data['password']),
            'phone_number' => $data['phone_number'] ?? null,
            'role_id' => $patientRole->id,
            'is_active' => true,
        ]);
    }

    /**
     * Authenticate user credentials and return the user with their role.
     */
    public function login(array $credentials): User
    {
        $user = User::where('email', $credentials['email'])->with('role')->first();

        if (!$user || !Hash::check($credentials['password'], $user->password)) {
            throw ValidationException::withMessages([
                'email' => ['Invalid credentials.'],
            ]);
        }

        return $user;
    }

    /**
     * Logout the current user by revoking all tokens.
     */
    public function logout(User $user): void
    {
        $user->tokens()->delete();
    }
}
