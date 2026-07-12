<?php

namespace Tests\Feature\Favorites;

use App\Models\Product;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class FavoritesUnificationTest extends TestCase
{
    use RefreshDatabase;

    /**
     * Régression : le bouton "signet" affiché partout dans le feed
     * (POST /products/{id}/save) manipulait une table "product_saves"
     * totalement déconnectée de la vraie page Favoris (qui lit
     * favorite_items via /favorites). Un produit "sauvegardé" depuis le
     * feed n'apparaissait donc jamais dans les Favoris de l'utilisateur.
     */
    public function test_saving_a_product_from_the_feed_makes_it_appear_in_favorites(): void
    {
        $user = User::factory()->create();
        $product = Product::factory()->create(['status' => 'active']);

        $save = $this->actingAs($user, 'sanctum')->postJson("/api/v1/products/{$product->id}/save");
        $save->assertOk()->assertJsonPath('saved', true);

        $favorites = $this->actingAs($user, 'sanctum')->getJson('/api/v1/favorites');
        $favorites->assertOk();
        $productIds = collect($favorites->json('data'))->pluck('product_id');
        $this->assertTrue($productIds->contains($product->id));
    }

    public function test_toggling_save_twice_removes_it_from_favorites(): void
    {
        $user = User::factory()->create();
        $product = Product::factory()->create(['status' => 'active']);

        $this->actingAs($user, 'sanctum')->postJson("/api/v1/products/{$product->id}/save");
        $second = $this->actingAs($user, 'sanctum')->postJson("/api/v1/products/{$product->id}/save");
        $second->assertOk()->assertJsonPath('saved', false);

        $favorites = $this->actingAs($user, 'sanctum')->getJson('/api/v1/favorites');
        $this->assertCount(0, $favorites->json('data'));
    }

    public function test_feed_reflects_is_saved_status_from_the_unified_favorites_table(): void
    {
        $user = User::factory()->create();
        $product = Product::factory()->create(['status' => 'active']);

        $this->actingAs($user, 'sanctum')->postJson("/api/v1/products/{$product->id}/save");

        $feed = $this->actingAs($user, 'sanctum')->getJson('/api/v1/products/feed');
        $feed->assertOk();
        $item = collect($feed->json('data'))->firstWhere('id', $product->id);
        $this->assertNotNull($item);
        $this->assertTrue($item['is_saved']);
    }
}
