<?php

namespace Tests\Feature\Premium;

use App\Models\PremiumSubscription;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class PremiumWebhookHardeningTest extends TestCase
{
    use RefreshDatabase;

    private function pendingSubscription(User $user): PremiumSubscription
    {
        return PremiumSubscription::create([
            'user_id' => $user->id,
            'plan' => 'monthly',
            'amount' => 2000,
            'currency' => 'XOF',
            'status' => 'pending',
            'payment_method' => 'wave',
        ]);
    }

    private function postPremiumWebhook(PremiumSubscription $subscription, array $extra = [])
    {
        config(['services.wave.webhook_secret' => 'whsec_test']);

        $body = json_encode([
            'type' => 'checkout.session.completed',
            'data' => array_merge([
                'id' => 'cs-premium-1',
                'client_reference' => 'premium_' . $subscription->id,
                'payment_status' => 'succeeded',
            ], $extra),
        ]);

        $timestamp = time();
        $signature = hash_hmac('sha256', $timestamp . $body, 'whsec_test');

        return $this->call('POST', '/api/v1/webhooks/wave-premium', [], [], [], [
            'HTTP_Wave-Signature' => "t={$timestamp},v1={$signature}",
            'CONTENT_TYPE' => 'application/json',
        ], $body);
    }

    public function test_underpaid_premium_is_not_activated(): void
    {
        $user = User::factory()->create(['is_premium' => false]);
        $subscription = $this->pendingSubscription($user);

        $this->postPremiumWebhook($subscription, ['amount' => '500'])->assertOk();

        $this->assertFalse((bool) $user->fresh()->is_premium);
        $this->assertSame('pending', $subscription->fresh()->status);
    }

    public function test_exact_amount_activates_premium(): void
    {
        $user = User::factory()->create(['is_premium' => false]);
        $subscription = $this->pendingSubscription($user);

        $this->postPremiumWebhook($subscription, ['amount' => '2000'])->assertOk();

        $this->assertTrue((bool) $user->fresh()->is_premium);
        $this->assertSame('active', $subscription->fresh()->status);
    }

    public function test_second_webhook_does_not_extend_the_subscription_again(): void
    {
        $user = User::factory()->create(['is_premium' => false]);
        $subscription = $this->pendingSubscription($user);

        $this->postPremiumWebhook($subscription)->assertOk();
        $firstExpiry = $user->fresh()->premium_expires_at;

        $this->postPremiumWebhook($subscription)->assertOk();

        $this->assertEquals($firstExpiry, $user->fresh()->premium_expires_at);
    }
}
