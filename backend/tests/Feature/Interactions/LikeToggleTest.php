<?php

namespace Tests\Feature\Interactions;

use App\Models\Product;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Tests\TestCase;

class LikeToggleTest extends TestCase
{
    use RefreshDatabase;

    private function makeProduct(int $likeCount = 0): Product
    {
        $seller = User::factory()->create(['is_seller' => true, 'account_status' => 'active']);

        return Product::factory()->create([
            'user_id' => $seller->id,
            'status' => 'active',
            'like_count' => $likeCount,
        ]);
    }

    public function test_like_then_unlike_updates_the_counter(): void
    {
        $product = $this->makeProduct();
        $buyer = User::factory()->create(['phone_verified' => true]);

        $this->actingAs($buyer, 'sanctum')
            ->postJson("/api/v1/products/{$product->id}/like")
            ->assertOk()
            ->assertJson(['liked' => true, 'like_count' => 1]);

        $this->actingAs($buyer, 'sanctum')
            ->postJson("/api/v1/products/{$product->id}/like")
            ->assertOk()
            ->assertJson(['liked' => false, 'like_count' => 0]);

        $this->assertDatabaseMissing('product_likes', ['user_id' => $buyer->id, 'product_id' => $product->id]);
    }

    public function test_unlike_never_makes_the_counter_negative(): void
    {
        $product = $this->makeProduct(0);
        $buyer = User::factory()->create(['phone_verified' => true]);

        // Compteur déjà désynchronisé (0) alors qu'un like existe.
        DB::table('product_likes')->insert([
            'user_id' => $buyer->id,
            'product_id' => $product->id,
            'created_at' => now(),
            'updated_at' => now(),
        ]);

        $this->actingAs($buyer, 'sanctum')
            ->postJson("/api/v1/products/{$product->id}/like")
            ->assertOk()
            ->assertJson(['liked' => false, 'like_count' => 0]);
    }

    public function test_save_toggle_twice_adds_then_removes(): void
    {
        $product = $this->makeProduct();
        $buyer = User::factory()->create(['phone_verified' => true]);

        $this->actingAs($buyer, 'sanctum')
            ->postJson("/api/v1/products/{$product->id}/save")
            ->assertOk()
            ->assertJson(['saved' => true]);

        $this->actingAs($buyer, 'sanctum')
            ->postJson("/api/v1/products/{$product->id}/save")
            ->assertOk()
            ->assertJson(['saved' => false]);
    }
}
