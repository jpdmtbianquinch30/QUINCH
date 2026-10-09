<?php

namespace Tests\Feature\Privacy;

use App\Models\Product;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

/**
 * Ce qu'un visiteur anonyme a le droit de voir.
 */
class PublicExposureTest extends TestCase
{
    use RefreshDatabase;

    public function test_draft_and_disabled_listings_are_hidden_from_the_public(): void
    {
        $seller = User::factory()->create();

        foreach (['draft', 'expired', 'paused', 'disabled'] as $status) {
            $product = Product::factory()->create(['user_id' => $seller->id, 'status' => 'active']);
            // Le statut est forcé hors enum éventuel : on teste la logique d'accès.
            $product->forceFill(['status' => $status]);
            $this->assertFalse($product->isVisibleTo(null), $status);
            $this->assertTrue($product->isVisibleTo($seller), "propriétaire / $status");
            $this->assertFalse($product->isVisibleTo(User::factory()->create()), "tiers / $status");
        }
    }

    public function test_public_can_open_active_listing_but_not_a_draft(): void
    {
        $seller = User::factory()->create();
        $active = Product::factory()->create(['user_id' => $seller->id, 'status' => 'active']);
        $draft = Product::factory()->create(['user_id' => $seller->id, 'status' => 'draft']);

        $this->getJson("/api/v1/products/{$active->slug}")->assertOk();
        $this->getJson("/api/v1/products/{$draft->slug}")->assertNotFound();
    }

    public function test_owner_can_still_open_their_draft(): void
    {
        $seller = User::factory()->create();
        $draft = Product::factory()->create(['user_id' => $seller->id, 'status' => 'draft']);

        $this->actingAs($seller, 'sanctum')->getJson("/api/v1/products/{$draft->slug}")->assertOk();
    }

    public function test_public_profile_does_not_expose_revenue(): void
    {
        $seller = User::factory()->create();

        $response = $this->getJson("/api/v1/users/{$seller->username}/profile")->assertOk();

        $this->assertArrayNotHasKey('total_revenue', $response->json('stats'));
    }

    public function test_banned_or_anonymized_profiles_are_not_public(): void
    {
        $banned = User::factory()->create();
        $banned->forceFill(['account_status' => 'banned'])->save();
        $this->getJson("/api/v1/users/{$banned->username}/profile")->assertNotFound();

        $gone = User::factory()->create();
        $gone->forceFill(['anonymized_at' => now()])->save();
        $this->getJson("/api/v1/users/{$gone->username}/profile")->assertNotFound();
    }
}
