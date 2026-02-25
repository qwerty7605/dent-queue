<?php

namespace App\Services;

use App\Models\User;

class UserService
{
    /**
     * Get all users with their roles.
     */
    public function getAllUsers()
    {
        return User::with('role')->get();
    }

    /**
     * Update user profile.
     */
    public function updateProfile(User $user, array $data)
    {
        $user->update($data);
        return $user;
    }

    /**
     * Deactivate a user.
     */
    public function deactivate(User $user)
    {
        $user->update(['is_active' => false]);
        return $user;
    }
}
