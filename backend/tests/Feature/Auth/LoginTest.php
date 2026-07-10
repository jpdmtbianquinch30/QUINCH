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
            'phone_number' => '+221771234567',
            'password' => Hash::make('Password1'),
        ]);

        $response = $this->postJson('/api/v1/auth/login', [
            'phone_number' => '+221771234567',
            'password' => 'Password1',
        ]);

        $response->assertOk()->assertJsonStructure(['user', 'token']);
    }

    public function test_login_fails_with_wrong_password(): void
    {
        User::factory()->create([
            'phone_number' => '+221771234567',
            'password' => Hash::make('Password1'),
        ]);

        $response = $this->postJson('/api/v1/auth/login', [
            'phone_number' => '+221771234567',
            'password' => 'WrongPassword1',
        ]);

        $response->assertUnprocessable()
            ->assertJsonValidationErrors(['phone_number']);
    }

    public function test_login_fails_for_unknown_phone_number(): void
    {
        $response = $this->postJson('/api/v1/auth/login', [
            'phone_number' => '+221709999999',
            'password' => 'Password1',
        ]);

        $response->assertUnprocessable();
    }

    public function test_suspended_account_cannot_login(): void
    {
        User::factory()->suspended()->create([
            'phone_number' => '+221771234567',
            'password' => Hash::make('Password1'),
        ]);

        $response = $this->postJson('/api/v1/auth/login', [
            'phone_number' => '+221771234567',
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
