<?php

namespace Tests\Feature\Security;

use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class SecurityHeadersTest extends TestCase
{
    use RefreshDatabase;

    public function test_api_responses_carry_the_hardened_headers(): void
    {
        $response = $this->getJson('/api/v1/premium/plans');

        $response->assertHeader('X-Content-Type-Options', 'nosniff');
        $response->assertHeader('X-Frame-Options', 'DENY');
        $response->assertHeader('X-XSS-Protection', '0');
        $response->assertHeader('Referrer-Policy', 'strict-origin-when-cross-origin');
        $response->assertHeader('X-Permitted-Cross-Domain-Policies', 'none');
        $this->assertStringContainsString("default-src 'none'", (string) $response->headers->get('Content-Security-Policy'));
        $this->assertStringContainsString("frame-ancestors 'none'", (string) $response->headers->get('Content-Security-Policy'));
        $this->assertStringContainsString('max-age=', (string) $response->headers->get('Strict-Transport-Security'));
    }

    public function test_auth_responses_are_never_cached(): void
    {
        $response = $this->postJson('/api/v1/auth/login', ['identifier' => 'nobody@example.com', 'email' => 'nobody@example.com', 'password' => 'x']);

        $this->assertStringContainsString('no-store', (string) $response->headers->get('Cache-Control'));
    }

    public function test_other_api_responses_are_not_forced_to_no_store(): void
    {
        $response = $this->getJson('/api/v1/premium/plans');

        $this->assertStringNotContainsString('no-store', (string) $response->headers->get('Cache-Control'));
    }
}
