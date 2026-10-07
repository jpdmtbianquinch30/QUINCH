<?php

namespace Tests\Feature\Payments;

use App\Jobs\ReconcileWavePayments;
use App\Models\PremiumSubscription;
use App\Models\Product;
use App\Models\ProductVideo;
use App\Models\User;
use App\Services\Payments\WavePaymentConfirmer;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Storage;
use Tests\TestCase;

/**
 * Rattrapage : un webhook perdu ne doit jamais laisser un client payé sans service.
 */
class ReconcileWavePaymentsTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();

        config(['services.wave.api_key' => 'test-key', 'services.wave.base_url' => 'https://api.wave.com/v1']);
        Storage::fake('public');
    }

    private function runJob(): void
    {
        (new ReconcileWavePayments())->handle(app(WavePaymentConfirmer::class));
    }

    private function pendingSubscription(User $user, int $ageMinutes = 10): PremiumSubscription
    {
        $subscription = PremiumSubscription::create([
            'user_id' => $user->id, 'plan' => 'monthly', 'amount' => 2000, 'currency' => 'XOF',
            'status' => 'pending', 'payment_method' => 'wave',
        ]);

        DB::table($subscription->getTable())->where('id', $subscription->id)->update([
            'payment_gateway_id' => 'cos-1',
            'created_at' => now()->subMinutes($ageMinutes),
        ]);

        return $subscription->fresh();
    }

    private function draftWithFee(User $user, int $ageMinutes = 10): Product
    {
        $video = ProductVideo::factory()->create(['user_id' => $user->id]);
        $product = Product::factory()->create([
            'user_id' => $user->id, 'status' => 'draft', 'video_id' => $video->id,
            'listing_fee_status' => 'pending', 'listing_fee_amount' => 150,
        ]);

        DB::table($product->getTable())->where('id', $product->id)->update([
            'listing_fee_gateway_id' => 'cos-2',
            'updated_at' => now()->subMinutes($ageMinutes),
        ]);

        return $product->fresh();
    }

    private function fakeSearch(array $sessions): void
    {
        Http::fake([
            'api.wave.com/v1/checkout/sessions/search*' => Http::response(['result' => $sessions]),
        ]);
    }

    private function waveSession(string $reference, string $checkout, string $payment, string $amount): array
    {
        return [
            'id' => 'cos-1', 'client_reference' => $reference, 'amount' => $amount, 'currency' => 'XOF',
            'checkout_status' => $checkout, 'payment_status' => $payment,
        ];
    }

    public function test_a_paid_session_activates_premium_when_the_webhook_was_lost(): void
    {
        $user = User::factory()->create(['is_premium' => false]);
        $subscription = $this->pendingSubscription($user);
        $this->fakeSearch([$this->waveSession('premium_' . $subscription->id, 'complete', 'succeeded', '2000')]);

        $this->runJob();

        $this->assertSame('active', $subscription->fresh()->status);
        $this->assertTrue((bool) $user->fresh()->is_premium);
    }

    public function test_expired_sessions_cancel_the_pending_subscription(): void
    {
        $user = User::factory()->create();
        $subscription = $this->pendingSubscription($user);
        $this->fakeSearch([$this->waveSession('premium_' . $subscription->id, 'expired', 'cancelled', '2000')]);

        $this->runJob();

        $this->assertSame('cancelled', $subscription->fresh()->status);
    }

    public function test_a_session_still_open_is_left_alone(): void
    {
        $user = User::factory()->create();
        $subscription = $this->pendingSubscription($user);
        $this->fakeSearch([$this->waveSession('premium_' . $subscription->id, 'open', 'processing', '2000')]);

        $this->runJob();

        $this->assertSame('pending', $subscription->fresh()->status);
    }

    public function test_it_falls_back_to_the_stored_session_id_when_search_is_unavailable(): void
    {
        $user = User::factory()->create(['is_premium' => false]);
        $subscription = $this->pendingSubscription($user);

        Http::fake([
            'api.wave.com/v1/checkout/sessions/search*' => Http::response([], 404),
            'api.wave.com/v1/checkout/sessions/cos-1' => Http::response(
                $this->waveSession('premium_' . $subscription->id, 'complete', 'succeeded', '2000')
            ),
        ]);

        $this->runJob();

        $this->assertSame('active', $subscription->fresh()->status);
    }

    public function test_an_underpaid_session_does_not_activate_premium(): void
    {
        $user = User::factory()->create(['is_premium' => false]);
        $subscription = $this->pendingSubscription($user);
        $this->fakeSearch([$this->waveSession('premium_' . $subscription->id, 'complete', 'succeeded', '500')]);

        $this->runJob();

        $this->assertSame('pending', $subscription->fresh()->status);
        $this->assertFalse((bool) $user->fresh()->is_premium);
    }

    public function test_a_paid_session_of_another_reference_is_ignored(): void
    {
        $user = User::factory()->create(['is_premium' => false]);
        $subscription = $this->pendingSubscription($user);
        $this->fakeSearch([$this->waveSession('premium_autre-reference', 'complete', 'succeeded', '2000')]);

        $this->runJob();

        $this->assertSame('pending', $subscription->fresh()->status);
    }

    public function test_recent_payments_are_not_checked_yet(): void
    {
        $user = User::factory()->create();
        $this->pendingSubscription($user, 1);
        Http::fake();

        $this->runJob();

        Http::assertNothingSent();
    }

    public function test_nothing_happens_without_a_wave_api_key(): void
    {
        config(['services.wave.api_key' => null]);
        $user = User::factory()->create();
        $this->pendingSubscription($user);
        Http::fake();

        $this->runJob();

        Http::assertNothingSent();
    }

    public function test_a_paid_listing_fee_publishes_the_draft(): void
    {
        $user = User::factory()->create(['is_premium' => false]);
        $product = $this->draftWithFee($user);
        $this->fakeSearch([$this->waveSession('listing_' . $product->id, 'complete', 'succeeded', '150')]);

        $this->runJob();

        $this->assertSame('active', $product->fresh()->status);
        $this->assertSame('paid', $product->fresh()->listing_fee_status);
    }

    public function test_an_expired_listing_session_marks_the_fee_as_failed(): void
    {
        $user = User::factory()->create(['is_premium' => false]);
        $product = $this->draftWithFee($user);
        $this->fakeSearch([$this->waveSession('listing_' . $product->id, 'expired', 'cancelled', '150')]);

        $this->runJob();

        $this->assertSame('draft', $product->fresh()->status);
        $this->assertSame('failed', $product->fresh()->listing_fee_status);
    }
}
