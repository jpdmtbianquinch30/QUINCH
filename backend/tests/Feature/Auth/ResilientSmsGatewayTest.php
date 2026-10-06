<?php

namespace Tests\Feature\Auth;

use App\Models\SmsLog;
use App\Services\Sms\SmsGateway;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Http;
use Tests\TestCase;

class ResilientSmsGatewayTest extends TestCase
{
    use RefreshDatabase;

    private const CODE = '482913';

    protected function setUp(): void
    {
        parent::setUp();

        Cache::flush();

        config([
            'services.sms.driver'          => 'orange',
            'services.sms.fallback_driver' => 'twilio',
            'services.sms.breaker_seconds' => 120,
            'services.sms.orange' => [
                'base_url'      => 'https://api.orange.com/smsmessaging/v1',
                'auth_url'      => 'https://api.orange.com/oauth/v3/token',
                'client_id'     => 'id',
                'client_secret' => 'secret',
                'sender'        => '+221770000000',
                'sender_name'   => 'QUINCH',
            ],
            'services.sms.twilio' => [
                'sid' => 'AC123', 'token' => 'tok', 'from' => '+15005550006', 'messaging_service_sid' => null,
            ],
        ]);
    }

    private function message(): string
    {
        return 'QUINCH : votre code est ' . self::CODE . '. Valable 10 min.';
    }

    private function fakeProviders(int $orangeStatus, int $twilioStatus): void
    {
        Http::fake([
            'api.orange.com/oauth/v3/token' => Http::response(['access_token' => 'tok', 'expires_in' => 3600]),
            'api.orange.com/smsmessaging/*' => Http::response([], $orangeStatus),
            'api.twilio.com/*'              => Http::response(['sid' => 'SM1'], $twilioStatus),
        ]);
    }

    public function test_primary_success_does_not_touch_the_fallback(): void
    {
        $this->fakeProviders(201, 201);

        app(SmsGateway::class)->send('+221771112233', $this->message());

        Http::assertNotSent(fn ($r) => str_contains($r->url(), 'api.twilio.com'));
        $this->assertDatabaseHas('sms_logs', [
            'provider' => 'orange', 'status' => 'sent', 'to_masked' => '+22177***33',
        ]);
        $this->assertSame(1, SmsLog::count());
    }

    public function test_failure_of_the_primary_falls_back_to_the_secondary(): void
    {
        $this->fakeProviders(500, 201);

        app(SmsGateway::class)->send('+221771112233', $this->message());

        Http::assertSent(fn ($r) => str_contains($r->url(), 'api.twilio.com'));
        $this->assertDatabaseHas('sms_logs', ['provider' => 'orange', 'status' => 'failed']);
        $this->assertDatabaseHas('sms_logs', ['provider' => 'twilio', 'status' => 'sent']);
    }

    public function test_when_every_provider_fails_an_exception_is_thrown_so_the_job_retries(): void
    {
        $this->fakeProviders(500, 500);

        try {
            app(SmsGateway::class)->send('+221771112233', $this->message());
            $this->fail('Une exception était attendue.');
        } catch (\RuntimeException $e) {
            $this->assertStringContainsString('Aucun fournisseur SMS', $e->getMessage());
            $this->assertStringNotContainsString(self::CODE, $e->getMessage());
        }

        $this->assertSame(2, SmsLog::where('status', 'failed')->count());
    }

    public function test_without_a_fallback_a_failure_is_thrown_and_recorded_once(): void
    {
        config(['services.sms.fallback_driver' => null]);
        $this->fakeProviders(500, 201);

        $this->expectException(\RuntimeException::class);

        try {
            app(SmsGateway::class)->send('+221771112233', $this->message());
        } finally {
            Http::assertNotSent(fn ($r) => str_contains($r->url(), 'api.twilio.com'));
            $this->assertSame(1, SmsLog::count());
        }
    }

    public function test_a_failed_provider_is_skipped_by_the_next_sends(): void
    {
        $this->fakeProviders(500, 201);

        $gateway = app(SmsGateway::class);
        $gateway->send('+221771112233', $this->message());
        $gateway->send('+221771112244', $this->message());

        $orangeCalls = Http::recorded(fn ($request) => str_contains($request->url(), '/smsmessaging/'))->count();

        $this->assertSame(1, $orangeCalls, 'Orange ne doit plus être appelé tant que son disjoncteur est ouvert.');
        $this->assertSame(2, SmsLog::where('provider', 'twilio')->where('status', 'sent')->count());
    }

    public function test_the_log_never_contains_the_code_nor_the_full_number(): void
    {
        $this->fakeProviders(500, 201);

        app(SmsGateway::class)->send('+221771112233', $this->message());

        $dump = SmsLog::all()->toJson();

        $this->assertStringNotContainsString(self::CODE, $dump);
        $this->assertStringNotContainsString('771112233', $dump);
    }

    public function test_old_sms_logs_are_pruned_and_recent_ones_kept(): void
    {
        SmsLog::create(['provider' => 'orange', 'status' => 'sent', 'to_masked' => '+22177***33', 'created_at' => now()->subDays(100)]);
        SmsLog::create(['provider' => 'orange', 'status' => 'sent', 'to_masked' => '+22177***44', 'created_at' => now()->subDays(5)]);

        (new SmsLog())->pruneAll();

        $this->assertSame(1, SmsLog::count());
        $this->assertDatabaseHas('sms_logs', ['to_masked' => '+22177***44']);
    }
}
