<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Services\UserService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Str;

class StaffProfileController extends Controller
{
    public function __construct(protected UserService $userService)
    {
    }

    public function update(Request $request, string $id): JsonResponse
    {
        $user = $request->user();

        if ((int) $user->id !== (int) $id) {
            return response()->json([
                'message' => 'Unauthorized to update this profile.',
            ], 403);
        }

        $payload = $this->validatePayload($request);
        $payload = $this->applyAliases($payload);
        $updatedUser = $this->userService->updateProfile($user, $payload);

        return response()->json([
            'message' => 'Profile updated successfully.',
            'user' => $updatedUser->fresh()->load('role'),
        ]);
    }

    private function validatePayload(Request $request): array
    {
        $this->normalizePayload($request);

        return $request->validate([
            'first_name' => ['sometimes', 'required', 'string', 'max:100'],
            'middle_name' => ['sometimes', 'nullable', 'string', 'max:100'],
            'last_name' => ['sometimes', 'required', 'string', 'max:100'],
            'birthdate' => ['sometimes', 'nullable', 'date', 'before_or_equal:today'],
            'location' => ['sometimes', 'nullable', 'string', 'max:255'],
            'address' => ['sometimes', 'nullable', 'string', 'max:255'],
            'gender' => ['sometimes', 'nullable', 'string', 'in:male,female,other'],
            'phone_number' => ['sometimes', 'nullable', 'regex:/^09\d{9}$/'],
            'contact_number' => ['sometimes', 'nullable', 'regex:/^09\d{9}$/'],
            'profile_picture' => ['sometimes', 'nullable', 'image', 'mimes:jpeg,png,jpg,gif', 'max:2048'],
        ], [
            'birthdate.before_or_equal' => 'Birthdate cannot be in the future.',
            'phone_number.regex' => 'Contact number must be a valid 11-digit mobile number.',
            'contact_number.regex' => 'Contact number must be a valid 11-digit mobile number.',
            'profile_picture.image' => 'The profile picture must be an image file.',
            'profile_picture.max' => 'The profile picture must not be greater than 2MB.',
        ]);
    }

    private function normalizePayload(Request $request): void
    {
        if ($request->filled('gender')) {
            $request->merge([
                'gender' => Str::lower((string) $request->input('gender')),
            ]);
        }
    }

    private function applyAliases(array $payload): array
    {
        if (array_key_exists('address', $payload) && !array_key_exists('location', $payload)) {
            $payload['location'] = $payload['address'];
        }

        if (array_key_exists('contact_number', $payload) && !array_key_exists('phone_number', $payload)) {
            $payload['phone_number'] = $payload['contact_number'];
        }

        return $payload;
    }
}
