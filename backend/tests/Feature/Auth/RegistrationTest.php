<?php

namespace Tests\Feature\Auth;

use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Mail;
use Tests\TestCase;

class RegistrationTest extends TestCase
{
    use RefreshDatabase;

    private array $validPayload = [
        'email' => 'fatou@example.com',
        'full_name' => 'Fatou Diop',
        'username' => 'fatou_diop',
        'password' => 'Password1',
        'password_confirmation' => 'Password1',
        'accept_terms' => true,
    ];

    public function test_register_creates_user_and_returns_token(): void
    {
        $response = $this->postJson('/api/v1/auth/register', $this->validPayload);

        $response->assertCreated()
            ->assertJsonStructure(['message', 'user', 'token'])
            ->assertJsonPath('user.email', 'fatou@example.com')
            ->assertJsonPath('user.username', 'fatou_diop')
            ->assertJsonPath('user.phone_number', null);

        $this->assertDatabaseHas('users', [
            'email' => 'fatou@example.com',
            'username' => 'fatou_diop',
            'role' => 'user',
            'phone_number' => null,
        ]);
    }

    public function test_register_needs_no_phone_number_and_sends_no_code(): void
    {
        Mail::fake();

        $this->postJson('/api/v1/auth/register', $this->validPayload)
            ->assertCreated()
            ->assertJsonMissingPath('demo_otp')
            ->assertJsonMissingPath('otp_sent')
            ->assertJsonPath('user.email_verified', false);

        Mail::assertNothingSent();
        Mail::assertNothingQueued();
    }

    public function test_register_stores_the_email_in_lowercase(): void
    {
        $this->postJson('/api/v1/auth/register', [
            ...$this->validPayload,
            'email' => '  Fatou@Example.COM ',
        ])->assertCreated();

        $this->assertDatabaseHas('users', ['email' => 'fatou@example.com']);
    }

    public function test_register_rejects_duplicate_email_whatever_the_case(): void
    {
        User::factory()->create(['email' => 'fatou@example.com']);

        $this->postJson('/api/v1/auth/register', [
            ...$this->validPayload,
            'email' => 'FATOU@example.com',
        ])->assertUnprocessable()->assertJsonValidationErrors(['email']);
    }

    public function test_register_rejects_invalid_email(): void
    {
        $this->postJson('/api/v1/auth/register', [
            ...$this->validPayload,
            'email' => 'pas-un-email',
        ])->assertUnprocessable()->assertJsonValidationErrors(['email']);
    }

    public function test_register_requires_an_email(): void
    {
        $payload = $this->validPayload;
        unset($payload['email']);

        $this->postJson('/api/v1/auth/register', $payload)
            ->assertUnprocessable()
            ->assertJsonValidationErrors(['email']);
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
