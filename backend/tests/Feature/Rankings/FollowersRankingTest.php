<?php

namespace Tests\Feature\Rankings;

use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

/**
 * Top 100 des profils les plus suivis (nombre d'abonnés).
 */
class FollowersRankingTest extends TestCase
{
    use RefreshDatabase;

    private function premium(): User
    {
        return User::factory()->create([
            'phone_verified' => true,
            'account_status' => 'active',
            'is_premium' => true,
            'premium_expires_at' => now()->addMonth(),
            'ranking_opt_in' => true,
        ]);
    }

    private function follow(User $follower, User $target): void
    {
        $this->actingAs($follower, 'sanctum')
            ->postJson("/api/v1/follow/{$target->id}")
            ->assertSuccessful();
    }

    public function test_profiles_are_ranked_by_followers_count(): void
    {
        $viewer = $this->premium();
        $popular = $this->premium();
        $quiet = $this->premium();

        $fans = User::factory()->count(3)->create(['phone_verified' => true, 'account_status' => 'active']);

        $this->follow($fans[0], $popular);
        $this->follow($fans[1], $popular);
        $this->follow($fans[2], $quiet);

        $res = $this->actingAs($viewer, 'sanctum')->getJson('/api/v1/rankings/followers')->assertOk();

        $this->assertSame($popular->username, $res->json('ranking.0.username'));
        $this->assertSame(2, $res->json('ranking.0.followers_count'));
        $this->assertSame(1, $res->json('ranking.0.rank'));
    }

    public function test_followers_ranking_is_reserved_to_premium(): void
    {
        $free = User::factory()->create(['phone_verified' => true, 'account_status' => 'active']);

        $this->actingAs($free, 'sanctum')->getJson('/api/v1/rankings/followers')->assertStatus(403);
    }
}
