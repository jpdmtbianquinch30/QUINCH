<?php

namespace Tests\Feature\Production;

use App\Support\ProductionPreflight;
use Tests\TestCase;

class ProductionPreflightTest extends TestCase
{
    /** Configuration de production valide, que chaque test dégrade. */
    private function validProductionConfig(): void
    {
        config([
            'app.debug' => false,
            'app.key' => 'base64:' . base64_encode(str_repeat('a', 32)),
            'app.url' => 'https://api.quinch.sn',
            'quinch.frontend_url' => 'https://quinch.sn',
            'cors.allowed_origins' => ['https://quinch.sn'],
            'services.sms.driver' => 'orange',
            'services.sms.orange.client_id' => 'id',
            'services.sms.orange.client_secret' => 'secret',
            'services.sms.orange.sender' => '+221770000000',
            'queue.default' => 'redis',
            'cache.default' => 'redis',
            'database.redis.default.password' => 'redis-secret',
            'database.connections.pgsql.password' => 'db-secret',
            'sanctum.expiration' => 20160,
            'quinch.enabled_payment_methods' => ['wave'],
            'services.wave.api_key' => 'wave-key',
            'services.wave.webhook_secret' => 'wave-secret',
        ]);
    }

    private function errors(): array
    {
        return (new ProductionPreflight())->errors('production');
    }

    public function test_valid_production_config_has_no_error(): void
    {
        $this->validProductionConfig();

        $this->assertSame([], $this->errors());
    }

    public function test_nothing_is_checked_outside_production(): void
    {
        config(['services.sms.driver' => 'log']);

        $this->assertSame([], (new ProductionPreflight())->errors('local'));
    }

    public function test_log_sms_driver_is_refused_in_production(): void
    {
        $this->validProductionConfig();
        config(['services.sms.driver' => 'log']);

        $this->assertStringContainsString('SMS_DRIVER', implode(' ', $this->errors()));
    }

    public function test_missing_wave_secret_is_refused(): void
    {
        $this->validProductionConfig();
        config(['services.wave.webhook_secret' => '']);

        $this->assertStringContainsString('WAVE_WEBHOOK_SECRET', implode(' ', $this->errors()));
    }

    public function test_localhost_cors_and_debug_are_refused(): void
    {
        $this->validProductionConfig();
        config([
            'app.debug' => true,
            'cors.allowed_origins' => ['http://localhost:4200'],
        ]);

        $all = implode(' ', $this->errors());
        $this->assertStringContainsString('APP_DEBUG', $all);
        $this->assertStringContainsString('CORS_ALLOWED_ORIGINS', $all);
    }

    public function test_sync_queue_and_empty_redis_password_are_refused(): void
    {
        $this->validProductionConfig();
        config([
            'queue.default' => 'sync',
            'cache.default' => 'redis',
            'database.redis.default.password' => null,
        ]);

        $all = implode(' ', $this->errors());
        $this->assertStringContainsString('QUEUE_CONNECTION', $all);
        $this->assertStringContainsString('REDIS_PASSWORD', $all);
    }

    public function test_preflight_command_fails_with_bad_production_config(): void
    {
        $this->validProductionConfig();
        config(['services.sms.driver' => 'log']);

        $this->artisan('quinch:preflight', ['--as' => 'production'])->assertExitCode(1);
    }

    public function test_preflight_command_succeeds_with_valid_production_config(): void
    {
        $this->validProductionConfig();

        $this->artisan('quinch:preflight', ['--as' => 'production'])->assertExitCode(0);
    }

    public function test_database_queue_is_refused_because_docker_workers_read_redis(): void
    {
        $this->validProductionConfig();
        config(['queue.default' => 'database']);

        $this->assertStringContainsString('QUEUE_CONNECTION=database', implode(' ', $this->errors()));
    }

    public function test_a_valid_fallback_provider_is_accepted(): void
    {
        $this->validProductionConfig();
        config([
            'services.sms.fallback_driver' => 'twilio',
            'services.sms.twilio.sid' => 'AC123',
            'services.sms.twilio.token' => 'tok',
            'services.sms.twilio.from' => '+15005550006',
        ]);

        $this->assertSame([], $this->errors());
    }

    public function test_a_fallback_without_credentials_or_equal_to_the_primary_is_refused(): void
    {
        $this->validProductionConfig();

        config(['services.sms.fallback_driver' => 'twilio', 'services.sms.twilio.sid' => '', 'services.sms.twilio.token' => '']);
        $this->assertStringContainsString('TWILIO_SID', implode(' ', $this->errors()));

        config(['services.sms.fallback_driver' => 'orange']);
        $this->assertStringContainsString('SMS_FALLBACK_DRIVER doit différer', implode(' ', $this->errors()));

        config(['services.sms.fallback_driver' => 'nexmo']);
        $this->assertStringContainsString('SMS_FALLBACK_DRIVER=nexmo', implode(' ', $this->errors()));
    }
}

