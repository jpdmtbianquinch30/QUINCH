<?php

namespace Tests\Feature\Admin;

use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class AdminAccessTest extends TestCase
{
    use RefreshDatabase;

    public function test_regular_user_cannot_access_admin_routes(): void
    {
        $user = User::factory()->create();

        $response = $this->actingAs($user, 'sanctum')->getJson('/api/v1/admin/dashboard/metrics');

        $response->assertForbidden()
            ->assertJsonPath('error', 'insufficient_permissions');
    }

    public function test_unauthenticated_user_cannot_access_admin_routes(): void
    {
        $response = $this->getJson('/api/v1/admin/dashboard/metrics');

        $response->assertUnauthorized();
    }

    public function test_admin_can_access_admin_routes(): void
    {
        $admin = User::factory()->admin()->create();

        $response = $this->actingAs($admin, 'sanctum')->getJson('/api/v1/admin/dashboard/metrics');

        $response->assertOk();
    }

    public function test_suspended_admin_is_still_blocked_from_admin_routes(): void
    {
        // Un admin suspendu ne doit pas pouvoir continuer à administrer la
        // plateforme (voir CheckRole::handle -> isSuspended()).
        $admin = User::factory()->admin()->suspended()->create();

        $response = $this->actingAs($admin, 'sanctum')->getJson('/api/v1/admin/dashboard/metrics');

        $response->assertForbidden()
            ->assertJsonPath('error', 'account_suspended');
    }

    public function test_admin_destructive_endpoints_no_longer_exist_as_http_routes(): void
    {
        // Régression : system/reset et delete-all-videos ont été retirés de
        // l'API HTTP (déplacés en commandes Artisan quinch:reset-data et
        // quinch:delete-all-videos) — même un super_admin ne doit plus
        // pouvoir les déclencher via une requête HTTP.
        $superAdmin = User::factory()->superAdmin()->create();

        $reset = $this->actingAs($superAdmin, 'sanctum')->postJson('/api/v1/admin/system/reset');
        $deleteVideos = $this->actingAs($superAdmin, 'sanctum')->postJson('/api/v1/admin/moderation/delete-all-videos');

        $reset->assertNotFound();
        $deleteVideos->assertNotFound();
    }
}
