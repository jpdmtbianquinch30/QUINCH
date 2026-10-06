<?php

namespace Tests\Feature\Auth;

use App\Services\Sms\LogSmsGateway;
use App\Services\Sms\OrangeSmsGateway;
use App\Services\Sms\ResilientSmsGateway;
use App\Services\Sms\SmsGateway;
use App\Services\Sms\TwilioSmsGateway;
use Illuminate\Http\Client\Request;
use Illuminate\Support\Facades\Http;
use Tests\TestCase;

class SmsGatewayTest extends TestCase
{
    private function orangeConfig(): void
    {
        config(['services.sms.orange' => [
            'base_url'      => 'https://api.orange.com/smsmessaging/v1',
            'auth_url'      => 'https://api.orange.com/oauth/v3/token',
            'client_id'     => 'id',
            'client_secret' => 'secret',
            'sender'        => '+221770000000',
            'sender_name'   => 'QUINCH',
        ]]);
    }

    public function test_driver_is_selected_from_config(): void
    {
        config(['services.sms.fallback_driver' => null]);

        config(['services.sms.driver' => 'orange']);
        $gateway = app(SmsGateway::class);
        $this->assertInstanceOf(ResilientSmsGateway::class, $gateway);
        $this->assertSame(['orange'], $gateway->providerNames());

        config(['services.sms.driver' => 'twilio']);
        $this->assertSame(['twilio'], app(SmsGateway::class)->providerNames());

        // Secours configuré : principal d'abord, puis secours.
        config(['services.sms.driver' => 'orange', 'services.sms.fallback_driver' => 'twilio']);
        $this->assertSame(['orange', 'twilio'], app(SmsGateway::class)->providerNames());

        // Le secours identique au principal est ignoré.
        config(['services.sms.driver' => 'orange', 'services.sms.fallback_driver' => 'orange']);
        $this->assertSame(['orange'], app(SmsGateway::class)->providerNames());

        // « log » reste le simulateur de développement, sans suivi.
        config(['services.sms.driver' => 'log', 'services.sms.fallback_driver' => null]);
        $this->assertInstanceOf(LogSmsGateway::class, app(SmsGateway::class));
    }

    public function test_orange_gateway_sends_the_expected_request(): void
    {
        $this->orangeConfig();

        Http::fake([
            'api.orange.com/oauth/v3/token' => Http::response(['access_token' => 'tok-123', 'expires_in' => 3600]),
            'api.orange.com/smsmessaging/*' => Http::response(['outboundSMSMessageRequest' => []], 201),
        ]);

        (new OrangeSmsGateway())->send('+221771112233', 'Bonjour');

        Http::assertSent(function (Request $r) {
            return str_contains($r->url(), '/smsmessaging/v1/outbound/')
                && $r->hasHeader('Authorization', 'Bearer tok-123')
                && $r['outboundSMSMessageRequest']['address'] === 'tel:+221771112233'
                && $r['outboundSMSMessageRequest']['outboundSMSTextMessage']['message'] === 'Bonjour';
        });
    }

    public function test_orange_gateway_throws_when_the_provider_fails(): void
    {
        $this->orangeConfig();

        Http::fake([
            'api.orange.com/oauth/v3/token' => Http::response(['access_token' => 'tok', 'expires_in' => 3600]),
            'api.orange.com/smsmessaging/*' => Http::response([], 500),
        ]);

        $this->expectException(\RuntimeException::class);

        (new OrangeSmsGateway())->send('+221771112233', 'Bonjour');
    }

    public function test_twilio_gateway_sends_the_expected_request(): void
    {
        config(['services.sms.twilio' => [
            'sid' => 'AC123', 'token' => 'tok', 'from' => '+15005550006', 'messaging_service_sid' => null,
        ]]);

        Http::fake(['api.twilio.com/*' => Http::response(['sid' => 'SM1'], 201)]);

        (new TwilioSmsGateway())->send('+221771112233', 'Bonjour');

        Http::assertSent(function (Request $r) {
            return str_contains($r->url(), '/Accounts/AC123/Messages.json')
                && $r['To'] === '+221771112233'
                && $r['From'] === '+15005550006'
                && $r['Body'] === 'Bonjour';
        });
    }

    public function test_unconfigured_gateways_refuse_to_send(): void
    {
        config(['services.sms.orange' => ['client_id' => null, 'client_secret' => null, 'sender' => null]]);

        $this->expectException(\RuntimeException::class);

        (new OrangeSmsGateway())->send('+221771112233', 'Bonjour');
    }
}
