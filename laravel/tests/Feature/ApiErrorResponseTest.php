<?php

namespace Tests\Feature;

use App\Models\Role;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class ApiErrorResponseTest extends TestCase
{
    use RefreshDatabase;

    public function test_api_validation_errors_are_returned_in_field_mapped_shape(): void
    {
        Role::create(['name' => 'Patient']);

        $response = $this->postJson('/api/v1/auth/register', [
            'first_name' => '',
            'last_name' => '',
            'email' => 'not-an-email',
            'username' => 'bad username',
            'password' => '123',
            'password_confirmation' => '456',
            'contact_number' => '123',
        ]);

        $response->assertStatus(422)
            ->assertJsonPath('type', 'validation_error')
            ->assertJsonPath('message', 'The given data was invalid.')
            ->assertJsonStructure([
                'type',
                'message',
                'errors' => [
                    'first_name',
                    'last_name',
                    'email',
                    'username',
                    'password',
                    'contact_number',
                ],
            ]);

        $this->assertIsArray($response->json('errors.first_name'));
        $this->assertIsArray($response->json('errors.username'));
    }

    public function test_api_non_field_errors_do_not_include_validation_error_map(): void
    {
        $response = $this->getJson('/api/v1/user');

        $response->assertStatus(401)
            ->assertJsonPath('type', 'authentication_error')
            ->assertJsonPath('message', 'Unauthenticated.')
            ->assertJsonMissingPath('errors');
    }
}
