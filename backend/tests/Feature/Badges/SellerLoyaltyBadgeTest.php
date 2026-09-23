<?php

namespace Tests\Feature\Badges;

use App\Models\Product;
use App\Models\Transaction;
use App\Models\User;
use App\Models\UserBadge;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class SellerLoyaltyBadgeTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();
        config(['quinch.features.badges' => true]);
    }

    private function completedTransaction(User $seller, User $buyer): Transaction
    {
        $product = Product::factory()->create(['user_id' => $seller->id]);

        return Transaction::create([
            'buyer_id' => $buyer->id,
            'seller_id' => $seller->id,
            'product_id' => $product->id,
            'amount' => 5000,
            'currency' => 'XOF',
            'payment_method' => 'wave',
            'payment_status' => 'completed',
            'order_status' => 'delivered',
        ]);
    }

    public function test_seller_can_award_loyalty_badge_to_a_real_buyer(): void
    {
        $seller = User::factory()->create();
        $buyer = User::factory()->create();
        $this->completedTransaction($seller, $buyer);

        $response = $this->actingAs($seller, 'sanctum')
            ->postJson("/api/v1/users/{$buyer->id}/loyalty-badge", ['reason' => 'Client depuis 6 mois']);

        $response->assertOk()->assertJsonPath('badge.type', 'loyal_customer');

        $this->assertDatabaseHas('user_badges', [
            'user_id' => $buyer->id,
            'badge_type' => 'loyal_customer',
            'awarded_by' => $seller->id,
        ]);
    }

    public function test_seller_cannot_award_badge_to_someone_who_never_bought_from_them(): void
    {
        $seller = User::factory()->create();
        $stranger = User::factory()->create();

        $response = $this->actingAs($seller, 'sanctum')
            ->postJson("/api/v1/users/{$stranger->id}/loyalty-badge");

        $response->assertStatus(403);
        $this->assertDatabaseMissing('user_badges', ['user_id' => $stranger->id]);
    }

    public function test_seller_cannot_award_badge_to_themselves(): void
    {
        $seller = User::factory()->create();

        $response = $this->actingAs($seller, 'sanctum')
            ->postJson("/api/v1/users/{$seller->id}/loyalty-badge");

        $response->assertStatus(422);
    }

    public function test_seller_cannot_revoke_a_badge_awarded_by_another_seller(): void
    {
        $sellerA = User::factory()->create();
        $sellerB = User::factory()->create();
        $buyer = User::factory()->create();
        $this->completedTransaction($sellerA, $buyer);
        $this->completedTransaction($sellerB, $buyer);

        UserBadge::create([
            'user_id' => $buyer->id,
            'badge_type' => 'loyal_customer',
            'awarded_by' => $sellerA->id,
        ]);

        $this->actingAs($sellerB, 'sanctum')
            ->deleteJson("/api/v1/users/{$buyer->id}/loyalty-badge")
            ->assertOk();

        $this->assertDatabaseHas('user_badges', [
            'user_id' => $buyer->id,
            'badge_type' => 'loyal_customer',
            'awarded_by' => $sellerA->id,
        ]);
    }

    public function test_my_customers_lists_only_buyers_with_completed_purchases(): void
    {
        $seller = User::factory()->create();
        $buyer = User::factory()->create();
        $this->completedTransaction($seller, $buyer);

        $otherBuyer = User::factory()->create();
        $product = Product::factory()->create(['user_id' => $seller->id]);
        Transaction::create([
            'buyer_id' => $otherBuyer->id,
            'seller_id' => $seller->id,
            'product_id' => $product->id,
            'amount' => 1000,
            'currency' => 'XOF',
            'payment_method' => 'wave',
            'payment_status' => 'pending',
            'order_status' => 'pending_payment',
        ]);

        $response = $this->actingAs($seller, 'sanctum')->getJson('/api/v1/my-customers');

        $response->assertOk();
        $ids = collect($response->json('customers'))->pluck('id');
        $this->assertTrue($ids->contains($buyer->id));
        $this->assertFalse($ids->contains($otherBuyer->id));
    }

    public function test_loyalty_badge_endpoints_are_hidden_when_feature_flag_disabled(): void
    {
        config(['quinch.features.badges' => false]);
        $seller = User::factory()->create();
        $buyer = User::factory()->create();

        $this->actingAs($seller, 'sanctum')
            ->postJson("/api/v1/users/{$buyer->id}/loyalty-badge")
            ->assertNotFound();
    }
}
