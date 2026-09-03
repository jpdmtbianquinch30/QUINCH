<?php

namespace Tests\Feature\FeatureFlags;

use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class DisabledFeatureTest extends TestCase
{
    use RefreshDatabase;

    /**
     * Toutes les fonctionnalités V2 sont désormais activées (voir
     * .env.example). Ce test vérifie uniquement que le mécanisme de flag
     * lui-même fonctionne toujours dans les deux sens — pas qu'une
     * fonctionnalité précise est bloquée par défaut.
     */
    public function test_feature_flag_mechanism_blocks_a_disabled_feature(): void
    {
        config(['quinch.features.reviews' => false]);

        $user = User::factory()->create();

        $response = $this->actingAs($user, 'sanctum')->postJson('/api/v1/reviews', [
            'seller_id' => (string) \Illuminate\Support\Str::uuid(),
            'rating' => 5,
        ]);

        $response->assertNotFound();
    }

    public function test_feature_flag_mechanism_allows_an_enabled_feature(): void
    {
        config(['quinch.features.reviews' => true]);

        $user = User::factory()->create();

        $response = $this->actingAs($user, 'sanctum')->postJson('/api/v1/reviews', [
            'seller_id' => (string) \Illuminate\Support\Str::uuid(),
            'rating' => 5,
        ]);

        $this->assertNotEquals(404, $response->getStatusCode());
    }

    public function test_wave_is_the_default_enabled_payment_method(): void
    {
        $this->assertSame(['wave'], config('quinch.enabled_payment_methods'));
    }
}
