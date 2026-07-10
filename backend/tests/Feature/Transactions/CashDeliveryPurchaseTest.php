<?php

namespace Tests\Feature\Transactions;

use App\Models\Product;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class CashDeliveryPurchaseTest extends TestCase
{
    use RefreshDatabase;

    public function test_buyer_can_initiate_a_cash_delivery_purchase(): void
    {
        $seller = User::factory()->create();
        $buyer = User::factory()->create();
        $product = Product::factory()->create(['user_id' => $seller->id, 'status' => 'active']);

        $response = $this->actingAs($buyer, 'sanctum')->postJson('/api/v1/transactions/initiate', [
            'product_id' => $product->id,
            'payment_method' => 'cash_delivery',
            'delivery_type' => 'pickup',
        ]);

        $response->assertCreated()
            ->assertJsonPath('transaction.payment_method', 'cash_delivery')
            ->assertJsonPath('transaction.payment_status', 'pending');

        $this->assertDatabaseHas('transactions', [
            'product_id' => $product->id,
            'buyer_id' => $buyer->id,
            'seller_id' => $seller->id,
            'payment_method' => 'cash_delivery',
        ]);

        // Le produit doit passer en "reserved" pour ne plus être achetable
        // par quelqu'un d'autre pendant la transaction.
        $this->assertDatabaseHas('products', [
            'id' => $product->id,
            'status' => 'reserved',
        ]);
    }

    public function test_v1_rejects_wave_and_orange_money_and_free_money(): void
    {
        // V1 : seul cash_delivery est activé (voir config/quinch.php et
        // QUINCH_PAYMENT_METHODS). Les autres moyens de paiement doivent être
        // refusés par la validation tant que les webhooks providers ne sont
        // pas validés en conditions réelles.
        $seller = User::factory()->create();
        $buyer = User::factory()->create();
        $product = Product::factory()->create(['user_id' => $seller->id, 'status' => 'active']);

        foreach (['wave', 'orange_money', 'free_money'] as $method) {
            $response = $this->actingAs($buyer, 'sanctum')->postJson('/api/v1/transactions/initiate', [
                'product_id' => $product->id,
                'payment_method' => $method,
                'delivery_type' => 'pickup',
            ]);

            $response->assertUnprocessable()
                ->assertJsonValidationErrors(['payment_method']);
        }
    }

    public function test_seller_cannot_buy_their_own_product(): void
    {
        $seller = User::factory()->create();
        $product = Product::factory()->create(['user_id' => $seller->id, 'status' => 'active']);

        $response = $this->actingAs($seller, 'sanctum')->postJson('/api/v1/transactions/initiate', [
            'product_id' => $product->id,
            'payment_method' => 'cash_delivery',
            'delivery_type' => 'pickup',
        ]);

        $response->assertUnprocessable()
            ->assertJson(['message' => 'Vous ne pouvez pas acheter votre propre produit.']);
    }

    public function test_cannot_buy_a_product_that_is_not_active(): void
    {
        $seller = User::factory()->create();
        $buyer = User::factory()->create();
        $product = Product::factory()->create(['user_id' => $seller->id, 'status' => 'sold']);

        $response = $this->actingAs($buyer, 'sanctum')->postJson('/api/v1/transactions/initiate', [
            'product_id' => $product->id,
            'payment_method' => 'cash_delivery',
            'delivery_type' => 'pickup',
        ]);

        $response->assertUnprocessable()
            ->assertJson(['message' => 'Ce produit n\'est plus disponible.']);
    }

    public function test_buyer_can_confirm_their_own_cash_delivery_transaction(): void
    {
        $seller = User::factory()->create();
        $buyer = User::factory()->create();
        $product = Product::factory()->create(['user_id' => $seller->id, 'status' => 'active']);

        $initiate = $this->actingAs($buyer, 'sanctum')->postJson('/api/v1/transactions/initiate', [
            'product_id' => $product->id,
            'payment_method' => 'cash_delivery',
            'delivery_type' => 'pickup',
        ]);
        $transactionId = $initiate->json('transaction.id');

        $confirm = $this->actingAs($buyer, 'sanctum')
            ->postJson("/api/v1/transactions/{$transactionId}/confirm");

        $confirm->assertOk();
        $this->assertDatabaseHas('transactions', [
            'id' => $transactionId,
            'payment_status' => 'completed',
        ]);
    }

    public function test_a_different_buyer_cannot_confirm_someone_elses_transaction(): void
    {
        $seller = User::factory()->create();
        $buyer = User::factory()->create();
        $stranger = User::factory()->create();
        $product = Product::factory()->create(['user_id' => $seller->id, 'status' => 'active']);

        $initiate = $this->actingAs($buyer, 'sanctum')->postJson('/api/v1/transactions/initiate', [
            'product_id' => $product->id,
            'payment_method' => 'cash_delivery',
            'delivery_type' => 'pickup',
        ]);
        $transactionId = $initiate->json('transaction.id');

        $confirm = $this->actingAs($stranger, 'sanctum')
            ->postJson("/api/v1/transactions/{$transactionId}/confirm");

        $confirm->assertForbidden();
    }
}
