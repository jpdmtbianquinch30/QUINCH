<?php

namespace Tests\Feature\Payments;

use App\Models\PremiumSubscription;
use App\Models\Product;
use App\Models\ProductVideo;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Storage;
use Tests\TestCase;

/**
 * Point d'entrée unique /webhooks/wave : un seul webhook enregistré chez Wave,
 * aiguillé selon le client_reference.
 */
class WaveWebhookRoutingTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();

        config(['services.wave.webhook_secret' => 'whsec_test']);
        Storage::fake('public');
    }

    private function postWebhook(array $payload, ?string $signatureHeader = null)
    {
        $body = json_encode($payload);
        $timestamp = time();
        $signature = hash_hmac('sha256', $timestamp . $body, 'whsec_test');

        return $this->call('POST', '/api/v1/webhooks/wave', [], [], [], [
            'HTTP_Wave-Signature' => $signatureHeader ?? "t={$timestamp},v1={$signature}",
            'CONTENT_TYPE' => 'application/json',
        ], $body);
    }

    private function event(string $type, string $reference, array $extra = []): array
    {
        return [
            'type' => $type,
            'data' => array_merge([
                'id' => 'cos-test-1',
                'client_reference' => $reference,
                'payment_status' => $type === 'checkout.session.completed' ? 'succeeded' : 'failed',
                'amount' => '2000',
            ], $extra),
        ];
    }

    private function pendingSubscription(User $user, string $status = 'pending'): PremiumSubscription
    {
        return PremiumSubscription::create([
            'user_id' => $user->id, 'plan' => 'monthly', 'amount' => 2000, 'currency' => 'XOF',
            'status' => $status, 'payment_method' => 'wave',
        ]);
    }

    public function test_premium_reference_activates_the_subscription(): void
    {
        $user = User::factory()->create(['is_premium' => false]);
        $subscription = $this->pendingSubscription($user);

        $this->postWebhook($this->event('checkout.session.completed', 'premium_' . $subscription->id))->assertOk();

        $this->assertSame('active', $subscription->fresh()->status);
        $this->assertTrue((bool) $user->fresh()->is_premium);
    }

    public function test_listing_reference_activates_the_draft(): void
    {
        $user = User::factory()->create(['is_premium' => false]);
        $video = ProductVideo::factory()->create(['user_id' => $user->id]);
        $product = Product::factory()->create([
            'user_id' => $user->id, 'status' => 'draft', 'video_id' => $video->id,
            'listing_fee_status' => 'pending', 'listing_fee_amount' => 150,
        ]);

        $this->postWebhook($this->event('checkout.session.completed', 'listing_' . $product->id, ['amount' => '150']))->assertOk();

        $this->assertSame('active', $product->fresh()->status);
        $this->assertSame('paid', $product->fresh()->listing_fee_status);
    }

    public function test_a_payment_failure_does_not_cancel_the_premium_subscription(): void
    {
        $user = User::factory()->create(['is_premium' => false]);
        $subscription = $this->pendingSubscription($user);

        $this->postWebhook($this->event('checkout.session.payment_failed', 'premium_' . $subscription->id))->assertOk();

        $this->assertSame('pending', $subscription->fresh()->status);

        // Wave autorise plusieurs échecs puis un succès dans la même session.
        $this->postWebhook($this->event('checkout.session.completed', 'premium_' . $subscription->id))->assertOk();

        $this->assertSame('active', $subscription->fresh()->status);
        $this->assertTrue((bool) $user->fresh()->is_premium);
    }

    public function test_a_late_success_still_activates_a_cancelled_subscription(): void
    {
        $user = User::factory()->create(['is_premium' => false]);
        $subscription = $this->pendingSubscription($user, 'cancelled');

        $this->postWebhook($this->event('checkout.session.completed', 'premium_' . $subscription->id))->assertOk();

        $this->assertSame('active', $subscription->fresh()->status);
    }

    public function test_an_invalid_signature_is_refused(): void
    {
        $user = User::factory()->create();
        $subscription = $this->pendingSubscription($user);

        $this->postWebhook($this->event('checkout.session.completed', 'premium_' . $subscription->id), 't=' . time() . ',v1=deadbeef')
            ->assertStatus(401);

        $this->assertSame('pending', $subscription->fresh()->status);
    }

    public function test_the_webhook_is_refused_when_no_secret_is_configured(): void
    {
        config(['services.wave.webhook_secret' => null]);

        $this->postWebhook(['type' => 'checkout.session.completed', 'data' => ['client_reference' => 'x']])->assertStatus(401);
    }

    public function test_several_v1_signatures_are_accepted_when_one_is_valid(): void
    {
        $user = User::factory()->create(['is_premium' => false]);
        $subscription = $this->pendingSubscription($user);

        $payload = $this->event('checkout.session.completed', 'premium_' . $subscription->id);
        $body = json_encode($payload);
        $timestamp = time();
        $good = hash_hmac('sha256', $timestamp . $body, 'whsec_test');

        // Rotation de secret : Wave peut envoyer deux signatures v1.
        $this->postWebhook($payload, "t={$timestamp},v1=deadbeef,v1={$good}")->assertOk();

        $this->assertSame('active', $subscription->fresh()->status);
    }

    public function test_unknown_or_malformed_references_are_ignored_without_error(): void
    {
        $this->postWebhook($this->event('checkout.session.completed', 'quelque-chose'))
            ->assertOk()->assertJson(['status' => 'ignored']);

        $this->postWebhook($this->event('checkout.session.completed', 'premium_pas-un-uuid'))
            ->assertOk()->assertJson(['status' => 'ignored']);

        $this->postWebhook(['type' => 'checkout.session.completed', 'data' => []])
            ->assertOk()->assertJson(['status' => 'ignored']);
    }
}
