<?php

namespace Tests\Feature\Auth;

use App\Mail\PasswordResetCodeMail;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Routing\Middleware\ThrottleRequests;
use Illuminate\Support\Facades\Mail;
use Tests\TestCase;

class OtpSecurityTest extends TestCase
{
    use RefreshDatabase;

    private function wrongCodeFor(string $otp): string
    {
        return $otp === '111111' ? '222222' : '111111';
    }

    public function test_otp_is_refused_after_max_wrong_attempts(): void
    {
        $user = User::factory()->unverified()->create();
        $otp = $user->generateOtp();
        $wrong = $this->wrongCodeFor($otp);
        $user = $user->fresh();

        for ($i = 0; $i < 5; $i++) {
            $this->assertFalse($user->verifyOtp($wrong));
        }

        $this->assertFalse($user->verifyOtp($otp), 'Le bon code doit être refusé une fois le quota épuisé.');
    }

    public function test_correct_code_within_the_limit_succeeds(): void
    {
        $user = User::factory()->unverified()->create();
        $otp = $user->generateOtp();
        $wrong = $this->wrongCodeFor($otp);
        $user = $user->fresh();

        for ($i = 0; $i < 4; $i++) {
            $this->assertFalse($user->verifyOtp($wrong));
        }

        $this->assertTrue($user->verifyOtp($otp));
    }

    public function test_a_new_code_resets_the_attempt_counter(): void
    {
        $user = User::factory()->unverified()->create();
        $otp = $user->generateOtp();
        $wrong = $this->wrongCodeFor($otp);
        $locked = $user->fresh();

        for ($i = 0; $i < 5; $i++) {
            $locked->verifyOtp($wrong);
        }

        $newOtp = $user->fresh()->generateOtp();

        $this->assertTrue($user->fresh()->verifyOtp($newOtp));
    }

    public function test_otp_routes_removed_from_registration_are_gone(): void
    {
        $this->postJson('/api/v1/auth/verify-otp', ['email' => 'a@example.com', 'otp' => '123456'])
            ->assertNotFound();

        $this->postJson('/api/v1/auth/resend-otp', ['email' => 'a@example.com'])
            ->assertNotFound();
    }

    public function test_forgot_password_is_throttled_per_email_for_known_and_unknown_addresses(): void
    {
        $this->withoutMiddleware(ThrottleRequests::class);

        $user = User::factory()->create();

        foreach ([$user->email, 'inconnu@example.com'] as $email) {
            $this->postJson('/api/v1/auth/forgot-password', ['email' => $email])->assertOk();

            $this->postJson('/api/v1/auth/forgot-password', ['email' => $email])
                ->assertStatus(429)
                ->assertJsonPath('error', 'otp_rate_limited');
        }
    }

    public function test_the_code_is_hashed_in_database(): void
    {
        $user = User::factory()->create();
        $otp = $user->generateOtp();

        $this->assertNotSame($otp, $user->fresh()->otp_code);
    }

    public function test_demo_code_is_only_exposed_in_the_testing_environment(): void
    {
        $otp = app(\App\Services\OtpService::class);

        $this->assertTrue($otp->shouldExposeDemoCode());

        foreach (['local', 'production', 'staging'] as $env) {
            $this->app['env'] = $env;
            $this->assertFalse($otp->shouldExposeDemoCode(), "Le code ne doit jamais être exposé en {$env}.");
        }
    }

    public function test_a_mail_failure_does_not_change_the_response(): void
    {
        // Même réponse que le compte existe ou non : une panne de file ne doit
        // pas transformer la réponse en 500 (qui révélerait l'existence du compte).
        Mail::shouldReceive('to')->andThrow(new \RuntimeException('file indisponible'));

        $user = User::factory()->create();

        $this->postJson('/api/v1/auth/forgot-password', ['email' => $user->email])->assertOk();
    }
}
