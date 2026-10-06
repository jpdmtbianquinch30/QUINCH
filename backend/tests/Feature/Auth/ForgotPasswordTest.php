<?php

namespace Tests\Feature\Auth;

use App\Mail\PasswordResetCodeMail;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Mail;
use Tests\TestCase;

class ForgotPasswordTest extends TestCase
{
    use RefreshDatabase;

    public function test_forgot_password_returns_demo_otp_for_existing_user_in_testing(): void
    {
        User::factory()->create(['email' => 'fatou@example.com']);

        $this->postJson('/api/v1/auth/forgot-password', ['email' => 'fatou@example.com'])
            ->assertOk()
            ->assertJsonStructure(['message', 'demo_otp']);
    }

    public function test_forgot_password_gives_same_generic_message_for_unknown_email(): void
    {
        // Ne doit jamais révéler si une adresse est inscrite ou non.
        $this->postJson('/api/v1/auth/forgot-password', ['email' => 'inconnu@example.com'])
            ->assertOk()
            ->assertJsonMissingPath('demo_otp')
            ->assertJsonPath('message', 'Si cette adresse est associée à un compte, un code a été envoyé par e-mail.');
    }

    public function test_forgot_password_emails_the_code_to_the_account_address(): void
    {
        Mail::fake();
        $user = User::factory()->create(['email' => 'fatou@example.com']);

        $code = (string) $this->postJson('/api/v1/auth/forgot-password', ['email' => 'Fatou@Example.com'])
            ->assertOk()
            ->json('demo_otp');

        Mail::assertQueued(PasswordResetCodeMail::class, function (PasswordResetCodeMail $mail) use ($user, $code) {
            return $mail->hasTo($user->email) && $mail->code === $code;
        });
    }

    public function test_unknown_email_gets_no_mail(): void
    {
        Mail::fake();

        $this->postJson('/api/v1/auth/forgot-password', ['email' => 'inconnu@example.com'])->assertOk();

        Mail::assertNothingQueued();
        Mail::assertNothingSent();
    }

    public function test_the_mail_renders_the_code(): void
    {
        $html = (new PasswordResetCodeMail('482915', 10))->render();

        $this->assertStringContainsString('482915', $html);
        $this->assertStringContainsString('10 minutes', $html);
    }

    public function test_reset_password_succeeds_with_correct_otp(): void
    {
        $user = User::factory()->create([
            'email' => 'fatou@example.com',
            'password' => Hash::make('OldPassword1'),
        ]);
        $otp = $user->generateOtp();

        $this->postJson('/api/v1/auth/reset-password', [
            'email' => 'fatou@example.com',
            'otp' => $otp,
            'password' => 'NewPassword1',
            'password_confirmation' => 'NewPassword1',
        ])->assertOk();

        // Le nouveau mot de passe doit fonctionner pour se connecter.
        $this->postJson('/api/v1/auth/login', [
            'email' => 'fatou@example.com',
            'password' => 'NewPassword1',
        ])->assertOk();
    }

    public function test_reset_password_marks_the_email_as_verified(): void
    {
        $user = User::factory()->create(['email' => 'fatou@example.com', 'email_verified_at' => null]);
        $otp = $user->generateOtp();

        $this->postJson('/api/v1/auth/reset-password', [
            'email' => 'fatou@example.com',
            'otp' => $otp,
            'password' => 'NewPassword1',
            'password_confirmation' => 'NewPassword1',
        ])->assertOk();

        $this->assertNotNull($user->fresh()->email_verified_at);
    }

    public function test_reset_password_fails_with_wrong_otp(): void
    {
        $user = User::factory()->create(['email' => 'fatou@example.com']);
        $user->generateOtp();

        $this->postJson('/api/v1/auth/reset-password', [
            'email' => 'fatou@example.com',
            'otp' => '000000',
            'password' => 'NewPassword1',
            'password_confirmation' => 'NewPassword1',
        ])->assertUnprocessable()->assertJsonPath('error', 'invalid_otp');
    }

    public function test_a_code_sent_for_one_account_does_not_work_on_another(): void
    {
        $victim = User::factory()->create(['email' => 'victime@example.com']);
        $attacker = User::factory()->create(['email' => 'pirate@example.com']);
        $attackerCode = $attacker->generateOtp();

        $this->postJson('/api/v1/auth/reset-password', [
            'email' => $victim->email,
            'otp' => $attackerCode,
            'password' => 'NewPassword1',
            'password_confirmation' => 'NewPassword1',
        ])->assertUnprocessable()->assertJsonPath('error', 'invalid_otp');
    }

    public function test_reset_password_revokes_all_existing_sessions(): void
    {
        $user = User::factory()->create(['email' => 'fatou@example.com']);
        $token = $user->createToken('old-session')->plainTextToken;
        $otp = $user->generateOtp();

        $this->postJson('/api/v1/auth/reset-password', [
            'email' => 'fatou@example.com',
            'otp' => $otp,
            'password' => 'NewPassword1',
            'password_confirmation' => 'NewPassword1',
        ]);

        // L'ancien token ne doit plus fonctionner.
        $this->withHeader('Authorization', "Bearer $token")->getJson('/api/v1/auth/me')->assertUnauthorized();
    }

    public function test_the_old_phone_based_reset_routes_are_gone(): void
    {
        $this->postJson('/api/v1/auth/reset-password-email', [
            'phone_number' => '+221771234567',
            'email' => 'fatou@example.com',
            'otp' => '123456',
            'password' => 'NewPassword1',
            'password_confirmation' => 'NewPassword1',
        ])->assertNotFound();

        $this->postJson('/api/v1/auth/forgot-password', ['phone_number' => '+221771234567'])
            ->assertUnprocessable()
            ->assertJsonValidationErrors(['email']);
    }
}
