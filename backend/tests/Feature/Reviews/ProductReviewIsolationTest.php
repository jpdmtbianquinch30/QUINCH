<?php

namespace Tests\Feature\Reviews;

use App\Models\Conversation;
use App\Models\Message;
use App\Models\Product;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class ProductReviewIsolationTest extends TestCase
{
    use RefreshDatabase;

    /** Un avis exige une relation réelle : ici, le visiteur a écrit au vendeur. */
    private function talk(User $buyer, User $seller): void
    {
        $c = Conversation::create(['buyer_id' => $buyer->id, 'seller_id' => $seller->id, 'status' => 'active', 'last_message_at' => now()]);
        Message::create(['conversation_id' => $c->id, 'sender_id' => $buyer->id, 'body' => 'Bonjour', 'type' => 'text']);
    }

    public function test_review_only_appears_on_its_own_product(): void
    {
        $seller = User::factory()->create();
        $buyer = User::factory()->create();
        $a = Product::factory()->create(['user_id' => $seller->id]);
        $b = Product::factory()->create(['user_id' => $seller->id]);

        $this->talk($buyer, $seller);
        Sanctum::actingAs($buyer);
        $this->postJson('/api/v1/reviews', [
            'seller_id' => $seller->id, 'product_id' => $a->id, 'rating' => 5, 'comment' => 'Top',
        ])->assertCreated();

        $this->getJson("/api/v1/users/{$seller->id}/reviews?product_id={$a->id}")
            ->assertOk()->assertJsonPath('stats.total', 1);
        $this->getJson("/api/v1/users/{$seller->id}/reviews?product_id={$b->id}")
            ->assertOk()->assertJsonPath('stats.total', 0);
        // Profil vendeur (sans product_id) : tous les avis du vendeur.
        $this->getJson("/api/v1/users/{$seller->id}/reviews")
            ->assertOk()->assertJsonPath('stats.total', 1);
    }

    public function test_same_user_can_review_two_products_but_not_twice_the_same(): void
    {
        $seller = User::factory()->create();
        $buyer = User::factory()->create();
        $a = Product::factory()->create(['user_id' => $seller->id]);
        $b = Product::factory()->create(['user_id' => $seller->id]);

        $this->talk($buyer, $seller);
        Sanctum::actingAs($buyer);
        $this->postJson('/api/v1/reviews', ['seller_id' => $seller->id, 'product_id' => $a->id, 'rating' => 4])->assertCreated();
        $this->postJson('/api/v1/reviews', ['seller_id' => $seller->id, 'product_id' => $b->id, 'rating' => 3])->assertCreated();
        $this->postJson('/api/v1/reviews', ['seller_id' => $seller->id, 'product_id' => $a->id, 'rating' => 1])->assertStatus(422);
    }

    public function test_product_must_belong_to_the_reviewed_seller(): void
    {
        $seller = User::factory()->create();
        $other = User::factory()->create();
        $buyer = User::factory()->create();
        $foreign = Product::factory()->create(['user_id' => $other->id]);

        $this->talk($buyer, $seller);
        Sanctum::actingAs($buyer);
        $this->postJson('/api/v1/reviews', ['seller_id' => $seller->id, 'product_id' => $foreign->id, 'rating' => 5])
            ->assertStatus(422);
    }

    public function test_invalid_product_id_filter_is_rejected(): void
    {
        $seller = User::factory()->create();
        $this->getJson("/api/v1/users/{$seller->id}/reviews?product_id=pas-un-uuid")->assertStatus(422);
    }
}
