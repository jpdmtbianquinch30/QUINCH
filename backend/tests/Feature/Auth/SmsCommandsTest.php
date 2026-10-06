<?php

namespace Tests\Feature\Auth;

use App\Models\SmsLog;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Http;
use Tests\TestCase;

class SmsCommandsTest extends TestCase
{
    use RefreshDatabase;

    private function twilioConfig(): void
    {
        config(['services.sms.twilio' => [
            'sid' => 'AC123', 'token' => 'tok', 'from' => '+15005550006', 'messaging_service_sid' => null,
        ]]);
    }

    public function test_sms_test_sends_through_the_chosen_provider(): void
    {
        $this->twilioConfig();
        Http::fake(['api.twilio.com/*' => Http::response(['sid' => 'SM1'], 201)]);

        $this->artisan('quinch:sms-test', ['phone' => '+221771112233', '--provider' => 'twilio'])
            ->assertExitCode(0);

        Http::assertSent(fn ($r) => str_contains($r->url(), 'api.twilio.com') && $r['To'] === '+221771112233');
    }

    public function test_sms_test_reports_a_provider_failure(): void
    {
        $this->twilioConfig();
        Http::fake(['api.twilio.com/*' => Http::response([], 500)]);

        $this->artisan('quinch:sms-test', ['phone' => '+221771112233', '--provider' => 'twilio'])
            ->assertExitCode(1);
    }

    public function test_sms_test_rejects_a_bad_number_and_an_unknown_provider(): void
    {
        $this->artisan('quinch:sms-test', ['phone' => '0771112233'])->assertExitCode(1);
        $this->artisan('quinch:sms-test', ['phone' => '+221771112233', '--provider' => 'foo'])->assertExitCode(1);
    }

    public function test_sms_stats_handles_empty_and_filled_logs(): void
    {
        $this->artisan('quinch:sms-stats')->expectsOutputToContain('Aucun envoi')->assertExitCode(0);

        SmsLog::create(['provider' => 'orange', 'status' => 'sent', 'to_masked' => '+22177***33', 'duration_ms' => 400, 'created_at' => now()]);
        SmsLog::create(['provider' => 'orange', 'status' => 'failed', 'to_masked' => '+22177***44', 'duration_ms' => 9000, 'created_at' => now()]);

        $this->artisan('quinch:sms-stats', ['--hours' => 24])->assertExitCode(0);
    }
}
