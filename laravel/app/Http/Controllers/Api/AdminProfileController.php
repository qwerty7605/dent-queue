<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Services\UserService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Str;

class AdminProfileController extends Controller
{
    public function __construct(protected UserService $userService)
    {
    }

    public function update(Request $request): JsonResponse
    {
        $user = $request->user();

        // Security check, ensure the user is an admin
        if (! $user->role || Str::lower($user->role->name) !== 'admin') {
            return response()->json([
                'message' => 'Unauthorized. Must be an admin to perform this action.',
            ], 403);
        }

        $payload = $this->validatePayload($request, $user->id);
        $payload = $this->applyAliases($payload);

        // Handle password hashing if provided
        if (isset($payload['password'])) {
            $payload['password'] = Hash::make($payload['password']);
        }

        $updatedUser = $this->userService->updateProfile($user, $payload);

        return response()->json([
            'message' => 'Profile updated successfully.',
            'user' => $updatedUser->fresh()->load('role'),
        ]);
    }

    private function validatePayload(Request $request, int $userId): array
    {
        if ($request->filled('gender')) {
            $request->merge([
                'gender' => Str::lower((string) $request->input('gender')),
            ]);
        }

        return $request->validate([
            'first_name' => ['sometimes', 'required', 'string', 'max:100'],
            'last_name' => ['sometimes', 'required', 'string', 'max:100'],
            'gender' => ['sometimes', 'nullable', 'string', 'in:male,female,other'],
            'birthdate' => ['sometimes', 'nullable', 'date', 'before_or_equal:today'],
            'phone_number' => ['sometimes', 'nullable', 'regex:/^09\d{9}$/'],
            'contact_number' => ['sometimes', 'nullable', 'regex:/^09\d{9}$/'],
            'username' => ['sometimes', 'required', 'string', 'max:255', 'unique:users,username,' . $userId],
            'password' => ['sometimes', 'required', 'string', 'min:8'],
        ], [
            'birthdate.before_or_equal' => 'Birthdate cannot be in the future.',
            'phone_number.regex' => 'Contact number must be a valid 11-digit mobile number starting with 09.',
            'contact_number.regex' => 'Contact number must be a valid 11-digit mobile number starting with 09.',
            'username.unique' => 'The requested username is already taken. Please choose another one.',
        ]);
    }

    private function applyAliases(array $payload): array
    {
        if (array_key_exists('contact_number', $payload) && !array_key_exists('phone_number', $payload)) {
            $payload['phone_number'] = $payload['contact_number'];
            unset($payload['contact_number']);
        }

        return $payload;
    }
}
