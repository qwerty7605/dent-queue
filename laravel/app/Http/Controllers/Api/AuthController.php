<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Services\AuthService;
use Illuminate\Http\Request;
use Illuminate\Validation\Rule;

class AuthController extends Controller
{
    protected $authService;

    public function __construct(AuthService $authService)
    {
        $this->authService = $authService;
    }

    public function register(Request $request)
    {
        $data = $request->validate(
            $this->registrationRules(),
            $this->registrationMessages(),
        );

        if (array_key_exists('contact_number', $data) && !array_key_exists('phone_number', $data)) {
            $data['phone_number'] = $data['contact_number'];
        }

        $user = $this->authService->register($data);
        $token = $user->createToken('auth_token')->plainTextToken;

        return response()->json([
            'user' => $user->load('role'),
            'access_token' => $token,
            'token_type' => 'Bearer',
        ], 201);
    }

    public function validateRegistration(Request $request)
    {
        $payload = $request->validate([
            'fields' => ['required', 'array', 'min:1'],
            'fields.*' => ['required', 'string', Rule::in(array_keys($this->registrationRules()))],
        ]);

        $allRules = $this->registrationRules();
        $rules = [];

        foreach ($payload['fields'] as $field) {
            $rules[$field] = $allRules[$field];
        }

        $request->validate($rules, $this->registrationMessages());

        return response()->json([
            'valid' => true,
            'message' => 'Registration fields are valid.',
        ]);
    }

    public function login(Request $request)
    {
        // allow login with either email or username
        $credentials = $request->validate([
            'email' => 'sometimes|required|string|email',
            'username' => 'sometimes|required|string',
            'password' => 'required|string',
        ]);

        // choose field for lookup
        if (isset($credentials['username'])) {
            $lookup = ['username' => $credentials['username']];
        }
        else {
            $lookup = ['email' => $credentials['email']];
        }

        $lookup['password'] = $credentials['password'];

        $user = $this->authService->login($lookup);
        $token = $user->createToken('auth_token')->plainTextToken;

        return response()->json([
            'user' => $user->load('role'),
            'access_token' => $token,
            'token_type' => 'Bearer',
        ]);
    }

    public function logout(Request $request)
    {
        $this->authService->logout($request->user());

        return response()->json([
            'message' => 'Successfully logged out'
        ]);
    }

    private function registrationRules(): array
    {
        return [
            'first_name' => ['required', 'string', 'max:30', 'regex:/^[\pL\s]+$/u'],
            'middle_name' => ['nullable', 'string', 'max:30', 'regex:/^[\pL\s]+$/u'],
            'last_name' => ['required', 'string', 'max:30', 'regex:/^[\pL\s]+$/u'],
            'username' => ['required', 'string', 'max:50', 'regex:/^[A-Za-z0-9._-]+$/', 'unique:users,username'],
            'email' => 'required|string|email|max:255|unique:users,email',
            'password' => 'required|string|min:8|confirmed',
            'password_confirmation' => ['required_with:password', 'same:password'],
            'phone_number' => ['sometimes', 'nullable', 'regex:/^09\d{9}$/'],
            'contact_number' => ['sometimes', 'nullable', 'regex:/^09\d{9}$/'],
            'location' => 'nullable|string|max:255',
            'gender' => 'nullable|string|in:male,female,other',
            'terms_accepted' => 'accepted',
        ];
    }

    private function registrationMessages(): array
    {
        return [
            'phone_number.regex' => 'Contact number must be a valid 11-digit mobile number starting with 09.',
            'contact_number.regex' => 'Contact number must be a valid 11-digit mobile number starting with 09.',
            'username.regex' => 'Username may only contain letters, numbers, dots, hyphens, and underscores.',
            'first_name.regex' => 'First name may only contain letters and spaces.',
            'middle_name.regex' => 'Middle name may only contain letters and spaces.',
            'last_name.regex' => 'Last name may only contain letters and spaces.',
            'terms_accepted.accepted' => 'You must accept the Terms and Conditions before creating an account.',
        ];
    }
}
