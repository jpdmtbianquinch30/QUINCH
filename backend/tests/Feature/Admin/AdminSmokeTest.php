<?php

namespace Tests\Feature\Admin;

use App\Models\Product;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Route;
use Tests\TestCase;

/**
 * Filet de sécurité : TOUTES les routes GET sans paramètre de l'espace admin doivent
 * répondre sans erreur serveur (500) pour un super admin — SQL Postgres invalide,
 * colonne manquante, relation inexistante... Une page admin blanche vient presque
 * toujours de là.
 */
class AdminSmokeTest extends TestCase
{
    use RefreshDatabase;

    public function test_every_parameterless_admin_get_route_answers_without_server_error(): void
    {
        $super = User::factory()->superAdmin()->create();
        // Un peu de données pour que les agrégats ne portent pas sur des tables vides.
        Product::factory()->count(3)->create();
        User::factory()->count(3)->create();

        $failures = [];
        $checked = 0;

        foreach (Route::getRoutes() as $route) {
            $uri = $route->uri();
            if (!str_starts_with($uri, 'api/v1/admin/') || !in_array('GET', $route->methods(), true) || str_contains($uri, '{')) {
                continue;
            }

            $checked++;
            $res = $this->actingAs($super, 'sanctum')->getJson('/' . $uri);
            if ($res->getStatusCode() >= 500) {
                $failures[] = $uri . ' -> ' . $res->getStatusCode() . ' ' . substr((string) $res->getContent(), 0, 300);
            }
        }

        $this->assertGreaterThan(10, $checked, 'Aucune route admin trouvée : le test ne vérifie rien.');
        $this->assertSame([], $failures, implode("\n", $failures));
    }
}
