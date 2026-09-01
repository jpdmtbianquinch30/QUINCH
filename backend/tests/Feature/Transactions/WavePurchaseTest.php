<?php

namespace Tests\Feature\Transactions;

use App\Models\Product;
use App\Models\Transaction;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Http;
use Tests\TestCase;

class WavePurchaseTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();

        // Clé Wave factice pour que WaveGateway ne refuse pas la requête
        // dès le départ (voir WaveGateway::initiatePayment).
        config(['services.wave.api_key' => 'test-key']);
    }

    private function fakeSuccessfulWaveCheckout(): void
    {
        Http::fake([
            'api.wave.com/v1/checkout/sessions' => Http::response([
                'id' => 'cs-test-123',
                'wave_launch_url' => 'https://checkout.wave.com/cs-test-123',
            ], 200),
        ]);
    }

    public function test_buyer_can_initiate_a_wave_purchase(): void
    {
        $this->fakeSuccessfulWaveCheckout();

        $seller = User::factory()->create();
        $buyer = User::factory()->create();
        $product = Product::factory()->create([
            'user_id' => $seller->id,
            'status' => 'active',
            'stock_quantity' => 1,
        ]);

        $response = $this->actingAs($buyer, 'sanctum')->postJson('/api/v1/transactions/initiate', [
            'product_id' => $product->id,
            'payment_method' => 'wave',
            'delivery_type' => 'pickup',
        ]);

        $response->assertCreated()
            ->assertJsonPath('transaction.payment_method', 'wave')
            ->assertJsonPath('transaction.payment_status', 'pending')
            ->assertJsonPath('transaction.order_status', 'pending_payment')
            ->assertJsonStructure(['payment_url']);

        $this->assertDatabaseHas('transactions', [
            'product_id' => $product->id,
            'buyer_id' => $buyer->id,
            'seller_id' => $seller->id,
            'payment_method' => 'wave',
        ]);

        // Le stock doit être décrémenté immédiatement (verrou pessimiste).
        $this->assertDatabaseHas('products', [
            'id' => $product->id,
            'stock_quantity' => 0,
            'status' => 'reserved',
        ]);
    }

    public function test_rejects_a_payment_method_not_in_enabled_list(): void
    {
        // Par défaut QUINCH_PAYMENT_METHODS=wave : orange_money est
        // implémenté mais pas forcément activé selon l'environnement.
        config(['quinch.enabled_payment_methods' => ['wave']]);

        $seller = User::factory()->create();
        $buyer = User::factory()->create();
        $product = Product::factory()->create(['user_id' => $seller->id, 'status' => 'active']);

        $response = $this->actingAs($buyer, 'sanctum')->postJson('/api/v1/transactions/initiate', [
            'product_id' => $product->id,
            'payment_method' => 'orange_money',
            'delivery_type' => 'pickup',
        ]);

        $response->assertUnprocessable()
            ->assertJsonValidationErrors(['payment_method']);
    }

    public function test_seller_cannot_buy_their_own_product(): void
    {
        $this->fakeSuccessfulWaveCheckout();

        $seller = User::factory()->create();
        $product = Product::factory()->create(['user_id' => $seller->id, 'status' => 'active']);

        $response = $this->actingAs($seller, 'sanctum')->postJson('/api/v1/transactions/initiate', [
            'product_id' => $product->id,
            'payment_method' => 'wave',
            'delivery_type' => 'pickup',
        ]);

        $response->assertUnprocessable()
            ->assertJson(['message' => 'Vous ne pouvez pas acheter votre propre produit.']);
    }

    public function test_cannot_buy_a_product_that_is_out_of_stock(): void
    {
        $this->fakeSuccessfulWaveCheckout();

        $seller = User::factory()->create();
        $buyer = User::factory()->create();
        $product = Product::factory()->create([
            'user_id' => $seller->id,
            'status' => 'active',
            'stock_quantity' => 0,
        ]);

        $response = $this->actingAs($buyer, 'sanctum')->postJson('/api/v1/transactions/initiate', [
            'product_id' => $product->id,
            'payment_method' => 'wave',
            'delivery_type' => 'pickup',
        ]);

        $response->assertUnprocessable()
            ->assertJson(['message' => 'Ce produit n\'est plus disponible en quantité suffisante.']);
    }

    public function test_stock_is_released_when_wave_checkout_creation_fails(): void
    {
        Http::fake([
            'api.wave.com/v1/checkout/sessions' => Http::response(['error' => 'invalid_request'], 400),
        ]);

        $seller = User::factory()->create();
        $buyer = User::factory()->create();
        $product = Product::factory()->create([
            'user_id' => $seller->id,
            'status' => 'active',
            'stock_quantity' => 1,
        ]);

        $response = $this->actingAs($buyer, 'sanctum')->postJson('/api/v1/transactions/initiate', [
            'product_id' => $product->id,
            'payment_method' => 'wave',
            'delivery_type' => 'pickup',
        ]);

        $response->assertStatus(502);

        // Le stock ne doit pas rester bloqué si la création de la session
        // de paiement échoue côté Wave.
        $this->assertDatabaseHas('products', [
            'id' => $product->id,
            'stock_quantity' => 1,
            'status' => 'active',
        ]);
    }

    public function test_wave_webhook_activates_transaction_with_valid_signature(): void
    {
        config(['services.wave.webhook_secret' => 'whsec_test']);

        $seller = User::factory()->create();
        $buyer = User::factory()->create();
        $product = Product::factory()->create(['user_id' => $seller->id, 'status' => 'reserved']);

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

        $body = json_encode([
            'type' => 'checkout.session.completed',
            'data' => [
                'id' => 'cs-test-123',
                'client_reference' => $transaction->id,
                'payment_status' => 'succeeded',
            ],
        ]);

        $timestamp = time();
        $signature = hash_hmac('sha256', $timestamp . $body, 'whsec_test');

        $response = $this->call('POST', '/api/v1/webhooks/wave', [], [], [], [
            'HTTP_Wave-Signature' => "t={$timestamp},v1={$signature}",
            'CONTENT_TYPE' => 'application/json',
        ], $body);

        $response->assertOk();
        $this->assertDatabaseHas('transactions', [
            'id' => $transaction->id,
            'payment_status' => 'completed',
            'order_status' => 'processing',
        ]);
    }

    public function test_wave_webhook_rejects_invalid_signature(): void
    {
        config(['services.wave.webhook_secret' => 'whsec_test']);

        $response = $this->postJson('/api/v1/webhooks/wave', [
            'type' => 'checkout.session.completed',
            'data' => ['client_reference' => 'whatever', 'payment_status' => 'succeeded'],
        ], ['Wave-Signature' => 't=1,v1=invalid']);

        $response->assertStatus(401);
    }
}
