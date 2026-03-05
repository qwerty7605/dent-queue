<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Services\AuthService;
use Illuminate\Http\Request;

class AuthController extends Controller
{
    protected $authService;

    public function __construct(AuthService $authService)
    {
        $this->authService = $authService;
    }

    public function register(Request $request)
    {
        $data = $request->validate([
            'first_name' => 'required|string|max:100',
            'middle_name' => 'nullable|string|max:100',
            'last_name' => 'required|string|max:100',
            'username' => 'required|string|max:50|unique:users,username',
            'email' => 'required|string|email|max:255|unique:users,email',
            'password' => 'required|string|min:8|confirmed',
            'location' => 'nullable|string|max:255',
            'gender' => 'nullable|string|in:male,female,other',
        ]);

        $user = $this->authService->register($data);
        $token = $user->createToken('auth_token')->plainTextToken;

        return response()->json([
            'user' => $user->load('role'),
            'access_token' => $token,
            'token_type' => 'Bearer',
        ], 201);
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
}
