<?php

namespace Tests\Feature\Negotiation;

use App\Models\Negotiation;
use App\Models\Product;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class NegotiationTest extends TestCase
{
    use RefreshDatabase;

    public function test_buyer_can_propose_a_price_on_a_negotiable_product(): void
    {
        $seller = User::factory()->create();
        $buyer = User::factory()->create();
        $product = Product::factory()->create(['user_id' => $seller->id, 'is_negotiable' => true, 'price' => 10000]);

        $response = $this->actingAs($buyer, 'sanctum')->postJson('/api/v1/negotiations/propose', [
            'product_id' => $product->id,
            'proposed_price' => 8000,
            'message' => 'Dernier prix ?',
        ]);

        $response->assertCreated()->assertJsonPath('negotiation.proposed_price', 8000);
        $this->assertDatabaseHas('negotiations', ['product_id' => $product->id, 'buyer_id' => $buyer->id, 'status' => 'pending']);
    }

    public function test_cannot_propose_on_a_non_negotiable_product(): void
    {
        $seller = User::factory()->create();
        $buyer = User::factory()->create();
        $product = Product::factory()->create(['user_id' => $seller->id, 'is_negotiable' => false]);

        $response = $this->actingAs($buyer, 'sanctum')->postJson('/api/v1/negotiations/propose', [
            'product_id' => $product->id,
            'proposed_price' => 1000,
        ]);

        $response->assertUnprocessable();
    }

    public function test_seller_cannot_negotiate_their_own_product(): void
    {
        $seller = User::factory()->create();
        $product = Product::factory()->create(['user_id' => $seller->id, 'is_negotiable' => true]);

        $response = $this->actingAs($seller, 'sanctum')->postJson('/api/v1/negotiations/propose', [
            'product_id' => $product->id,
            'proposed_price' => 1000,
        ]);

        $response->assertUnprocessable();
    }

    /**
     * C'est le scénario qui plantait avant correction : $validated['status']
     * n'existait jamais, provoquant une TypeError fatale sur ce paramètre
     * strictement typé string de notifyNegotiation().
     */
    public function test_seller_can_accept_an_offer_without_crashing(): void
    {
        $seller = User::factory()->create();
        $buyer = User::factory()->create();
        $product = Product::factory()->create(['user_id' => $seller->id, 'is_negotiable' => true]);
        $negotiation = Negotiation::create([
            'buyer_id' => $buyer->id,
            'seller_id' => $seller->id,
            'product_id' => $product->id,
            'proposed_price' => 5000,
            'expires_at' => now()->addHours(24),
        ]);

        $response = $this->actingAs($seller, 'sanctum')->postJson("/api/v1/negotiations/{$negotiation->id}/respond", [
            'action' => 'accept',
        ]);

        $response->assertOk()->assertJsonPath('negotiation.status', 'accepted');
    }

    public function test_seller_can_reject_an_offer_without_crashing(): void
    {
        $seller = User::factory()->create();
        $buyer = User::factory()->create();
        $product = Product::factory()->create(['user_id' => $seller->id, 'is_negotiable' => true]);
        $negotiation = Negotiation::create([
            'buyer_id' => $buyer->id,
            'seller_id' => $seller->id,
            'product_id' => $product->id,
            'proposed_price' => 5000,
            'expires_at' => now()->addHours(24),
        ]);

        $response = $this->actingAs($seller, 'sanctum')->postJson("/api/v1/negotiations/{$negotiation->id}/respond", [
            'action' => 'reject',
        ]);

        $response->assertOk()->assertJsonPath('negotiation.status', 'rejected');
    }

    public function test_seller_can_counter_an_offer_without_crashing(): void
    {
        $seller = User::factory()->create();
        $buyer = User::factory()->create();
        $product = Product::factory()->create(['user_id' => $seller->id, 'is_negotiable' => true]);
        $negotiation = Negotiation::create([
            'buyer_id' => $buyer->id,
            'seller_id' => $seller->id,
            'product_id' => $product->id,
            'proposed_price' => 5000,
            'expires_at' => now()->addHours(24),
        ]);

        $response = $this->actingAs($seller, 'sanctum')->postJson("/api/v1/negotiations/{$negotiation->id}/respond", [
            'action' => 'counter',
            'counter_price' => 7000,
        ]);

        $response->assertOk()
            ->assertJsonPath('negotiation.status', 'countered')
            ->assertJsonPath('negotiation.counter_price', 7000);
    }

    public function test_buyer_cannot_respond_to_their_own_proposal(): void
    {
        $seller = User::factory()->create();
        $buyer = User::factory()->create();
        $product = Product::factory()->create(['user_id' => $seller->id, 'is_negotiable' => true]);
        $negotiation = Negotiation::create([
            'buyer_id' => $buyer->id,
            'seller_id' => $seller->id,
            'product_id' => $product->id,
            'proposed_price' => 5000,
            'expires_at' => now()->addHours(24),
        ]);

        $response = $this->actingAs($buyer, 'sanctum')->postJson("/api/v1/negotiations/{$negotiation->id}/respond", [
            'action' => 'accept',
        ]);

        $response->assertForbidden();
    }

    public function test_cannot_respond_to_an_expired_offer(): void
    {
        $seller = User::factory()->create();
        $buyer = User::factory()->create();
        $product = Product::factory()->create(['user_id' => $seller->id, 'is_negotiable' => true]);
        $negotiation = Negotiation::create([
            'buyer_id' => $buyer->id,
            'seller_id' => $seller->id,
            'product_id' => $product->id,
            'proposed_price' => 5000,
            'expires_at' => now()->subHour(),
        ]);

        $response = $this->actingAs($seller, 'sanctum')->postJson("/api/v1/negotiations/{$negotiation->id}/respond", [
            'action' => 'accept',
        ]);

        $response->assertUnprocessable();
    }
}
