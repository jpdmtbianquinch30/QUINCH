<?php

namespace Tests\Feature\Follow;

use App\Models\User;
use App\Models\UserFollow;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class FollowTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();
        config(['quinch.features.follow' => true]);
    }

    public function test_user_can_follow_another_user(): void
    {
        $me = User::factory()->create();
        $target = User::factory()->create();

        $response = $this->actingAs($me, 'sanctum')->postJson("/api/v1/follow/{$target->id}");

        $response->assertOk()->assertJson(['following' => true, 'is_mutual' => false]);
        $this->assertDatabaseHas('user_follows', ['follower_id' => $me->id, 'following_id' => $target->id]);
    }

    public function test_user_cannot_follow_themselves(): void
    {
        $me = User::factory()->create();

        $response = $this->actingAs($me, 'sanctum')->postJson("/api/v1/follow/{$me->id}");

        $response->assertUnprocessable();
        $this->assertDatabaseMissing('user_follows', ['follower_id' => $me->id, 'following_id' => $me->id]);
    }

    public function test_user_cannot_follow_the_same_person_twice(): void
    {
        $me = User::factory()->create();
        $target = User::factory()->create();
        UserFollow::create(['follower_id' => $me->id, 'following_id' => $target->id]);

        $response = $this->actingAs($me, 'sanctum')->postJson("/api/v1/follow/{$target->id}");

        $response->assertUnprocessable();
    }

    public function test_mutual_follow_creates_friendship_and_conversation(): void
    {
        $userA = User::factory()->create();
        $userB = User::factory()->create();

        // B suit déjà A — quand A suit B en retour, ça doit déclencher l'amitié.
        UserFollow::create(['follower_id' => $userB->id, 'following_id' => $userA->id]);

        $response = $this->actingAs($userA, 'sanctum')->postJson("/api/v1/follow/{$userB->id}");

        $response->assertOk()
            ->assertJson(['following' => true, 'is_mutual' => true])
            ->assertJsonStructure(['conversation_id']);

        $conversationId = $response->json('conversation_id');
        $this->assertDatabaseHas('messages', [
            'conversation_id' => $conversationId,
            'type' => 'system',
        ]);
    }

    public function test_user_can_unfollow(): void
    {
        $me = User::factory()->create();
        $target = User::factory()->create();
        UserFollow::create(['follower_id' => $me->id, 'following_id' => $target->id]);

        $response = $this->actingAs($me, 'sanctum')->deleteJson("/api/v1/unfollow/{$target->id}");

        $response->assertOk()->assertJson(['following' => false]);
        $this->assertDatabaseMissing('user_follows', ['follower_id' => $me->id, 'following_id' => $target->id]);
    }

    public function test_followers_and_following_lists_are_correct(): void
    {
        $me = User::factory()->create();
        $followerA = User::factory()->create();
        $followerB = User::factory()->create();
        $iFollow = User::factory()->create();

        UserFollow::create(['follower_id' => $followerA->id, 'following_id' => $me->id]);
        UserFollow::create(['follower_id' => $followerB->id, 'following_id' => $me->id]);
        UserFollow::create(['follower_id' => $me->id, 'following_id' => $iFollow->id]);

        $followers = $this->actingAs($me, 'sanctum')->getJson('/api/v1/my-followers');
        $followers->assertOk();
        $this->assertCount(2, $followers->json('data'));

        $following = $this->actingAs($me, 'sanctum')->getJson('/api/v1/my-following');
        $following->assertOk();
        $this->assertCount(1, $following->json('data'));
    }

    public function test_counts_endpoint_reflects_follow_state(): void
    {
        $me = User::factory()->create();
        $target = User::factory()->create();
        UserFollow::create(['follower_id' => $me->id, 'following_id' => $target->id]);

        $response = $this->actingAs($me, 'sanctum')->getJson("/api/v1/users/{$target->id}/follow-counts");

        $response->assertOk()->assertJson([
            'followers' => 1,
            'following' => 0,
            'is_following' => true,
            'is_mutual' => false,
        ]);
    }
}
