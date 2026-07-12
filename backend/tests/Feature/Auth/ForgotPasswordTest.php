<?php

namespace Tests\Feature\Auth;

use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Hash;
use Tests\TestCase;

class ForgotPasswordTest extends TestCase
{
    use RefreshDatabase;

    public function test_forgot_password_returns_demo_otp_for_existing_user_in_testing(): void
    {
        User::factory()->create(['phone_number' => '+221771234567']);

        $response = $this->postJson('/api/v1/auth/forgot-password', [
            'phone_number' => '+221771234567',
        ]);

        $response->assertOk()->assertJsonStructure(['message', 'demo_otp']);
    }

    public function test_forgot_password_gives_same_generic_message_for_unknown_number(): void
    {
        // Ne doit jamais révéler si un numéro est inscrit ou non.
        $response = $this->postJson('/api/v1/auth/forgot-password', [
            'phone_number' => '+221709999999',
        ]);

        $response->assertOk()
            ->assertJsonMissingPath('demo_otp')
            ->assertJsonPath('message', 'Si ce numéro est associé à un compte, un code a été envoyé par SMS.');
    }

    public function test_reset_password_succeeds_with_correct_otp(): void
    {
        $user = User::factory()->create([
            'phone_number' => '+221771234567',
            'password' => Hash::make('OldPassword1'),
        ]);
        $otp = $user->generateOtp();

        $response = $this->postJson('/api/v1/auth/reset-password', [
            'phone_number' => '+221771234567',
            'otp' => $otp,
            'password' => 'NewPassword1',
            'password_confirmation' => 'NewPassword1',
        ]);

        $response->assertOk();

        // Le nouveau mot de passe doit fonctionner pour se connecter.
        $login = $this->postJson('/api/v1/auth/login', [
            'phone_number' => '+221771234567',
            'password' => 'NewPassword1',
        ]);
        $login->assertOk();
    }

    public function test_reset_password_fails_with_wrong_otp(): void
    {
        $user = User::factory()->create(['phone_number' => '+221771234567']);
        $user->generateOtp();

        $response = $this->postJson('/api/v1/auth/reset-password', [
            'phone_number' => '+221771234567',
            'otp' => '000000',
            'password' => 'NewPassword1',
            'password_confirmation' => 'NewPassword1',
        ]);

        $response->assertUnprocessable()->assertJsonPath('error', 'invalid_otp');
    }

    public function test_reset_password_revokes_all_existing_sessions(): void
    {
        $user = User::factory()->create(['phone_number' => '+221771234567']);
        $token = $user->createToken('old-session')->plainTextToken;
        $otp = $user->generateOtp();

        $this->postJson('/api/v1/auth/reset-password', [
            'phone_number' => '+221771234567',
            'otp' => $otp,
            'password' => 'NewPassword1',
            'password_confirmation' => 'NewPassword1',
        ]);

        // L'ancien token ne doit plus fonctionner.
        $response = $this->withHeader('Authorization', "Bearer $token")->getJson('/api/v1/auth/me');
        $response->assertUnauthorized();
    }
}
