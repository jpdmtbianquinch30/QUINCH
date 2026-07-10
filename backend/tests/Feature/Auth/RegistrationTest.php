<?php

namespace Tests\Feature\Auth;

use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class RegistrationTest extends TestCase
{
    use RefreshDatabase;

    private array $validPayload = [
        'phone_number' => '+221771234567',
        'full_name' => 'Fatou Diop',
        'username' => 'fatou_diop',
        'password' => 'Password1',
        'password_confirmation' => 'Password1',
    ];

    public function test_register_creates_user_and_returns_token(): void
    {
        $response = $this->postJson('/api/v1/auth/register', $this->validPayload);

        $response->assertCreated()
            ->assertJsonStructure(['message', 'user', 'token', 'otp_sent'])
            ->assertJsonPath('user.phone_number', '+221771234567')
            ->assertJsonPath('user.username', 'fatou_diop');

        $this->assertDatabaseHas('users', [
            'phone_number' => '+221771234567',
            'username' => 'fatou_diop',
            'role' => 'user',
        ]);
    }

    public function test_register_returns_demo_otp_in_testing_environment(): void
    {
        // En environnement de test, l'OTP est exposé pour permettre de tester
        // le flux de vérification sans dépendre d'un vrai envoi SMS.
        $response = $this->postJson('/api/v1/auth/register', $this->validPayload);

        $response->assertCreated()->assertJsonStructure(['demo_otp']);
    }

    public function test_register_rejects_duplicate_phone_number(): void
    {
        User::factory()->create(['phone_number' => '+221771234567']);

        $response = $this->postJson('/api/v1/auth/register', $this->validPayload);

        $response->assertUnprocessable()
            ->assertJsonValidationErrors(['phone_number']);
    }

    public function test_register_rejects_invalid_phone_format(): void
    {
        $response = $this->postJson('/api/v1/auth/register', [
            ...$this->validPayload,
            'phone_number' => '0771234567', // manque le +221
        ]);

        $response->assertUnprocessable()
            ->assertJsonValidationErrors(['phone_number']);
    }

    public function test_register_rejects_weak_password(): void
    {
        $response = $this->postJson('/api/v1/auth/register', [
            ...$this->validPayload,
            'password' => 'weakpassword', // pas de majuscule ni de chiffre
            'password_confirmation' => 'weakpassword',
        ]);

        $response->assertUnprocessable()
            ->assertJsonValidationErrors(['password']);
    }

    public function test_register_rejects_mismatched_password_confirmation(): void
    {
        $response = $this->postJson('/api/v1/auth/register', [
            ...$this->validPayload,
            'password_confirmation' => 'Different1',
        ]);

        $response->assertUnprocessable()
            ->assertJsonValidationErrors(['password']);
    }
}
