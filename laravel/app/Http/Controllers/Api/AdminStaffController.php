<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\User;
use App\Models\Role;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Str;

class AdminStaffController extends Controller
{
    /**
     * Display a listing of the staff members.
     */
    public function index(): JsonResponse
    {
        $staffRole = Role::whereRaw('LOWER(name) = ?', ['staff'])->first();

        if (!$staffRole) {
            return response()->json(['data' => []]);
        }

        $staff = User::with('staffRecord')
            ->where('role_id', $staffRole->id)
            ->where('is_active', true)
            ->get();

        return response()->json(['data' => $staff]);
    }

    /**
     * Store a newly created staff member in storage.
     */
    public function store(Request $request): JsonResponse
    {
        $data = $request->validate([
            'first_name' => 'required|string|max:100',
            'last_name' => 'required|string|max:100',
            'birthdate' => 'required|date',
            'gender' => 'required|string|in:male,female,other',
            'address' => 'nullable|string|max:255',
            'contact_number' => 'required|string', // Alias for phone_number
            'username' => 'required|string|max:50|unique:users,username',
            'password' => 'required|string|min:8|confirmed',
        ]);

        $staffRole = Role::whereRaw('LOWER(name) = ?', ['staff'])->first();

        if (!$staffRole) {
            return response()->json(['message' => 'Staff role not found.'], 500);
        }

        // Generate a synthetic email if not provided, since the DB requires it
        $email = $data['username'] . '@system.staff';

        $user = User::create([
            'first_name' => $data['first_name'],
            'last_name' => $data['last_name'],
            'birthdate' => $data['birthdate'],
            'gender' => $data['gender'],
            'location' => $data['address'], // Using location column for address
            'phone_number' => $data['contact_number'],
            'username' => $data['username'],
            'email' => $email,
            'password' => $data['password'], // Will be hashed by User model casts
            'role_id' => $staffRole->id,
            'is_active' => true,
        ]);

        return response()->json([
            'message' => 'Staff account successfully created.',
            'data' => $user->load(['role', 'staffRecord']),
        ], 201);
    }

    /**
     * Remove the specified staff member from active view.
     */
    public function destroy(string $id): JsonResponse
    {
        $user = User::findOrFail($id);

        // Security check: ensure the user being deactivated is a staff member
        if (!$user->role || Str::lower($user->role->name) !== 'staff') {
             return response()->json(['message' => 'Only staff accounts can be removed from this section.'], 403);
        }

        $user->is_active = false;
        $user->save();

        return response()->json([
            'message' => 'Staff account successfully removed.'
        ]);
    }
}
