<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Services\UserService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Str;
use Illuminate\Validation\ValidationException;

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
        $this->ensureUsernameChangeIsConfirmed($request, $payload, (string) $user->username);
        $this->ensurePasswordChangeIsConfirmed($request, $payload);
        unset($payload['current_password'], $payload['password_confirmation']);
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
            'first_name' => ['sometimes', 'required', 'string', 'max:30', 'regex:/^[\pL\s]+$/u'],
            'last_name' => ['sometimes', 'required', 'string', 'max:30', 'regex:/^[\pL\s]+$/u'],
            'gender' => ['sometimes', 'nullable', 'string', 'in:male,female,other'],
            'phone_number' => ['sometimes', 'nullable', 'regex:/^09\d{9}$/'],
            'contact_number' => ['sometimes', 'nullable', 'regex:/^09\d{9}$/'],
            'username' => ['sometimes', 'required', 'string', 'max:30', 'unique:users,username,' . $userId],
            'email' => ['sometimes', 'required', 'email', 'max:255', 'unique:users,email,' . $userId],
            'password' => ['sometimes', 'required', 'string', 'min:8', 'max:30', 'confirmed'],
            'password_confirmation' => ['required_with:password', 'string'],
            'current_password' => ['sometimes', 'string'],
        ], [
            'phone_number.regex' => 'Contact number must be a valid 11-digit mobile number starting with 09.',
            'contact_number.regex' => 'Contact number must be a valid 11-digit mobile number starting with 09.',
            'first_name.regex' => 'First name may only contain letters and spaces.',
            'last_name.regex' => 'Last name may only contain letters and spaces.',
            'username.unique' => 'The requested username is already taken. Please choose another one.',
        ]);
    }

    private function ensureUsernameChangeIsConfirmed(Request $request, array $payload, string $currentUsername): void
    {
        if (! array_key_exists('username', $payload) || $payload['username'] === $currentUsername) {
            return;
        }

        $request->validate([
            'current_password' => ['required', 'string'],
        ], [
            'current_password.required' => 'Confirm your password to change your username.',
        ]);

        if (! Hash::check((string) $request->input('current_password'), (string) $request->user()->password)) {
            throw ValidationException::withMessages([
                'current_password' => ['The password you entered is incorrect.'],
            ]);
        }
    }

    private function ensurePasswordChangeIsConfirmed(Request $request, array $payload): void
    {
        if (! array_key_exists('password', $payload)) {
            return;
        }

        $request->validate([
            'current_password' => ['required', 'string'],
        ], [
            'current_password.required' => 'Enter your current password to change your password.',
        ]);

        if (! Hash::check((string) $request->input('current_password'), (string) $request->user()->password)) {
            throw ValidationException::withMessages([
                'current_password' => ['The password you entered is incorrect.'],
            ]);
        }
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
