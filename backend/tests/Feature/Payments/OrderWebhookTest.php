<?php

namespace Tests\Feature\Payments;

use App\Models\Product;
use App\Models\Transaction;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

/**
 * Webhooks de COMMANDE (Wave + Orange Money) : idempotence, ordre des
 * événements, vérification du montant, stock.
 */
class OrderWebhookTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();
        config([
            'services.wave.webhook_secret' => 'whsec_test',
            'services.orange_money.webhook_secret' => 'orange_secret',
        ]);
    }

    /** Commande en attente de paiement : stock 1 -> 0 (réservé), prix 1000 + frais 20. */
    private function pendingOrder(array $override = []): Transaction
    {
        $seller = User::factory()->create();
        $buyer = User::factory()->create();
        $product = Product::factory()->create([
            'user_id' => $seller->id, 'status' => 'reserved', 'stock_quantity' => 0, 'price' => 1000,
        ]);

        return Transaction::create(array_merge([
            'buyer_id' => $buyer->id, 'seller_id' => $seller->id, 'product_id' => $product->id,
            'quantity' => 1, 'amount' => 1000, 'currency' => 'XOF', 'payment_method' => 'wave',
            'payment_status' => 'pending', 'order_status' => 'pending_payment',
            'security_check' => 'pending', 'delivery_type' => 'pickup', 'transaction_fee' => 20,
        ], $override));
    }

    private function wave(string $type, Transaction $t, array $extra = [])
    {
        $payload = [
            'type' => $type,
            'data' => array_merge([
                'id' => 'cos-1', 'client_reference' => $t->id,
                'payment_status' => $type === 'checkout.session.completed' ? 'succeeded' : 'failed',
                'amount' => '1020', 'currency' => 'XOF',
            ], $extra),
        ];
        $body = json_encode($payload);
        $ts = time();
        $sig = hash_hmac('sha256', $ts . $body, 'whsec_test');

        return $this->call('POST', '/api/v1/webhooks/wave', [], [], [], [
            'HTTP_Wave-Signature' => "t={$ts},v1={$sig}",
            'CONTENT_TYPE' => 'application/json',
        ], $body);
    }

    private function orange(array $payload)
    {
        $body = json_encode($payload);

        return $this->call('POST', '/api/v1/webhooks/orange-money', [], [], [], [
            'HTTP_X-Orange-Signature' => hash_hmac('sha256', $body, 'orange_secret'),
            'CONTENT_TYPE' => 'application/json',
        ], $body);
    }

    public function test_wave_success_marks_order_paid_and_is_idempotent(): void
    {
        $t = $this->pendingOrder();

        $this->wave('checkout.session.completed', $t)->assertOk();
        $this->wave('checkout.session.completed', $t)->assertOk(); // rejeu

        $t->refresh();
        $this->assertSame('completed', $t->payment_status);
        $this->assertSame('processing', $t->order_status);
        $this->assertSame('cos-1', $t->payment_gateway_id);
    }

    public function test_wave_failure_then_success_pays_without_overselling(): void
    {
        $t = $this->pendingOrder();

        $this->wave('checkout.session.payment_failed', $t)->assertOk();
        $t->refresh();
        // Échec non final : la commande reste en attente, le stock reste réservé.
        $this->assertSame('pending_payment', $t->order_status);
        $this->assertSame(1, $t->payment_failure_count);
        $this->assertSame(0, $t->product->fresh()->stock_quantity);

        $this->wave('checkout.session.completed', $t)->assertOk();
        $t->refresh();
        $this->assertSame('completed', $t->payment_status);
        $this->assertSame('processing', $t->order_status);
        $this->assertSame(0, $t->product->fresh()->stock_quantity);
    }

    public function test_late_wave_failure_never_cancels_a_paid_order(): void
    {
        $t = $this->pendingOrder();

        $this->wave('checkout.session.completed', $t)->assertOk();
        $this->wave('checkout.session.payment_failed', $t)->assertOk();

        $t->refresh();
        $this->assertSame('completed', $t->payment_status);
        $this->assertSame('processing', $t->order_status);
        $this->assertSame(0, $t->product->fresh()->stock_quantity);
    }

    public function test_wave_underpaid_amount_is_rejected(): void
    {
        $t = $this->pendingOrder();

        $this->wave('checkout.session.completed', $t, ['amount' => '10'])->assertOk();

        $t->refresh();
        $this->assertSame('pending', $t->payment_status);
        $this->assertSame('pending_payment', $t->order_status);
        $this->assertSame('manual_review', $t->security_check);
    }

    public function test_wave_missing_amount_or_wrong_currency_is_rejected(): void
    {
        $t = $this->pendingOrder();
        $this->wave('checkout.session.completed', $t, ['amount' => null])->assertOk();
        $this->assertSame('pending', $t->fresh()->payment_status);

        $t2 = $this->pendingOrder();
        $this->wave('checkout.session.completed', $t2, ['currency' => 'EUR'])->assertOk();
        $this->assertSame('pending', $t2->fresh()->payment_status);
    }

    public function test_success_after_reservation_expired_restocks_when_available(): void
    {
        $t = $this->pendingOrder(['order_status' => 'cancelled', 'payment_status' => 'failed']);
        $t->product->update(['stock_quantity' => 1, 'status' => 'active']); // stock libéré par le job

        $this->wave('checkout.session.completed', $t)->assertOk();

        $t->refresh();
        $this->assertSame('completed', $t->payment_status);
        $this->assertSame('processing', $t->order_status);
        $this->assertSame(0, $t->product->fresh()->stock_quantity);
    }

    public function test_success_after_expiry_without_stock_goes_to_manual_review_not_oversold(): void
    {
        $t = $this->pendingOrder(['order_status' => 'cancelled', 'payment_status' => 'failed']);
        $t->product->update(['stock_quantity' => 0, 'status' => 'sold']); // vendu à quelqu'un d'autre

        $this->wave('checkout.session.completed', $t)->assertOk();

        $t->refresh();
        $this->assertSame('completed', $t->payment_status);
        $this->assertSame('disputed', $t->order_status);
        $this->assertSame('manual_review', $t->security_check);
        $this->assertSame(0, $t->product->fresh()->stock_quantity);
    }

    public function test_orange_failed_never_marks_order_paid_and_releases_stock_once(): void
    {
        $t = $this->pendingOrder(['payment_method' => 'orange_money']);

        $this->orange(['order_id' => $t->id, 'status' => 'FAILED'])->assertOk();
        $this->orange(['order_id' => $t->id, 'status' => 'FAILED'])->assertOk(); // rejeu

        $t->refresh();
        $this->assertSame('failed', $t->payment_status);
        $this->assertSame('cancelled', $t->order_status);
        $this->assertNotSame('completed', $t->payment_status);
        $this->assertSame(1, $t->product->fresh()->stock_quantity); // restitué UNE fois
    }

    public function test_orange_success_checks_amount_and_late_failure_is_harmless(): void
    {
        $t = $this->pendingOrder(['payment_method' => 'orange_money']);

        $this->orange(['order_id' => $t->id, 'status' => 'SUCCESS', 'txnid' => 'om-1', 'amount' => 5, 'currency' => 'XOF'])->assertOk();
        $this->assertSame('pending', $t->fresh()->payment_status);

        $this->orange(['order_id' => $t->id, 'status' => 'SUCCESS', 'txnid' => 'om-1', 'amount' => 1020, 'currency' => 'XOF'])->assertOk();
        $this->orange(['order_id' => $t->id, 'status' => 'FAILED'])->assertOk();

        $t->refresh();
        $this->assertSame('completed', $t->payment_status);
        $this->assertSame('processing', $t->order_status);
        $this->assertSame(0, $t->product->fresh()->stock_quantity);
    }

    public function test_orange_webhook_with_garbage_order_id_does_not_500(): void
    {
        $this->orange(['order_id' => 'abc', 'status' => 'SUCCESS'])->assertOk();
        $this->orange(['order_id' => ['x'], 'status' => 'FAILED'])->assertOk();
    }

    public function test_orange_webhook_rejects_bad_signature(): void
    {
        $this->call('POST', '/api/v1/webhooks/orange-money', [], [], [], [
            'HTTP_X-Orange-Signature' => 'nope', 'CONTENT_TYPE' => 'application/json',
        ], json_encode(['order_id' => 'x', 'status' => 'SUCCESS']))->assertStatus(401);
    }
}
