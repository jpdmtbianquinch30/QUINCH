<?php

namespace Tests\Feature\FeatureFlags;

use App\Models\Product;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class DisabledFeatureTest extends TestCase
{
    use RefreshDatabase;

    /**
     * Par défaut (config/quinch.php), les fonctionnalités V2 restantes
     * (négociation, avis, badges) sont désactivées. Un utilisateur
     * authentifié qui tape directement sur ces routes doit recevoir un 404
     * propre (voir EnsureFeatureEnabled), pas une page d'erreur ni un
     * comportement incohérent avec l'UI qui les cache.
     *
     * Le suivi (follow) a été activé pour de vrai — voir
     * Tests\Feature\Follow\FollowTest pour sa couverture fonctionnelle.
     */
    public function test_negotiation_routes_are_disabled_by_default(): void
    {
        $buyer = User::factory()->create();
        $product = Product::factory()->create(['is_negotiable' => true, 'status' => 'active']);

        $response = $this->actingAs($buyer, 'sanctum')->postJson('/api/v1/negotiations/propose', [
            'product_id' => $product->id,
            'proposed_price' => 1000,
        ]);

        $response->assertNotFound();
    }

    public function test_reviews_routes_are_disabled_by_default(): void
    {
        $user = User::factory()->create();

        $response = $this->actingAs($user, 'sanctum')->postJson('/api/v1/reviews', [
            'transaction_id' => (string) \Illuminate\Support\Str::uuid(),
            'rating' => 5,
        ]);

        $response->assertNotFound();
    }

    public function test_badges_routes_are_disabled_by_default(): void
    {
        $user = User::factory()->create();

        $response = $this->actingAs($user, 'sanctum')->getJson('/api/v1/my-badges');

        $response->assertNotFound();
    }

    public function test_follow_is_enabled_by_default(): void
    {
        // Contrairement aux autres fonctionnalités V2, le suivi a été
        // activé pour de vrai (voir FollowTest pour la couverture complète).
        $user = User::factory()->create();
        $target = User::factory()->create();

        $response = $this->actingAs($user, 'sanctum')->postJson("/api/v1/follow/{$target->id}");

        $response->assertOk();
    }

    public function test_feature_flag_mechanism_works_in_both_directions(): void
    {
        // Vérifie que le mécanisme de flag lui-même fonctionne : si on
        // active une fonctionnalité encore désactivée par défaut, la route
        // redevient accessible (le 404 vient bien du flag, pas d'une route
        // cassée). On utilise "reviews" ici puisque follow n'est plus
        // désactivé par défaut.
        config(['quinch.features.reviews' => true]);

        $user = User::factory()->create();

        $response = $this->actingAs($user, 'sanctum')->postJson('/api/v1/reviews', [
            'transaction_id' => (string) \Illuminate\Support\Str::uuid(),
            'rating' => 5,
        ]);

        // On s'attend à autre chose qu'un 404 (validation, 422, etc.) —
        // preuve que le flag a bien laissé passer la requête jusqu'au
        // contrôleur, peu importe ce qu'il en fait ensuite.
                $this->assertNotEquals(404, $response->getStatusCode());
    }

    public function test_wave_is_the_default_enabled_payment_method(): void
    {
        // V1 : Wave est la seule passerelle réellement intégrée et activée
        // par défaut (voir app/Services/PaymentGateway/WaveGateway.php).
        // cash_delivery a été retiré : PaymentGatewayFactory ne sait plus le
        // gérer (voir WavePurchaseTest pour le flux d'achat complet).
        $this->assertSame(['wave'], config('quinch.enabled_payment_methods'));
    }
}
