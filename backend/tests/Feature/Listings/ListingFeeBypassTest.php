<?php

namespace Tests\Feature\Listings;

use App\Models\Product;
use App\Models\ProductVideo;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Storage;
use Tests\TestCase;

class ListingFeeBypassTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();

        config(['services.wave.api_key' => 'test-key']);
        Storage::fake('public');
    }

    private function draftWithVideo(User $user, string $feeStatus = 'pending'): Product
    {
        $video = ProductVideo::factory()->create(['user_id' => $user->id]);

        return Product::factory()->create([
            'user_id' => $user->id,
            'status' => 'draft',
            'video_id' => $video->id,
            'listing_fee_status' => $feeStatus,
            'listing_fee_amount' => 150,
        ]);
    }

    private function postListingWebhook(Product $product, array $extra = [])
    {
        config(['services.wave.webhook_secret' => 'whsec_test']);

        $body = json_encode([
            'type' => 'checkout.session.completed',
            'data' => array_merge([
                'id' => 'cs-listing-1',
                'client_reference' => 'listing_' . $product->id,
                'payment_status' => 'succeeded',
            ], $extra),
        ]);

        $timestamp = time();
        $signature = hash_hmac('sha256', $timestamp . $body, 'whsec_test');

        return $this->call('POST', '/api/v1/webhooks/wave-listing', [], [], [], [
            'HTTP_Wave-Signature' => "t={$timestamp},v1={$signature}",
            'CONTENT_TYPE' => 'application/json',
        ], $body);
    }

    // ─── Contournement via PUT ───────────────────────────────────────────

    public function test_owner_cannot_publish_a_pending_fee_draft_through_update(): void
    {
        $user = User::factory()->create(['is_premium' => false]);
        $product = $this->draftWithVideo($user, 'pending');

        $this->actingAs($user, 'sanctum')
            ->putJson("/api/v1/products/{$product->id}", ['status' => 'active'])
            ->assertStatus(422)
            ->assertJsonPath('error', 'invalid_status_transition');

        $this->assertSame('draft', $product->fresh()->status);
    }

    public function test_owner_cannot_publish_a_video_draft_without_fee_through_update(): void
    {
        $user = User::factory()->create(['is_premium' => false]);
        $product = $this->draftWithVideo($user, 'none');

        $this->actingAs($user, 'sanctum')
            ->putJson("/api/v1/products/{$product->id}", ['status' => 'active'])
            ->assertStatus(422);

        $this->assertSame('draft', $product->fresh()->status);
    }

    public function test_owner_cannot_reactivate_a_product_disabled_by_moderation(): void
    {
        $user = User::factory()->create();
        $product = Product::factory()->create(['user_id' => $user->id, 'status' => 'disabled']);

        $this->actingAs($user, 'sanctum')
            ->putJson("/api/v1/products/{$product->id}", ['status' => 'active'])
            ->assertStatus(422);

        $this->assertSame('disabled', $product->fresh()->status);
    }

    public function test_owner_can_pause_then_reactivate_a_live_product(): void
    {
        $user = User::factory()->create();
        $product = Product::factory()->create(['user_id' => $user->id, 'status' => 'active']);

        $this->actingAs($user, 'sanctum')
            ->putJson("/api/v1/products/{$product->id}", ['status' => 'paused'])
            ->assertOk();

        $this->actingAs($user, 'sanctum')
            ->putJson("/api/v1/products/{$product->id}", ['status' => 'active'])
            ->assertOk();

        $this->assertSame('active', $product->fresh()->status);
    }

    public function test_admin_can_still_change_any_status(): void
    {
        $admin = User::factory()->admin()->create();
        $product = Product::factory()->create(['status' => 'disabled']);

        $this->actingAs($admin, 'sanctum')
            ->putJson("/api/v1/products/{$product->id}", ['status' => 'active'])
            ->assertOk();

        $this->assertSame('active', $product->fresh()->status);
    }

    // ─── Endpoint /publish ───────────────────────────────────────────────

    public function test_publish_requires_the_fee_for_a_free_account_with_video(): void
    {
        Http::fake([
            'api.wave.com/v1/checkout/sessions' => Http::response([
                'id' => 'cs-1',
                'wave_launch_url' => 'https://checkout.wave.com/cs-1',
            ], 200),
        ]);

        $user = User::factory()->create(['is_premium' => false]);
        $product = $this->draftWithVideo($user, 'none');

        $this->actingAs($user, 'sanctum')
            ->postJson("/api/v1/products/{$product->id}/publish")
            ->assertOk()
            ->assertJsonPath('fee', 150)
            ->assertJsonStructure(['payment_url']);

        $fresh = $product->fresh();
        $this->assertSame('draft', $fresh->status);
        $this->assertSame('pending', $fresh->listing_fee_status);
        $this->assertSame(150, (int) $fresh->listing_fee_amount);
    }

    public function test_publish_is_free_when_there_is_no_video(): void
    {
        $user = User::factory()->create(['is_premium' => false]);
        $product = Product::factory()->create([
            'user_id' => $user->id,
            'status' => 'draft',
            'video_id' => null,
            'listing_fee_status' => 'none',
        ]);

        $this->actingAs($user, 'sanctum')
            ->postJson("/api/v1/products/{$product->id}/publish")
            ->assertOk()
            ->assertJsonMissingPath('payment_url');

        $this->assertSame('active', $product->fresh()->status);
    }

    public function test_publish_is_free_for_a_premium_account_with_video(): void
    {
        $user = User::factory()->create([
            'is_premium' => true,
            'premium_expires_at' => now()->addMonth(),
        ]);
        $product = $this->draftWithVideo($user, 'none');

        $this->actingAs($user, 'sanctum')
            ->postJson("/api/v1/products/{$product->id}/publish")
            ->assertOk()
            ->assertJsonMissingPath('payment_url');

        $this->assertSame('active', $product->fresh()->status);
    }

    public function test_publish_rejects_non_owner_and_non_draft(): void
    {
        $owner = User::factory()->create();
        $other = User::factory()->create();
        $draft = Product::factory()->create(['user_id' => $owner->id, 'status' => 'draft', 'video_id' => null]);
        $live = Product::factory()->create(['user_id' => $owner->id, 'status' => 'active']);

        $this->actingAs($other, 'sanctum')
            ->postJson("/api/v1/products/{$draft->id}/publish")
            ->assertStatus(403);

        $this->actingAs($owner, 'sanctum')
            ->postJson("/api/v1/products/{$live->id}/publish")
            ->assertStatus(422);
    }

    // ─── Webhook ─────────────────────────────────────────────────────────

    public function test_webhook_refuses_an_underpaid_amount_then_accepts_the_right_one(): void
    {
        $user = User::factory()->create();
        $product = $this->draftWithVideo($user, 'pending');

        $this->postListingWebhook($product, ['amount' => '100'])->assertOk();
        $this->assertSame('draft', $product->fresh()->status);

        $this->postListingWebhook($product, ['amount' => '150'])->assertOk();
        $fresh = $product->fresh();
        $this->assertSame('active', $fresh->status);
        $this->assertSame('paid', $fresh->listing_fee_status);
    }

    public function test_webhook_is_idempotent_when_received_twice(): void
    {
        $user = User::factory()->create();
        $product = $this->draftWithVideo($user, 'pending');

        $this->postListingWebhook($product)->assertOk();
        $this->postListingWebhook($product)->assertOk();

        $this->assertSame('active', $product->fresh()->status);
        $this->assertSame('paid', $product->fresh()->listing_fee_status);
    }

    public function test_a_late_successful_payment_still_activates_a_failed_attempt(): void
    {
        $user = User::factory()->create();
        $product = $this->draftWithVideo($user, 'failed');

        $this->postListingWebhook($product)->assertOk();

        $this->assertSame('active', $product->fresh()->status);
    }

    // ─── Achats entre utilisateurs désactivés ────────────────────────────

    public function test_purchase_endpoints_are_disabled_by_the_purchases_flag(): void
    {
        config(['quinch.features.purchases' => false]);

        $user = User::factory()->create(['phone_verified' => true]);

        $this->actingAs($user, 'sanctum')->getJson('/api/v1/cart')->assertNotFound();
        $this->actingAs($user, 'sanctum')->postJson('/api/v1/transactions/initiate', [])->assertNotFound();
    }
}
