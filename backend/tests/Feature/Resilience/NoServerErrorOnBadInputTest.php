<?php

namespace Tests\Feature\Resilience;

use App\Models\Product;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

/**
 * Une entrée malformée ne doit JAMAIS produire une erreur 500.
 */
class NoServerErrorOnBadInputTest extends TestCase
{
    use RefreshDatabase;

    private function assertNot500($response): void
    {
        $this->assertLessThan(500, $response->status(), 'Réponse ' . $response->status() . ' : ' . substr($response->getContent(), 0, 200));
    }

    public function test_public_listing_filters_ignore_garbage(): void
    {
        foreach ([
            '/api/v1/products/feed?category=abc',
            '/api/v1/products/feed?min_price=abc&max_price=xyz',
            '/api/v1/products/feed?exclude_ids=abc,def',
            '/api/v1/products/feed?exclude_ids[]=abc',
            '/api/v1/marketplace?category=abc&seller_id=abc',
            '/api/v1/marketplace?price_min=abc',
        ] as $url) {
            $this->assertNot500($this->getJson($url));
        }
    }

    /**
     * Une requête par test : sous PostgreSQL, une erreur SQL aborderait la
     * transaction englobante de RefreshDatabase et fausserait les suivantes
     * (en production chaque requête a sa propre transaction).
     */
    #[\PHPUnit\Framework\Attributes\DataProvider('malformedUrls')]
    public function test_malformed_identifier_never_gives_500(string $method, string $url, ?int $expected): void
    {
        $user = User::factory()->create();
        $response = $this->actingAs($user, 'sanctum')->json($method, $url);

        $this->assertNot500($response);
        if ($expected !== null) {
            $this->assertSame($expected, $response->status());
        }
    }

    public static function malformedUrls(): array
    {
        return [
            'badges abc'        => ['GET', '/api/v1/users/abc/badges', 404],
            'notification abc'  => ['POST', '/api/v1/notifications/abc/read', 404],
            'view produit abc'  => ['POST', '/api/v1/products/abc/view', null],
            'produit inconnu'   => ['GET', '/api/v1/products/n-existe-pas', null],
            'video 36 x a'      => ['GET', '/api/v1/videos/' . 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa' . '/stream', null],
            'transaction abc'   => ['GET', '/api/v1/transactions/abc', null],
            'transaction zzz'   => ['GET', '/api/v1/transactions/zzzzzzzz-zzzz-zzzz-zzzz-zzzzzzzzzzzz', 404],
        ];
    }

    public function test_exists_rules_reject_non_uuid_with_422(): void
    {
        $user = User::factory()->create();

        foreach ([
            ['/api/v1/conversations/start', ['seller_id' => 'abc']],
            ['/api/v1/favorites/toggle', ['product_id' => 'abc']],
            ['/api/v1/shares/track', ['product_id' => 'abc', 'platform' => 'copy_link']],
            ['/api/v1/reviews', ['seller_id' => 'abc', 'rating' => 5]],
            ['/api/v1/negotiations/propose', ['product_id' => 'abc']],
        ] as [$url, $payload]) {
            $r = $this->actingAs($user, 'sanctum')->postJson($url, $payload);
            $this->assertNot500($r);
        }
    }

    public function test_share_data_with_accents_at_cut_boundary_is_valid_json(): void
    {
        $seller = User::factory()->create();
        $product = Product::factory()->create([
            'user_id' => $seller->id, 'status' => 'active',
            // 149 octets ASCII puis un « é » (2 octets) à cheval sur la coupe à 150.
            'description' => str_repeat('a', 149) . 'éééé',
        ]);

        $user = User::factory()->create();
        $r = $this->actingAs($user, 'sanctum')->getJson("/api/v1/products/{$product->slug}/share-data");
        $r->assertOk();
        $this->assertNotNull($r->json('description'));
    }

    public function test_oversized_device_fingerprint_does_not_break_login(): void
    {
        $user = User::factory()->create(['password' => bcrypt('Secret123')]);

        $r = $this->withHeaders(['X-Device-Fingerprint' => str_repeat('x', 600)])
            ->postJson('/api/v1/auth/login', ['email' => $user->email, 'password' => 'Secret123']);

        $r->assertOk();
        $this->assertSame(255, mb_strlen($user->fresh()->device_fingerprint));
    }
}
