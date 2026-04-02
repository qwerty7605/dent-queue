<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Services\UserService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Str;

class PatientProfileController extends Controller
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
            'location' => ['sometimes', 'nullable', 'string', 'max:255'],
            'address' => ['sometimes', 'nullable', 'string', 'max:255'],
            'gender' => ['sometimes', 'nullable', 'string', 'in:male,female,other'],
            'phone_number' => ['sometimes', 'nullable', 'regex:/^09\d{9}$/'],
            'contact_number' => ['sometimes', 'nullable', 'regex:/^09\d{9}$/'],
            'profile_picture' => ['sometimes', 'nullable', 'image', 'mimes:jpeg,png,jpg,gif', 'max:2048'],
        ], [
            'phone_number.regex' => 'Contact number must be a valid 11-digit mobile number starting with 09.',
            'contact_number.regex' => 'Contact number must be a valid 11-digit mobile number starting with 09.',
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

        if ($request->has('address') && !$request->has('location')) {
            $request->merge([
                'location' => $request->input('address'),
            ]);
        }

        if ($request->has('contact_number') && !$request->has('phone_number')) {
            $request->merge([
                'phone_number' => $request->input('contact_number'),
            ]);
        }
    }
}
