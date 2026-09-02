<?php

namespace Tests\Feature\Feed;

use App\Models\Product;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class PremiumBoostTest extends TestCase
{
    use RefreshDatabase;

    public function test_premium_seller_product_ranks_above_identical_non_premium_product(): void
    {
        // On neutralise le facteur aléatoire du feed_score pour un test
        // déterministe — sinon un même test pourrait échouer une fois sur N
        // juste à cause du bruit volontaire dans le classement.
        config(['quinch.premium.feed_boost' => 1000]);

        $premiumSeller = User::factory()->create([
            'is_premium' => true,
            'premium_expires_at' => now()->addMonth(),
        ]);
        $freeSeller = User::factory()->create(['is_premium' => false]);

        // Engagement, fraîcheur et vidéo strictement identiques des deux
        // côtés — seule la différence premium/non-premium doit trancher.
        $premiumProduct = Product::factory()->create([
            'user_id' => $premiumSeller->id,
            'status' => 'active',
            'poster_url' => 'products/posters/a.jpg',
            'like_count' => 10,
            'view_count' => 100,
            'share_count' => 2,
            'video_id' => null,
        ]);

        $freeProduct = Product::factory()->create([
            'user_id' => $freeSeller->id,
            'status' => 'active',
            'poster_url' => 'products/posters/b.jpg',
            'like_count' => 10,
            'view_count' => 100,
            'share_count' => 2,
            'video_id' => null,
        ]);

        $response = $this->getJson('/api/v1/products/feed?tab=foryou&per_page=10');

        $response->assertOk();
        $ids = collect($response->json('data'))->pluck('id')->values();

        $premiumIndex = $ids->search($premiumProduct->id);
        $freeIndex = $ids->search($freeProduct->id);

        $this->assertNotFalse($premiumIndex, 'Le produit premium doit apparaître dans le feed.');
        $this->assertNotFalse($freeIndex, 'Le produit gratuit doit apparaître dans le feed.');
        $this->assertLessThan($freeIndex, $premiumIndex, 'Le produit du vendeur premium doit être classé avant celui du vendeur gratuit.');
    }

    public function test_expired_premium_does_not_get_the_boost(): void
    {
        config(['quinch.premium.feed_boost' => 1000]);

        // Flag encore à true mais date dépassée — simule le court laps de
        // temps avant le passage du job d'expiration quotidien.
        $expiredPremiumSeller = User::factory()->create([
            'is_premium' => true,
            'premium_expires_at' => now()->subDay(),
        ]);
        $freeSeller = User::factory()->create(['is_premium' => false]);

        $expiredProduct = Product::factory()->create([
            'user_id' => $expiredPremiumSeller->id,
            'status' => 'active',
            'poster_url' => 'products/posters/a.jpg',
            'like_count' => 10,
            'view_count' => 100,
            'share_count' => 500, // net avantage d'engagement pour compenser tout bruit aléatoire
            'video_id' => null,
        ]);

        $freeProduct = Product::factory()->create([
            'user_id' => $freeSeller->id,
            'status' => 'active',
            'poster_url' => 'products/posters/b.jpg',
            'like_count' => 10,
            'view_count' => 100,
            'share_count' => 2,
            'video_id' => null,
        ]);

        $response = $this->getJson('/api/v1/products/feed?tab=foryou&per_page=10');

        $ids = collect($response->json('data'))->pluck('id')->values();
        $expiredIndex = $ids->search($expiredProduct->id);
        $freeIndex = $ids->search($freeProduct->id);

        // Sans le boost (premium expiré), c'est l'engagement réel qui
        // décide — le produit avec 500 partages doit rester devant.
        $this->assertLessThan($freeIndex, $expiredIndex);
    }
}