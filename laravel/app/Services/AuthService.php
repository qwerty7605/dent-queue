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
            'first_name' => $data['first_name'],
            'middle_name' => $data['middle_name'] ?? null,
            'last_name' => $data['last_name'],
            'username' => $data['username'],
            'email' => $data['email'],
            'location' => $data['location'] ?? null,
            'gender' => $data['gender'] ?? null,
            'password' => Hash::make($data['password']),
            'role_id' => $patientRole->id,
            'is_active' => true,
        ]);
    }

    /**
     * Authenticate user credentials and return the user with their role.
     */
    public function login(array $credentials): User
    {
        $query = User::query();
        if (isset($credentials['username'])) {
            $query->where('username', $credentials['username']);
        } elseif (isset($credentials['email'])) {
            $query->where('email', $credentials['email']);
        }
        $user = $query->with('role')->first();

        if (!$user || !Hash::check($credentials['password'], $user->password)) {
            throw ValidationException::withMessages([
                'credentials' => ['Invalid credentials.'],
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
