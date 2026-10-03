<?php

namespace Tests\Feature\Performance;

use App\Models\Product;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class PaginationCapTest extends TestCase
{
    use RefreshDatabase;

    public function test_feed_per_page_is_capped(): void
    {
        $response = $this->getJson('/api/v1/products/feed?per_page=1000000');

        $response->assertOk();
        $this->assertLessThanOrEqual(30, (int) $response->json('per_page'));
    }

    public function test_feed_invalid_per_page_falls_back_to_default(): void
    {
        foreach (['abc', '-5', '0'] as $bad) {
            $response = $this->getJson('/api/v1/products/feed?per_page=' . $bad);

            $response->assertOk();
            $this->assertSame(10, (int) $response->json('per_page'), "per_page={$bad}");
        }
    }

    public function test_public_profile_products_per_page_is_capped(): void
    {
        $seller = User::factory()->create(['is_seller' => true, 'account_status' => 'active']);
        Product::factory()->create(['user_id' => $seller->id, 'status' => 'active']);

        $response = $this->getJson("/api/v1/users/{$seller->username}/products?per_page=999999");

        $response->assertOk();
        $this->assertLessThanOrEqual(30, (int) $response->json('per_page'));
    }

    public function test_guest_global_rate_limit_returns_429(): void
    {
        config(['quinch.rate_limits.guest' => 3]);

        for ($i = 0; $i < 3; $i++) {
            $this->getJson('/api/v1/categories')->assertOk();
        }

        $this->getJson('/api/v1/categories')->assertStatus(429);
    }

    public function test_webhooks_are_exempt_from_global_rate_limit(): void
    {
        config(['quinch.rate_limits.guest' => 1]);

        // Signature absente -> 401 (rejet applicatif), JAMAIS 429.
        for ($i = 0; $i < 5; $i++) {
            $this->postJson('/api/v1/webhooks/wave', [])->assertStatus(401);
        }
    }
}
