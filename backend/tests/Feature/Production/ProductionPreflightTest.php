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
            'mail.default' => 'smtp',
            'mail.mailers.smtp.host' => 'smtp.brevo.com',
            'mail.mailers.smtp.username' => 'smtp-user',
            'mail.mailers.smtp.password' => 'smtp-secret',
            'mail.from.address' => 'no-reply@quinch.sn',
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
        config(['mail.default' => 'log']);

        $this->assertSame([], (new ProductionPreflight())->errors('local'));
    }

    public function test_log_mailer_is_refused_in_production(): void
    {
        $this->validProductionConfig();
        config(['mail.default' => 'log']);

        $this->assertStringContainsString('MAIL_MAILER', implode(' ', $this->errors()));
    }

    public function test_smtp_without_real_host_or_credentials_is_refused(): void
    {
        $this->validProductionConfig();

        config(['mail.mailers.smtp.host' => '127.0.0.1']);
        $this->assertStringContainsString('MAIL_HOST', implode(' ', $this->errors()));

        $this->validProductionConfig();
        config(['mail.mailers.smtp.password' => '']);
        $this->assertStringContainsString('MAIL_USERNAME / MAIL_PASSWORD', implode(' ', $this->errors()));
    }

    public function test_placeholder_sender_address_is_refused(): void
    {
        $this->validProductionConfig();
        config(['mail.from.address' => 'hello@example.com']);

        $this->assertStringContainsString('MAIL_FROM_ADDRESS', implode(' ', $this->errors()));
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
        config(['mail.default' => 'log']);

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
}
