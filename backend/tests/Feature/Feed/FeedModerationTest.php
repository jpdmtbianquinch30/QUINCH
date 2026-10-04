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

    public function test_product_with_pending_video_appears_in_public_feed(): void
    {
        // Publication immédiate, modération APRÈS : une vidéo pas encore examinée
        // est visible dès sa mise en ligne (voir ProductFeedController::index).
        $product = Product::factory()->withPendingVideo()->create(['status' => 'active']);

        $response = $this->getJson('/api/v1/products/feed');

        $response->assertOk();
        $ids = collect($response->json('data'))->pluck('id');
        $this->assertTrue($ids->contains($product->id));
    }

    public function test_product_with_rejected_or_flagged_video_does_not_appear_in_public_feed(): void
    {
        $rejected = Product::factory()->withPendingVideo()->create(['status' => 'active']);
        $rejected->video->forceFill(['moderation_status' => 'rejected'])->save();

        $flagged = Product::factory()->withPendingVideo()->create(['status' => 'active']);
        $flagged->video->forceFill(['moderation_status' => 'flagged'])->save();

        $response = $this->getJson('/api/v1/products/feed');

        $response->assertOk();
        $ids = collect($response->json('data'))->pluck('id');
        $this->assertFalse($ids->contains($rejected->id));
        $this->assertFalse($ids->contains($flagged->id));
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
