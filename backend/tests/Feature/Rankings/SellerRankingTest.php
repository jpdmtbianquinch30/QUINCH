<?php

namespace Tests\Feature\Rankings;

use App\Models\Product;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

/**
 * QUINCH ne gère pas de transactions entre utilisateurs : le classement vendeurs
 * repose sur les vues + likes cumulés des annonces ACTIVES, jamais sur des ventes.
 */
class SellerRankingTest extends TestCase
{
    use RefreshDatabase;

    private function premium(array $attrs = []): User
    {
        return User::factory()->create(array_merge([
            'phone_verified' => true,
            'account_status' => 'active',
            'is_seller' => true,
            'is_premium' => true,
            'premium_expires_at' => now()->addMonth(),
            'ranking_opt_in' => true,
        ], $attrs));
    }

    private function product(User $owner, int $views, int $likes, string $status = 'active'): Product
    {
        return Product::factory()->create([
            'user_id' => $owner->id,
            'status' => $status,
            'view_count' => $views,
            'like_count' => $likes,
        ]);
    }

    public function test_sellers_are_ranked_by_views_plus_likes_of_active_products(): void
    {
        $viewer = $this->premium();
        $low = $this->premium();
        $high = $this->premium();

        $this->product($low, 10, 5);                 // score 15
        $this->product($high, 100, 20);              // 120
        $this->product($high, 30, 0);                // +30 = 150

        $res = $this->actingAs($viewer, 'sanctum')->getJson('/api/v1/rankings/sellers')->assertOk();

        $ranking = $res->json('ranking');
        $this->assertSame($high->username, $ranking[0]['username']);
        $this->assertSame(150, $ranking[0]['score']);
        $this->assertSame(130, $ranking[0]['total_views']);
        $this->assertSame(20, $ranking[0]['total_likes']);
        $this->assertSame(2, $ranking[0]['products_count']);
        $this->assertSame(1, $ranking[0]['rank']);
        $this->assertSame(15, $ranking[1]['score']);
    }

    public function test_inactive_products_do_not_count(): void
    {
        $viewer = $this->premium();
        $seller = $this->premium();

        $this->product($seller, 10, 0);
        $this->product($seller, 9999, 9999, 'sold');
        $this->product($seller, 9999, 9999, 'disabled');

        $res = $this->actingAs($viewer, 'sanctum')->getJson('/api/v1/rankings/sellers')->assertOk();

        $mine = collect($res->json('ranking'))->firstWhere('username', $seller->username);
        $this->assertSame(10, $mine['score']);
    }

    public function test_non_opted_in_or_non_premium_sellers_are_excluded(): void
    {
        $viewer = $this->premium();
        $hidden = $this->premium(['ranking_opt_in' => false]);
        $free = $this->premium(['is_premium' => false, 'premium_expires_at' => null]);

        $this->product($hidden, 500, 500);
        $this->product($free, 500, 500);

        $res = $this->actingAs($viewer, 'sanctum')->getJson('/api/v1/rankings/sellers')->assertOk();

        $usernames = collect($res->json('ranking'))->pluck('username')->all();
        $this->assertNotContains($hidden->username, $usernames);
        $this->assertNotContains($free->username, $usernames);
    }

    public function test_anonymous_seller_identity_is_masked_but_score_is_kept(): void
    {
        $viewer = $this->premium();
        $anon = $this->premium(['ranking_anonymous' => true]);
        $this->product($anon, 40, 2);

        $row = $this->actingAs($viewer, 'sanctum')->getJson('/api/v1/rankings/sellers')->assertOk()->json('ranking.0');

        $this->assertTrue($row['anonymous']);
        $this->assertNull($row['username']);
        $this->assertSame(42, $row['score']);
    }

    public function test_free_viewer_gets_403(): void
    {
        $free = User::factory()->create(['phone_verified' => true, 'is_premium' => false]);

        $this->actingAs($free, 'sanctum')->getJson('/api/v1/rankings/sellers')->assertForbidden();
    }

    public function test_buyers_ranking_no_longer_exists(): void
    {
        $viewer = $this->premium();

        $this->actingAs($viewer, 'sanctum')->getJson('/api/v1/rankings/buyers')->assertNotFound();
    }
}
