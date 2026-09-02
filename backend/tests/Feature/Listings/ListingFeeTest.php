<?php

namespace Tests\Feature\Listings;

use App\Jobs\CleanupAbandonedDraftListings;
use App\Models\Category;
use App\Models\Product;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Storage;
use Tests\TestCase;

class ListingFeeTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();

        config(['services.wave.api_key' => 'test-key']);
        Storage::fake('public');
    }

    private function fakeSuccessfulWaveCheckout(): void
    {
        Http::fake([
            'api.wave.com/v1/checkout/sessions' => Http::response([
                'id' => 'cs-listing-123',
                'wave_launch_url' => 'https://checkout.wave.com/cs-listing-123',
            ], 200),
        ]);
    }

    private function basePayload(array $overrides = []): array
    {
        return array_merge([
            'title' => 'Produit de test',
            'category_id' => Category::factory()->create()->id,
            'price' => 15000,
            'poster_file' => UploadedFile::fake()->image('poster.jpg'),
        ], $overrides);
    }

    public function test_free_account_listing_without_video_costs_300_and_stays_draft_until_paid(): void
    {
        $this->fakeSuccessfulWaveCheckout();

        $user = User::factory()->create(['is_premium' => false]);

        $response = $this->actingAs($user, 'sanctum')->postJson('/api/v1/products', $this->basePayload());

        $response->assertCreated()
            ->assertJsonPath('product.status', 'draft')
            ->assertJsonPath('product.listing_fee_status', 'pending')
            ->assertJsonPath('fee', 300)
            ->assertJsonStructure(['payment_url']);

        $this->assertDatabaseHas('products', ['status' => 'draft', 'listing_fee_amount' => 300]);
    }

    public function test_free_account_listing_with_video_costs_500(): void
    {
        $this->fakeSuccessfulWaveCheckout();

        $user = User::factory()->create(['is_premium' => false]);
        $video = \App\Models\ProductVideo::factory()->create(['user_id' => $user->id]);

        $response = $this->actingAs($user, 'sanctum')->postJson('/api/v1/products', $this->basePayload([
            'video_id' => $video->id,
        ]));

        $response->assertCreated()->assertJsonPath('fee', 500);
    }

    public function test_premium_account_publishes_immediately_for_free(): void
    {
        $user = User::factory()->create([
            'is_premium' => true,
            'premium_expires_at' => now()->addMonth(),
        ]);

        $response = $this->actingAs($user, 'sanctum')->postJson('/api/v1/products', $this->basePayload());

        $response->assertCreated()
            ->assertJsonPath('product.status', 'active')
            ->assertJsonPath('product.listing_fee_status', 'none')
            ->assertJsonMissingPath('payment_url');

        $this->assertDatabaseHas('products', ['status' => 'active', 'listing_fee_amount' => 0]);
    }

    public function test_free_account_is_limited_to_three_photos(): void
    {
        $user = User::factory()->create(['is_premium' => false]);

        $response = $this->actingAs($user, 'sanctum')->postJson('/api/v1/products', $this->basePayload([
            'image_files' => [
                UploadedFile::fake()->image('1.jpg'),
                UploadedFile::fake()->image('2.jpg'),
                UploadedFile::fake()->image('3.jpg'),
            ],
        ]));

        // 1 poster + 3 images = 4 photos, au-dessus de la limite de 3 pour un compte gratuit.
        $response->assertUnprocessable();
    }

    public function test_premium_account_can_use_up_to_ten_photos(): void
    {
        $this->fakeSuccessfulWaveCheckout();

        $user = User::factory()->create([
            'is_premium' => true,
            'premium_expires_at' => now()->addMonth(),
        ]);

        $response = $this->actingAs($user, 'sanctum')->postJson('/api/v1/products', $this->basePayload([
            'image_files' => array_map(fn($i) => UploadedFile::fake()->image("{$i}.jpg"), range(1, 9)),
        ]));

        // 1 poster + 9 images = 10 photos, à la limite exacte pour un compte premium.
        $response->assertCreated();
    }

    public function test_listing_fee_price_cannot_be_overridden_by_the_client(): void
    {
        $this->fakeSuccessfulWaveCheckout();

        $user = User::factory()->create(['is_premium' => false]);

        $response = $this->actingAs($user, 'sanctum')->postJson('/api/v1/products', $this->basePayload([
            'listing_fee_amount' => 1,
        ]));

        $response->assertCreated()->assertJsonPath('fee', 300);
        $this->assertDatabaseHas('products', ['listing_fee_amount' => 300]);
    }

    public function test_wave_webhook_activates_draft_listing_with_valid_signature(): void
    {
        config(['services.wave.webhook_secret' => 'whsec_test']);

        $user = User::factory()->create();
        $product = Product::factory()->create([
            'user_id' => $user->id,
            'status' => 'draft',
            'listing_fee_status' => 'pending',
            'listing_fee_amount' => 300,
        ]);

        $body = json_encode([
            'type' => 'checkout.session.completed',
            'data' => [
                'id' => 'cs-listing-123',
                'client_reference' => 'listing_' . $product->id,
                'payment_status' => 'succeeded',
            ],
        ]);

        $timestamp = time();
        $signature = hash_hmac('sha256', $timestamp . $body, 'whsec_test');

        $response = $this->call('POST', '/api/v1/webhooks/wave-listing', [], [], [], [
            'HTTP_Wave-Signature' => "t={$timestamp},v1={$signature}",
            'CONTENT_TYPE' => 'application/json',
        ], $body);

        $response->assertOk();

        $this->assertDatabaseHas('products', [
            'id' => $product->id,
            'status' => 'active',
            'listing_fee_status' => 'paid',
        ]);
    }

    public function test_wave_listing_webhook_rejects_invalid_signature(): void
    {
        config(['services.wave.webhook_secret' => 'whsec_test']);

        $response = $this->postJson('/api/v1/webhooks/wave-listing', [
            'type' => 'checkout.session.completed',
            'data' => ['client_reference' => 'listing_whatever', 'payment_status' => 'succeeded'],
        ], ['Wave-Signature' => 't=1,v1=invalid']);

        $response->assertStatus(401);
    }

    public function test_cleanup_job_deletes_abandoned_draft_after_24_hours(): void
    {
        $user = User::factory()->create();
        $product = Product::factory()->create([
            'user_id' => $user->id,
            'status' => 'draft',
            'listing_fee_status' => 'pending',
            'poster_url' => 'products/posters/old-poster.jpg',
            'images' => ['products/images/old-1.jpg'],
        ]);
        $product->created_at = now()->subHours(25);
        $product->save();

        Storage::disk('public')->put('products/posters/old-poster.jpg', 'fake-content');
        Storage::disk('public')->put('products/images/old-1.jpg', 'fake-content');

        (new CleanupAbandonedDraftListings)->handle();

        $this->assertDatabaseMissing('products', ['id' => $product->id]);
        Storage::disk('public')->assertMissing('products/posters/old-poster.jpg');
        Storage::disk('public')->assertMissing('products/images/old-1.jpg');
    }

    public function test_cleanup_job_does_not_touch_recent_drafts(): void
    {
        $user = User::factory()->create();
        $product = Product::factory()->create([
            'user_id' => $user->id,
            'status' => 'draft',
            'listing_fee_status' => 'pending',
        ]);

        (new CleanupAbandonedDraftListings)->handle();

        $this->assertDatabaseHas('products', ['id' => $product->id]);
    }

    public function test_cleanup_job_does_not_touch_active_products(): void
    {
        $user = User::factory()->create();
        $product = Product::factory()->create([
            'user_id' => $user->id,
            'status' => 'active',
        ]);
        $product->created_at = now()->subDays(5);
        $product->save();

        (new CleanupAbandonedDraftListings)->handle();

        $this->assertDatabaseHas('products', ['id' => $product->id]);
    }
}