<?php

namespace Tests\Feature\Marketplace;

use App\Models\Product;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class MarketplacePremiumSortTest extends TestCase
{
    use RefreshDatabase;

    private function makeSellers(): array
    {
        return [
            User::factory()->create(['is_premium' => true, 'premium_expires_at' => now()->addMonth()]),
            User::factory()->create(['is_premium' => false]),
        ];
    }

    public function test_premium_seller_ranks_first_on_default_recent_sort(): void
    {
        [$premiumSeller, $freeSeller] = $this->makeSellers();

        // Le produit gratuit est publié APRÈS le produit premium — sans
        // boost, il sortirait naturellement devant en tri "recent".
        $premiumProduct = Product::factory()->create(['user_id' => $premiumSeller->id, 'poster_url' => 'a.jpg', 'created_at' => now()->subHour()]);
        $freeProduct = Product::factory()->create(['user_id' => $freeSeller->id, 'poster_url' => 'b.jpg', 'created_at' => now()]);

        $response = $this->getJson('/api/v1/products?sort_by=recent');
        $ids = collect($response->json('data'))->pluck('id')->values();

        $this->assertLessThan($ids->search($freeProduct->id), $ids->search($premiumProduct->id));
    }

    public function test_premium_seller_ranks_first_on_popular_sort_at_equal_likes(): void
    {
        [$premiumSeller, $freeSeller] = $this->makeSellers();

        $premiumProduct = Product::factory()->create(['user_id' => $premiumSeller->id, 'poster_url' => 'a.jpg', 'like_count' => 10]);
        $freeProduct = Product::factory()->create(['user_id' => $freeSeller->id, 'poster_url' => 'b.jpg', 'like_count' => 10]);

        $response = $this->getJson('/api/v1/products?sort_by=popular');
        $ids = collect($response->json('data'))->pluck('id')->values();

        $this->assertLessThan($ids->search($freeProduct->id), $ids->search($premiumProduct->id));
    }

    public function test_price_sort_ignores_premium_status_entirely(): void
    {
        [$premiumSeller, $freeSeller] = $this->makeSellers();

        // Le produit premium est plus CHER — un tri prix honnête doit
        // classer le moins cher en premier, peu importe le statut vendeur.
        $premiumProduct = Product::factory()->create(['user_id' => $premiumSeller->id, 'poster_url' => 'a.jpg', 'price' => 50000]);
        $cheaperFreeProduct = Product::factory()->create(['user_id' => $freeSeller->id, 'poster_url' => 'b.jpg', 'price' => 10000]);

        $response = $this->getJson('/api/v1/products?sort_by=price_asc');
        $ids = collect($response->json('data'))->pluck('id')->values();

        $this->assertLessThan($ids->search($premiumProduct->id), $ids->search($cheaperFreeProduct->id));
    }

    public function test_seller_is_premium_flag_is_exposed_in_response(): void
    {
        [$premiumSeller, $freeSeller] = $this->makeSellers();

        Product::factory()->create(['user_id' => $premiumSeller->id, 'poster_url' => 'a.jpg']);
        Product::factory()->create(['user_id' => $freeSeller->id, 'poster_url' => 'b.jpg']);

        $response = $this->getJson('/api/v1/products');
        $items = collect($response->json('data'));

        $premiumItem = $items->firstWhere('seller.id', $premiumSeller->id);
        $freeItem = $items->firstWhere('seller.id', $freeSeller->id);

        $this->assertTrue($premiumItem['seller']['is_premium']);
        $this->assertFalse($freeItem['seller']['is_premium']);
    }
}
