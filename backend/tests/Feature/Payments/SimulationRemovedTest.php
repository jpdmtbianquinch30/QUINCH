<?php

namespace Tests\Feature\Payments;

use App\Services\PaymentGateway\WaveGateway;
use Tests\TestCase;

/**
 * Garantit que le mode simulation de paiement a disparu pour de bon.
 */
class SimulationRemovedTest extends TestCase
{
    public function test_simulation_routes_no_longer_exist(): void
    {
        $this->get('/dev/simulate-payment?reference=x&amount=100')->assertNotFound();
        $this->post('/dev/simulate-payment/confirm', ['reference' => 'x', 'outcome' => 'success'])->assertNotFound();
    }

    public function test_wave_without_api_key_fails_instead_of_simulating(): void
    {
        config(['services.wave.api_key' => null]);

        $result = (new WaveGateway())->initiatePayment([
            'transaction_id' => 'tx-1',
            'amount' => 1000,
            'success_url' => 'https://quinch.sn/ok',
            'error_url' => 'https://quinch.sn/ko',
        ]);

        $this->assertFalse($result['success']);
        $this->assertArrayNotHasKey('payment_url', $result);
    }
}
