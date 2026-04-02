<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\User;
use App\Models\Role;
use Illuminate\Http\Exceptions\HttpResponseException;
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
        $roleIds = Role::query()
            ->where(function ($query) {
                $query->whereRaw('LOWER(name) = ?', ['staff'])
                    ->orWhereRaw('LOWER(name) = ?', ['intern']);
            })
            ->pluck('id');

        if ($roleIds->isEmpty()) {
            return response()->json(['data' => []]);
        }

        $staff = User::with(['role', 'staffRecord'])
            ->whereIn('role_id', $roleIds)
            ->where('is_active', true)
            ->get();

        return response()->json(['data' => $staff]);
    }

    /**
     * Store a newly created staff member in storage.
     */
    public function store(Request $request): JsonResponse
    {
        $this->forbidInternWrites($request);

        $data = $request->validate([
            'first_name' => 'required|string|max:100',
            'middle_name' => 'nullable|string|max:100',
            'last_name' => 'required|string|max:100',
            'gender' => 'required|string|in:male,female,other',
            'address' => 'nullable|string|max:255',
            'contact_number' => ['required', 'regex:/^09\d{9}$/'],
            'role' => 'required|string|in:staff,intern',
            'username' => 'required|string|max:50|unique:users,username',
            'password' => 'required|string|min:8|confirmed',
        ], [
            'contact_number.regex' => 'Contact number must be a valid 11-digit mobile number starting with 09.',
        ]);

        $normalizedRole = Str::lower((string) $data['role']);
        $selectedRole = Role::whereRaw('LOWER(name) = ?', [$normalizedRole])->first();

        if (!$selectedRole) {
            $selectedRole = Role::create([
                'name' => Str::ucfirst($normalizedRole),
            ]);
        }

        // Generate a synthetic email if not provided, since the DB requires it
        $email = $data['username'] . '@system.' . $normalizedRole;

        $user = User::create([
            'first_name' => $data['first_name'],
            'middle_name' => $data['middle_name'] ?? null,
            'last_name' => $data['last_name'],
            'gender' => $data['gender'],
            'location' => $data['address'], // Using location column for address
            'phone_number' => $data['contact_number'],
            'username' => $data['username'],
            'email' => $email,
            'password' => $data['password'], // Will be hashed by User model casts
            'role_id' => $selectedRole->id,
            'is_active' => true,
        ]);

        $roleLabel = ucfirst(strtolower((string) $selectedRole->name));

        return response()->json([
            'message' => $roleLabel . ' account successfully created.',
            'data' => $user->load(['role', 'staffRecord']),
        ], 201);
    }

    /**
     * Remove the specified staff member from active view.
     */
    public function destroy(string $id): JsonResponse
    {
        $this->forbidInternWrites(request());

        $user = User::findOrFail($id);

        // Security check: ensure the user being deactivated is a staff or intern account.
        $roleName = $user->role ? Str::lower($user->role->name) : null;
        if (!in_array($roleName, ['staff', 'intern'], true)) {
             return response()->json(['message' => 'Only staff and intern accounts can be removed from this section.'], 403);
        }

        $user->is_active = false;
        $user->save();

        return response()->json([
            'message' => ucfirst((string) $roleName) . ' account successfully removed.'
        ]);
    }

    private function forbidInternWrites(Request $request): void
    {
        $roleName = strtolower((string) optional($request->user()?->role)->name);

        if ($roleName === 'intern') {
            throw new HttpResponseException(response()->json([
                'message' => 'Intern accounts have read-only access.',
            ], 403));
        }
    }
}
