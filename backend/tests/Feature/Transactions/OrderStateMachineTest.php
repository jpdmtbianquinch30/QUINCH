<?php

namespace Tests\Feature\Transactions;

use App\Models\FavoriteCollection;
use App\Models\Product;
use App\Models\Transaction;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class OrderStateMachineTest extends TestCase
{
    use RefreshDatabase;

    private function order(string $orderStatus, string $paymentStatus = 'completed'): array
    {
        $seller = User::factory()->create();
        $buyer = User::factory()->create();
        $product = Product::factory()->create(['user_id' => $seller->id, 'status' => 'reserved', 'stock_quantity' => 0]);
        $t = Transaction::create([
            'buyer_id' => $buyer->id, 'seller_id' => $seller->id, 'product_id' => $product->id, 'quantity' => 1,
            'amount' => 1000, 'currency' => 'XOF', 'payment_method' => 'wave', 'payment_status' => $paymentStatus,
            'order_status' => $orderStatus, 'security_check' => 'passed', 'delivery_type' => 'pickup', 'transaction_fee' => 0,
        ]);

        return [$seller, $buyer, $product, $t];
    }

    public function test_delivered_cannot_be_repeated_to_inflate_trust_score(): void
    {
        [$seller, , , $t] = $this->order('processing');
        Sanctum::actingAs($seller);

        $this->putJson("/api/v1/transactions/{$t->id}/status", ['status' => 'delivered'])->assertOk();
        $afterFirst = $seller->fresh()->trust_score;
        $this->putJson("/api/v1/transactions/{$t->id}/status", ['status' => 'delivered'])->assertStatus(422);

        $this->assertEquals($afterFirst, $seller->fresh()->trust_score);
    }

    public function test_seller_cannot_mark_a_disputed_order_as_delivered(): void
    {
        [$seller, , , $t] = $this->order('disputed');
        Sanctum::actingAs($seller);

        $this->putJson("/api/v1/transactions/{$t->id}/status", ['status' => 'delivered'])->assertStatus(422);
        $this->assertSame('disputed', $t->fresh()->order_status);
    }

    public function test_seller_cancellation_restores_stock(): void
    {
        [$seller, , $product, $t] = $this->order('processing');
        Sanctum::actingAs($seller);

        $this->putJson("/api/v1/transactions/{$t->id}/status", ['status' => 'cancelled'])->assertOk();

        $product->refresh();
        $this->assertSame(1, $product->stock_quantity);
        $this->assertSame('active', $product->status);
        $this->assertSame('manual_review', $t->fresh()->security_check); // payée : remboursement à traiter
    }

    public function test_buyer_cannot_cancel_once_paid(): void
    {
        [, $buyer, , $t] = $this->order('pending_payment', 'completed');
        Sanctum::actingAs($buyer);

        $this->putJson("/api/v1/transactions/{$t->id}/status", ['status' => 'cancelled'])->assertStatus(422);
        $this->assertSame('pending_payment', $t->fresh()->order_status);
        $this->assertSame('completed', $t->fresh()->payment_status);
    }

    public function test_buyer_cancel_of_unpaid_order_restores_stock(): void
    {
        [, $buyer, $product, $t] = $this->order('pending_payment', 'pending');
        Sanctum::actingAs($buyer);

        $this->putJson("/api/v1/transactions/{$t->id}/status", ['status' => 'cancelled'])->assertOk();
        $this->assertSame(1, $product->fresh()->stock_quantity);
    }

    public function test_favorite_collection_of_another_user_is_refused(): void
    {
        $owner = User::factory()->create();
        $me = User::factory()->create();
        $collection = FavoriteCollection::create(['user_id' => $owner->id, 'name' => 'Privée']);
        $product = Product::factory()->create(['status' => 'active']);

        Sanctum::actingAs($me);
        $this->postJson('/api/v1/favorites/toggle', ['product_id' => $product->id, 'collection_id' => $collection->id])->assertStatus(422);
    }

    public function test_view_counter_counts_once_per_visitor_in_a_window(): void
    {
        $product = Product::factory()->create(['status' => 'active', 'view_count' => 0]);

        for ($i = 0; $i < 5; $i++) {
            $this->postJson("/api/v1/products/{$product->id}/view")->assertOk();
        }

        $this->assertSame(1, (int) $product->fresh()->view_count);
    }

    public function test_password_rules_are_the_same_everywhere(): void
    {
        $user = User::factory()->create(['password' => bcrypt('Secret123')]);
        Sanctum::actingAs($user);

        // Sans majuscule / minuscule / chiffre : refus au changement (avant : seulement 8 caractères).
        foreach (['motdepasse', 'MOTDEPASSE1', 'Motdepasse'] as $weak) {
            $this->putJson('/api/v1/auth/change-password', [
                'current_password' => 'Secret123', 'new_password' => $weak, 'new_password_confirmation' => $weak,
            ])->assertStatus(422)->assertJsonValidationErrors(['new_password']);
        }
    }
}
