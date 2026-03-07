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
        if (isset($data['profile_picture']) && request()->hasFile('profile_picture')) {
            $file = request()->file('profile_picture');
            $filename = time() . '_' . $user->id . '.' . $file->extension();
            $path = $file->storeAs('profile_pictures', $filename, 'public');
            $data['profile_picture'] = '/storage/' . $path;
        }

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
