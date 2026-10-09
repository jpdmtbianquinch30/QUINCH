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
            'database.redis.default.password' => 'Xk93mQ7vLp2ZtR8wYb4NcA6dHf',
            'database.connections.pgsql.password' => 'Tn5Qe8Wz2LpV7kXr3MaBy9HcJd',
            'legal.publisher.name' => 'Jean Philippe Bianquinch',
            'legal.publisher.address' => 'Dakar, Sénégal',
            'legal.contact_email' => 'contact@quinch.sn',
            'legal.hosting.provider' => 'Contabo GmbH',
            'legal.hosting.location' => 'Allemagne',
            'session.secure' => true,
            'session.http_only' => true,
            'session.same_site' => 'lax',
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

    public function test_non_standard_mail_scheme_is_refused(): void
    {
        $this->validProductionConfig();
        config(['mail.mailers.smtp.scheme' => 'tls']);

        $this->assertStringContainsString('MAIL_SCHEME', implode(' ', $this->errors()));
    }

    public function test_port_465_requires_the_smtps_scheme(): void
    {
        $this->validProductionConfig();
        config(['mail.mailers.smtp.port' => 465, 'mail.mailers.smtp.scheme' => 'smtp']);
        $this->assertStringContainsString('MAIL_PORT=465', implode(' ', $this->errors()));

        $this->validProductionConfig();
        config(['mail.mailers.smtp.port' => 465, 'mail.mailers.smtp.scheme' => 'smtps']);
        $this->assertSame([], $this->errors());
    }

    public function test_standard_starttls_setup_is_accepted(): void
    {
        $this->validProductionConfig();
        config(['mail.mailers.smtp.port' => 587, 'mail.mailers.smtp.scheme' => 'smtp']);

        $this->assertSame([], $this->errors());
    }

    public function test_session_cookies_must_be_secure_httponly_and_samesite(): void
    {
        $this->validProductionConfig();
        config(['session.secure' => null]);
        $this->assertStringContainsString('SESSION_SECURE_COOKIE', implode(' ', $this->errors()));

        $this->validProductionConfig();
        config(['session.http_only' => false]);
        $this->assertStringContainsString('SESSION_HTTP_ONLY', implode(' ', $this->errors()));

        $this->validProductionConfig();
        config(['session.same_site' => 'none']);
        $this->assertStringContainsString('SESSION_SAME_SITE', implode(' ', $this->errors()));

        $this->validProductionConfig();
        config(['session.same_site' => 'strict']);
        $this->assertSame([], $this->errors());
    }

    public function test_placeholder_or_short_secrets_are_refused(): void
    {
        $this->validProductionConfig();
        config(['database.connections.pgsql.password' => 'CHANGE_ME']);
        $this->assertStringContainsString('DB_PASSWORD', implode(' ', $this->errors()));

        $this->validProductionConfig();
        config(['database.redis.default.password' => 'court123']);
        $this->assertStringContainsString('REDIS_PASSWORD', implode(' ', $this->errors()));

        $this->validProductionConfig();
        config(['database.connections.pgsql.password' => 'CHANGER_MOI_aussi_1234567']);
        $this->assertStringContainsString('DB_PASSWORD', implode(' ', $this->errors()));
    }

    public function test_legal_information_is_required_in_production(): void
    {
        foreach ([
            'legal.publisher.name' => 'LEGAL_PUBLISHER_NAME',
            'legal.publisher.address' => 'LEGAL_PUBLISHER_ADDRESS',
            'legal.contact_email' => 'LEGAL_CONTACT_EMAIL',
            'legal.hosting.provider' => 'LEGAL_HOST_NAME',
            'legal.hosting.location' => 'LEGAL_HOST_LOCATION',
        ] as $key => $variable) {
            $this->validProductionConfig();
            config([$key => '']);
            $this->assertStringContainsString($variable, implode(' ', $this->errors()));
        }
    }

    public function test_object_storage_requires_its_settings(): void
    {
        $this->validProductionConfig();
        config([
            'filesystems.disks.public.driver' => 's3',
            'filesystems.disks.public.bucket' => '',
            'filesystems.disks.public.key' => '',
            'filesystems.disks.public.secret' => '',
            'filesystems.disks.public.endpoint' => '',
            'media.url' => '',
        ]);

        $errors = implode(' ', $this->errors());
        foreach (['MEDIA_S3_BUCKET', 'MEDIA_S3_KEY', 'MEDIA_S3_SECRET', 'MEDIA_S3_ENDPOINT', 'MEDIA_CDN_URL'] as $variable) {
            $this->assertStringContainsString($variable, $errors);
        }
    }

    public function test_cdn_url_must_be_https(): void
    {
        $this->validProductionConfig();
        config([
            'filesystems.disks.public.driver' => 's3',
            'filesystems.disks.public.bucket' => 'quinch-media',
            'filesystems.disks.public.key' => 'k',
            'filesystems.disks.public.secret' => 's',
            'filesystems.disks.public.endpoint' => 'https://eu2.contabostorage.com',
            'media.url' => 'http://media.quinch.sn',
        ]);

        $this->assertStringContainsString('https://', implode(' ', $this->errors()));
    }

    public function test_local_media_storage_adds_no_error(): void
    {
        $this->validProductionConfig();
        config(['filesystems.disks.public.driver' => 'local']);

        $this->assertSame([], $this->errors());
    }
}
