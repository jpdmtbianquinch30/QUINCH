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
        ]);

        $freeProduct = Product::factory()->create([
            'user_id' => $freeSeller->id,
            'status' => 'active',
            'poster_url' => 'products/posters/b.jpg',
            'like_count' => 10,
            'view_count' => 100,
            'share_count' => 2,
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
    // Flag encore a true mais date depassee - simule le court laps de
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
        'created_at' => now()->subHour(),
    ]);

    $freeProduct = Product::factory()->create([
        'user_id' => $freeSeller->id,
        'status' => 'active',
        'poster_url' => 'products/posters/b.jpg',
        'created_at' => now(),
    ]);

    $response = $this->getJson('/api/v1/products/feed?tab=foryou&per_page=10');

    $ids = collect($response->json('data'))->pluck('id')->values();
    $expiredIndex = $ids->search($expiredProduct->id);
    $freeIndex = $ids->search($freeProduct->id);

    // Meme palier de 5 jours pour les deux (creees a 1h d'ecart), et aucun
    // des deux n'est premium actif (l'abonnement du premier a expire) :
    // seule la fraicheur tranche. Le plus recent (freeProduct) doit passer
    // devant, sans egard pour le premium expire.
    $this->assertLessThan($expiredIndex, $freeIndex);
}
}
