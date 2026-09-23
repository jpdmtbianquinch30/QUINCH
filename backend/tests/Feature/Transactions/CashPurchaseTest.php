<?php

namespace Tests\Feature\Transactions;

use App\Models\Product;
use App\Models\Transaction;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class CashPurchaseTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();
        config(['quinch.enabled_payment_methods' => ['cash']]);
    }

    private function createCashTransaction(User $seller, User $buyer): Transaction
    {
        $product = Product::factory()->create([
            'user_id' => $seller->id,
            'status' => 'active',
            'stock_quantity' => 1,
        ]);

        $response = $this->actingAs($buyer, 'sanctum')->postJson('/api/v1/transactions/initiate', [
            'product_id' => $product->id,
            'payment_method' => 'cash',
            'delivery_type' => 'meetup',
        ]);

        $response->assertCreated()->assertJsonPath('transaction.payment_status', 'pending');

        return Transaction::where('product_id', $product->id)->firstOrFail();
    }

    public function test_cash_order_can_progress_through_the_full_flow_despite_pending_payment_status(): void
    {
        $seller = User::factory()->create();
        $buyer = User::factory()->create();
        $transaction = $this->createCashTransaction($seller, $buyer);

        $this->actingAs($seller, 'sanctum')
            ->putJson("/api/v1/transactions/{$transaction->id}/status", ['status' => 'processing'])
            ->assertOk();

        $this->actingAs($seller, 'sanctum')
            ->putJson("/api/v1/transactions/{$transaction->id}/status", ['status' => 'shipped'])
            ->assertOk();

        $this->actingAs($seller, 'sanctum')
            ->putJson("/api/v1/transactions/{$transaction->id}/status", ['status' => 'delivered'])
            ->assertOk();

        $response = $this->actingAs($buyer, 'sanctum')
            ->putJson("/api/v1/transactions/{$transaction->id}/status", ['status' => 'completed']);

        $response->assertOk()->assertJsonPath('message', 'Réception confirmée. Merci !');

        $transaction->refresh();
        $this->assertEquals('completed', $transaction->order_status);
        $this->assertEquals('completed', $transaction->payment_status);
        $this->assertNotNull($transaction->completed_at);
    }

    public function test_cash_order_can_still_be_cancelled_while_pending(): void
    {
        $seller = User::factory()->create();
        $buyer = User::factory()->create();
        $transaction = $this->createCashTransaction($seller, $buyer);

        $this->actingAs($buyer, 'sanctum')
            ->putJson("/api/v1/transactions/{$transaction->id}/status", ['status' => 'cancelled'])
            ->assertOk();

        $this->assertEquals('cancelled', $transaction->fresh()->order_status);
    }

    public function test_online_gateway_order_still_blocked_until_payment_confirmed(): void
    {
        config(['quinch.enabled_payment_methods' => ['wave']]);

        $seller = User::factory()->create();
        $buyer = User::factory()->create();
        $product = Product::factory()->create(['user_id' => $seller->id, 'status' => 'active', 'stock_quantity' => 1]);

        $transaction = Transaction::create([
            'buyer_id' => $buyer->id,
            'seller_id' => $seller->id,
            'product_id' => $product->id,
            'quantity' => 1,
            'amount' => $product->price,
            'currency' => 'XOF',
            'payment_method' => 'wave',
            'payment_status' => 'pending',
            'order_status' => 'pending_payment',
            'security_check' => 'pending',
            'delivery_type' => 'pickup',
            'transaction_fee' => 0,
        ]);

        $this->actingAs($seller, 'sanctum')
            ->putJson("/api/v1/transactions/{$transaction->id}/status", ['status' => 'processing'])
            ->assertStatus(422)
            ->assertJsonPath('message', "Le paiement n'a pas encore été confirmé par la passerelle.");
    }
}
