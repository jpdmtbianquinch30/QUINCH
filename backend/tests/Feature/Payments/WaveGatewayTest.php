<?php

namespace Tests\Feature\Payments;

use App\Services\PaymentGateway\WaveGateway;
use Illuminate\Http\Client\ConnectionException;
use Illuminate\Http\Client\Factory;
use Illuminate\Support\Facades\Http;
use Tests\TestCase;

class WaveGatewayTest extends TestCase
{
    protected function setUp(): void
    {
        parent::setUp();

        config(['services.wave.api_key' => 'test-key', 'services.wave.base_url' => 'https://api.wave.com/v1']);
    }

    /** Http::fake() cumule les simulations (la première qui correspond gagne) : on repart d'un client neuf. */
    private function fakeOnly(array|callable $stubs): void
    {
        Http::swap(new Factory());
        Http::fake($stubs);
    }

    private function initiate(): array
    {
        return (new WaveGateway())->initiatePayment([
            'amount' => 2000,
            'transaction_id' => 'premium_abc',
            'success_url' => 'https://quinch.sn/ok',
            'error_url' => 'https://quinch.sn/ko',
        ]);
    }

    public function test_the_checkout_request_matches_the_wave_api_and_sends_no_notif_url(): void
    {
        Http::fake(['api.wave.com/*' => Http::response(['id' => 'cos-1', 'wave_launch_url' => 'https://pay.wave.com/c/cos-1'])]);

        $result = $this->initiate();

        $this->assertTrue($result['success']);
        $this->assertSame('https://pay.wave.com/c/cos-1', $result['payment_url']);
        $this->assertSame('cos-1', $result['gateway_reference']);

        Http::assertSent(fn ($r) => $r->url() === 'https://api.wave.com/v1/checkout/sessions'
            && $r['amount'] === '2000'
            && $r['currency'] === 'XOF'
            && $r['client_reference'] === 'premium_abc'
            && !isset($r['notif_url']));
    }

    public function test_a_network_failure_is_reported_instead_of_crashing(): void
    {
        Http::fake(function () {
            throw new ConnectionException('Connection refused');
        });

        $result = $this->initiate();

        $this->assertFalse($result['success']);
    }

    public function test_a_response_without_a_payment_url_is_a_failure(): void
    {
        Http::fake(['api.wave.com/*' => Http::response(['id' => 'cos-1'])]);

        $this->assertFalse($this->initiate()['success']);
    }

    public function test_retrieve_session_returns_the_session_or_null(): void
    {
        $gateway = new WaveGateway();

        $this->fakeOnly(['api.wave.com/v1/checkout/sessions/cos-1' => Http::response(['id' => 'cos-1', 'payment_status' => 'succeeded'])]);
        $this->assertSame('succeeded', $gateway->retrieveSession('cos-1')['payment_status']);

        $this->fakeOnly(['api.wave.com/*' => Http::response([], 404)]);
        $this->assertNull($gateway->retrieveSession('cos-1'));

        $this->fakeOnly(function () {
            throw new ConnectionException('timeout');
        });
        $this->assertNull($gateway->retrieveSession('cos-1'));
    }

    public function test_search_sessions_understands_the_usual_response_shapes(): void
    {
        $gateway = new WaveGateway();
        $session = ['id' => 'cos-1', 'payment_status' => 'succeeded'];

        foreach ([['result' => [$session]], ['data' => [$session]], [$session]] as $body) {
            $this->fakeOnly(['api.wave.com/*' => Http::response($body)]);
            $this->assertSame([$session], $gateway->searchSessions('premium_abc'));
        }

        $this->fakeOnly(['api.wave.com/*' => Http::response([], 500)]);
        $this->assertNull($gateway->searchSessions('premium_abc'));
    }

    public function test_verify_payment_relies_on_the_session_status(): void
    {
        Http::fake(['api.wave.com/v1/checkout/sessions/cos-1' => Http::response(['payment_status' => 'succeeded'])]);

        $this->assertTrue((new WaveGateway())->verifyPayment('cos-1')['verified']);
    }

    public function test_without_an_api_key_nothing_is_sent(): void
    {
        config(['services.wave.api_key' => null]);
        Http::fake();

        $gateway = new WaveGateway();
        $this->assertNull($gateway->retrieveSession('cos-1'));
        $this->assertNull($gateway->searchSessions('premium_abc'));
        $this->assertFalse($this->initiate()['success']);

        Http::assertNothingSent();
    }
}
