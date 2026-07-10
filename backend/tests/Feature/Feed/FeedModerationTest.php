<?php

namespace Tests\Feature\Feed;

use App\Models\Product;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class FeedModerationTest extends TestCase
{
    use RefreshDatabase;

    public function test_product_with_approved_video_appears_in_public_feed(): void
    {
        $product = Product::factory()->create(['status' => 'active']);

        $response = $this->getJson('/api/v1/products/feed');

        $response->assertOk();
        $ids = collect($response->json('data'))->pluck('id');
        $this->assertTrue($ids->contains($product->id));
    }

    public function test_product_with_pending_video_does_not_appear_in_public_feed(): void
    {
        // Régression : une vidéo pas encore validée par un modérateur ne doit
        // jamais apparaître publiquement (voir ProductFeedController::index).
        $product = Product::factory()->withPendingVideo()->create(['status' => 'active']);

        $response = $this->getJson('/api/v1/products/feed');

        $response->assertOk();
        $ids = collect($response->json('data'))->pluck('id');
        $this->assertFalse($ids->contains($product->id));
    }

    public function test_inactive_product_does_not_appear_in_public_feed(): void
    {
        $product = Product::factory()->create(['status' => 'draft']);

        $response = $this->getJson('/api/v1/products/feed');

        $response->assertOk();
        $ids = collect($response->json('data'))->pluck('id');
        $this->assertFalse($ids->contains($product->id));
    }
}
