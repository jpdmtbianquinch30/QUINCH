<?php

namespace Tests\Feature\Auth;

use App\Jobs\SendSmsJob;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Routing\Middleware\ThrottleRequests;
use Illuminate\Support\Facades\Queue;
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

    public function test_verify_endpoint_refuses_the_correct_code_after_five_failures(): void
    {
        $this->withoutMiddleware(ThrottleRequests::class);

        $user = User::factory()->unverified()->create();
        $otp = $user->generateOtp();
        $wrong = $this->wrongCodeFor($otp);

        for ($i = 0; $i < 5; $i++) {
            $this->postJson('/api/v1/auth/verify-otp', [
                'phone_number' => $user->phone_number,
                'otp' => $wrong,
            ])->assertStatus(422);
        }

        $this->postJson('/api/v1/auth/verify-otp', [
            'phone_number' => $user->phone_number,
            'otp' => $otp,
        ])->assertStatus(422);

        $this->assertFalse((bool) $user->fresh()->phone_verified);
    }

    public function test_resend_is_throttled_per_phone_for_known_and_unknown_numbers(): void
    {
        $this->withoutMiddleware(ThrottleRequests::class);

        $user = User::factory()->unverified()->create();

        foreach ([$user->phone_number, '+221700000001'] as $phone) {
            $this->postJson('/api/v1/auth/resend-otp', ['phone_number' => $phone])->assertOk();

            $this->postJson('/api/v1/auth/resend-otp', ['phone_number' => $phone])
                ->assertStatus(429)
                ->assertJsonPath('error', 'otp_rate_limited');
        }
    }

    public function test_forgot_password_queues_an_sms_with_the_code(): void
    {
        Queue::fake();

        $user = User::factory()->create();

        $response = $this->postJson('/api/v1/auth/forgot-password', [
            'phone_number' => $user->phone_number,
        ])->assertOk();

        $code = (string) $response->json('demo_otp');

        Queue::assertPushed(SendSmsJob::class, function (SendSmsJob $job) use ($user, $code) {
            return $job->to === $user->phone_number && str_contains($job->message, $code);
        });
    }

    public function test_unknown_number_gets_no_sms(): void
    {
        Queue::fake();

        $this->postJson('/api/v1/auth/forgot-password', ['phone_number' => '+221700000002'])
            ->assertOk();

        Queue::assertNothingPushed();
    }
}
