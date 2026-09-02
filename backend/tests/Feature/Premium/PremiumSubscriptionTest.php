<?php

namespace Tests\Feature\Premium;

use App\Jobs\ExpirePremiumSubscriptions;
use App\Models\PremiumSubscription;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Http;
use Tests\TestCase;

class PremiumSubscriptionTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();

        config(['services.wave.api_key' => 'test-key']);
        config(['quinch.enabled_payment_methods' => ['wave']]);
    }

    private function fakeSuccessfulWaveCheckout(): void
    {
        Http::fake([
            'api.wave.com/v1/checkout/sessions' => Http::response([
                'id' => 'cs-premium-123',
                'wave_launch_url' => 'https://checkout.wave.com/cs-premium-123',
            ], 200),
        ]);
    }

    public function test_user_can_subscribe_to_monthly_plan(): void
    {
        $this->fakeSuccessfulWaveCheckout();

        $user = User::factory()->create();

        $response = $this->actingAs($user, 'sanctum')->postJson('/api/v1/premium/subscribe', [
            'plan' => 'monthly',
            'payment_method' => 'wave',
        ]);

        $response->assertCreated()
            ->assertJsonPath('subscription.plan', 'monthly')
            ->assertJsonPath('subscription.status', 'pending')
            ->assertJsonStructure(['payment_url']);

        $this->assertDatabaseHas('premium_subscriptions', [
            'user_id' => $user->id,
            'plan' => 'monthly',
            'amount' => 2000,
            'status' => 'pending',
        ]);

        // L'utilisateur n'est pas premium tant que le webhook n'a pas confirmé.
        $this->assertFalse($user->fresh()->is_premium);
    }

    public function test_rejects_an_invalid_plan(): void
    {
        $user = User::factory()->create();

        $response = $this->actingAs($user, 'sanctum')->postJson('/api/v1/premium/subscribe', [
            'plan' => 'weekly',
            'payment_method' => 'wave',
        ]);

        $response->assertUnprocessable()->assertJsonValidationErrors(['plan']);
    }

    public function test_price_cannot_be_overridden_by_the_client(): void
    {
        $this->fakeSuccessfulWaveCheckout();

        $user = User::factory()->create();

        // Même en essayant d'injecter un montant, le prix vient uniquement
        // de la config serveur — jamais de la requête.
        $response = $this->actingAs($user, 'sanctum')->postJson('/api/v1/premium/subscribe', [
            'plan' => 'monthly',
            'payment_method' => 'wave',
            'amount' => 1,
        ]);

        $response->assertCreated();
        $this->assertDatabaseHas('premium_subscriptions', ['user_id' => $user->id, 'amount' => 2000]);
    }

    public function test_wave_webhook_activates_subscription_with_valid_signature(): void
    {
        config(['services.wave.webhook_secret' => 'whsec_test']);

        $user = User::factory()->create();
        $subscription = PremiumSubscription::create([
            'user_id' => $user->id,
            'plan' => 'annual',
            'amount' => 20000,
            'currency' => 'XOF',
            'status' => 'pending',
            'payment_method' => 'wave',
        ]);

        $body = json_encode([
            'type' => 'checkout.session.completed',
            'data' => [
                'id' => 'cs-premium-123',
                'client_reference' => 'premium_' . $subscription->id,
                'payment_status' => 'succeeded',
            ],
        ]);

        $timestamp = time();
        $signature = hash_hmac('sha256', $timestamp . $body, 'whsec_test');

        $response = $this->call('POST', '/api/v1/webhooks/wave-premium', [], [], [], [
            'HTTP_Wave-Signature' => "t={$timestamp},v1={$signature}",
            'CONTENT_TYPE' => 'application/json',
        ], $body);

        $response->assertOk();

        $this->assertDatabaseHas('premium_subscriptions', [
            'id' => $subscription->id,
            'status' => 'active',
        ]);

        $user->refresh();
        $this->assertTrue($user->is_premium);
        $this->assertEquals('annual', $user->premium_plan);
        $this->assertNotNull($user->premium_expires_at);
        $this->assertTrue($user->premium_expires_at->isAfter(now()->addMonths(11)));
    }

    public function test_wave_premium_webhook_rejects_invalid_signature(): void
    {
        config(['services.wave.webhook_secret' => 'whsec_test']);

        $response = $this->postJson('/api/v1/webhooks/wave-premium', [
            'type' => 'checkout.session.completed',
            'data' => ['client_reference' => 'premium_whatever', 'payment_status' => 'succeeded'],
        ], ['Wave-Signature' => 't=1,v1=invalid']);

        $response->assertStatus(401);
    }

    public function test_webhook_ignores_non_premium_client_references(): void
    {
        // Garde-fou : un webhook Wave d'un achat produit classique (sans
        // préfixe "premium_") ne doit jamais pouvoir activer un abonnement,
        // même si quelqu'un l'envoyait sur le mauvais endpoint par erreur.
        config(['services.wave.webhook_secret' => 'whsec_test']);

        $body = json_encode([
            'type' => 'checkout.session.completed',
            'data' => [
                'id' => 'cs-random',
                'client_reference' => 'some-transaction-uuid-not-premium',
                'payment_status' => 'succeeded',
            ],
        ]);

        $timestamp = time();
        $signature = hash_hmac('sha256', $timestamp . $body, 'whsec_test');

        $response = $this->call('POST', '/api/v1/webhooks/wave-premium', [], [], [], [
            'HTTP_Wave-Signature' => "t={$timestamp},v1={$signature}",
            'CONTENT_TYPE' => 'application/json',
        ], $body);

        $response->assertOk()->assertJson(['status' => 'ignored']);
    }

    public function test_expiration_job_deactivates_expired_premium_users(): void
    {
        $user = User::factory()->create();
        $user->forceFill([
            'is_premium' => true,
            'premium_plan' => 'monthly',
            'premium_expires_at' => now()->subDays(2),
        ])->save();

        $subscription = PremiumSubscription::create([
            'user_id' => $user->id,
            'plan' => 'monthly',
            'amount' => 2000,
            'currency' => 'XOF',
            'status' => 'active',
            'payment_method' => 'wave',
            'starts_at' => now()->subMonth(),
            'expires_at' => now()->subDays(2),
        ]);

        (new ExpirePremiumSubscriptions)->handle();

        $user->refresh();
        $this->assertFalse($user->is_premium);
        $this->assertNull($user->premium_plan);
        $this->assertEquals('expired', $subscription->fresh()->status);
    }

    public function test_expiration_job_does_not_touch_still_active_subscriptions(): void
    {
        $user = User::factory()->create();
        $user->forceFill([
            'is_premium' => true,
            'premium_plan' => 'annual',
            'premium_expires_at' => now()->addMonths(6),
        ])->save();

        $subscription = PremiumSubscription::create([
            'user_id' => $user->id,
            'plan' => 'annual',
            'amount' => 20000,
            'currency' => 'XOF',
            'status' => 'active',
            'payment_method' => 'wave',
            'starts_at' => now()->subMonths(6),
            'expires_at' => now()->addMonths(6),
        ]);

        (new ExpirePremiumSubscriptions)->handle();

        $user->refresh();
        $this->assertTrue($user->is_premium);
        $this->assertEquals('active', $subscription->fresh()->status);
    }
}