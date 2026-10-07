<?php

namespace Tests\Feature\Security;

use App\Support\ResolvesFrontendUrl;
use Illuminate\Http\Request;
use Tests\TestCase;

/**
 * Les redirections post-paiement (success_url / error_url) ne doivent jamais
 * pointer vers un site choisi par l'appelant via l'en-tête Origin.
 */
class FrontendUrlResolutionTest extends TestCase
{
    private function resolve(?string $origin): string
    {
        $resolver = new class {
            use ResolvesFrontendUrl;

            public function resolve(Request $request): string
            {
                return $this->resolveFrontendUrl($request);
            }
        };

        $server = $origin === null ? [] : ['HTTP_ORIGIN' => $origin];

        return $resolver->resolve(Request::create('/api/v1/premium/subscribe', 'POST', [], [], [], $server));
    }

    protected function setUp(): void
    {
        parent::setUp();

        config([
            'quinch.frontend_url' => 'https://quinch.sn',
            'cors.allowed_origins' => ['https://quinch.sn', 'https://www.quinch.sn'],
        ]);
    }

    public function test_an_allowed_origin_is_used(): void
    {
        $this->assertSame('https://www.quinch.sn', $this->resolve('https://www.quinch.sn'));
    }

    public function test_a_trailing_slash_is_ignored(): void
    {
        $this->assertSame('https://quinch.sn', $this->resolve('https://quinch.sn/'));
    }

    public function test_a_foreign_origin_falls_back_to_the_configured_frontend(): void
    {
        $this->assertSame('https://quinch.sn', $this->resolve('https://evil.example'));
        $this->assertSame('https://quinch.sn', $this->resolve('https://quinch.sn.evil.example'));
    }

    public function test_a_missing_origin_falls_back_to_the_configured_frontend(): void
    {
        $this->assertSame('https://quinch.sn', $this->resolve(null));
    }
}
