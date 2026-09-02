<?php

namespace Tests\Feature\Feed;

use App\Models\Product;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class ActiveSellersTest extends TestCase
{
    use RefreshDatabase;

    private function makeActiveSeller(array $overrides = []): User
    {
        return User::factory()->create(array_merge([
            'is_seller' => true,
            'account_status' => 'active',
        ], $overrides));
    }

    public function test_premium_seller_ranks_first_at_equal_engagement(): void
    {
        $premiumSeller = $this->makeActiveSeller(['is_premium' => true, 'premium_expires_at' => now()->addMonth()]);
        $freeSeller = $this->makeActiveSeller(['is_premium' => false]);

        Product::factory()->create(['user_id' => $premiumSeller->id, 'status' => 'active', 'like_count' => 5, 'view_count' => 20]);
        Product::factory()->create(['user_id' => $freeSeller->id, 'status' => 'active', 'like_count' => 5, 'view_count' => 20]);

        $response = $this->getJson('/api/v1/products/active-sellers');
        $response->assertOk();

        $ids = collect($response->json('sellers'))->pluck('id')->values();

        $this->assertLessThan($ids->search($freeSeller->id), $ids->search($premiumSeller->id));
    }

    public function test_strong_engagement_still_beats_a_weaker_premium_seller(): void
    {
        // Le boost premium ne doit pas être absolu — un vendeur gratuit
        // avec un engagement massif doit pouvoir rester devant un vendeur
        // premium avec très peu d'activité.
        $premiumSeller = $this->makeActiveSeller(['is_premium' => true, 'premium_expires_at' => now()->addMonth()]);
        $topFreeSeller = $this->makeActiveSeller(['is_premium' => false]);

        Product::factory()->create(['user_id' => $premiumSeller->id, 'status' => 'active', 'like_count' => 1, 'view_count' => 1]);
        Product::factory()->create(['user_id' => $topFreeSeller->id, 'status' => 'active', 'like_count' => 500, 'view_count' => 5000]);

        $response = $this->getJson('/api/v1/products/active-sellers');
        $ids = collect($response->json('sellers'))->pluck('id')->values();

        $this->assertLessThan($ids->search($premiumSeller->id), $ids->search($topFreeSeller->id));
    }

    public function test_is_premium_flag_is_exposed_and_expiration_respected(): void
    {
        $activePremium = $this->makeActiveSeller(['is_premium' => true, 'premium_expires_at' => now()->addMonth()]);
        $expiredPremium = $this->makeActiveSeller(['is_premium' => true, 'premium_expires_at' => now()->subDay()]);

        Product::factory()->create(['user_id' => $activePremium->id, 'status' => 'active']);
        Product::factory()->create(['user_id' => $expiredPremium->id, 'status' => 'active']);

        $response = $this->getJson('/api/v1/products/active-sellers');
        $sellers = collect($response->json('sellers'));

        $this->assertTrue($sellers->firstWhere('id', $activePremium->id)['is_premium']);
        $this->assertFalse($sellers->firstWhere('id', $expiredPremium->id)['is_premium']);
    }

    public function test_sellers_without_active_products_are_excluded(): void
    {
        $seller = $this->makeActiveSeller();
        Product::factory()->create(['user_id' => $seller->id, 'status' => 'draft']);

        $response = $this->getJson('/api/v1/products/active-sellers');
        $ids = collect($response->json('sellers'))->pluck('id');

        $this->assertFalse($ids->contains($seller->id));
    }
}
