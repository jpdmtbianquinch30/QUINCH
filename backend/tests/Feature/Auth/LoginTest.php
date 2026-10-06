<?php

namespace Tests\Feature\Auth;

use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Hash;
use Tests\TestCase;

class LoginTest extends TestCase
{
    use RefreshDatabase;

    public function test_login_succeeds_with_correct_credentials(): void
    {
        User::factory()->create([
            'email' => 'fatou@example.com',
            'password' => Hash::make('Password1'),
        ]);

        $response = $this->postJson('/api/v1/auth/login', [
            'email' => 'fatou@example.com',
            'password' => 'Password1',
        ]);

        $response->assertOk()->assertJsonStructure(['user', 'token']);
    }

    public function test_login_is_case_insensitive_on_the_email(): void
    {
        User::factory()->create([
            'email' => 'fatou@example.com',
            'password' => Hash::make('Password1'),
        ]);

        $this->postJson('/api/v1/auth/login', [
            'email' => '  Fatou@Example.COM ',
            'password' => 'Password1',
        ])->assertOk();
    }

    public function test_login_fails_with_wrong_password(): void
    {
        User::factory()->create([
            'email' => 'fatou@example.com',
            'password' => Hash::make('Password1'),
        ]);

        $response = $this->postJson('/api/v1/auth/login', [
            'email' => 'fatou@example.com',
            'password' => 'WrongPassword1',
        ]);

        $response->assertUnprocessable()
            ->assertJsonValidationErrors(['email']);
    }

    public function test_login_fails_for_unknown_email(): void
    {
        $response = $this->postJson('/api/v1/auth/login', [
            'email' => 'inconnu@example.com',
            'password' => 'Password1',
        ]);

        $response->assertUnprocessable();
    }

    public function test_login_by_phone_number_is_no_longer_accepted(): void
    {
        User::factory()->create([
            'phone_number' => '+221771234567',
            'password' => Hash::make('Password1'),
        ]);

        $this->postJson('/api/v1/auth/login', [
            'phone_number' => '+221771234567',
            'password' => 'Password1',
        ])->assertUnprocessable()->assertJsonValidationErrors(['email']);
    }

    public function test_suspended_account_cannot_login(): void
    {
        User::factory()->suspended()->create([
            'email' => 'fatou@example.com',
            'password' => Hash::make('Password1'),
        ]);

        $response = $this->postJson('/api/v1/auth/login', [
            'email' => 'fatou@example.com',
            'password' => 'Password1',
        ]);

        $response->assertForbidden()
            ->assertJsonPath('error', 'account_suspended');
    }

    public function test_unauthenticated_request_to_protected_route_returns_json_401(): void
    {
        // Régression : vérifie qu'une route protégée renvoie bien un 401 JSON
        // et non une page HTML 500 (voir bootstrap/app.php redirectGuestsTo).
        $response = $this->getJson('/api/v1/auth/me');

        $response->assertUnauthorized()
            ->assertJson(['message' => 'Unauthenticated.']);
    }
}
