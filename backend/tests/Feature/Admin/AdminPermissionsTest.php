<?php

namespace Tests\Feature\Admin;

use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Hash;
use Tests\TestCase;

/** Hiérarchie des rôles, permissions fines, mot de passe de confirmation, comptes bannis. */
class AdminPermissionsTest extends TestCase
{
    use RefreshDatabase;

    private function make(string $role, array $extra = []): User
    {
        return User::factory()->create(array_merge([
            'role' => $role,
            'phone_verified' => true,
            'password' => Hash::make('StaffPass1'),
        ], $extra));
    }

    public function test_moderator_cannot_ban(): void
    {
        $mod = $this->make('moderator');
        $target = $this->make('user');

        $this->actingAs($mod, 'sanctum')
            ->postJson("/api/v1/admin/users/{$target->id}/ban", ['reason' => 'Fraude', 'admin_password' => 'StaffPass1'])
            ->assertForbidden()
            ->assertJsonPath('error', 'insufficient_permissions');
    }

    public function test_admin_ban_needs_the_password_confirmation(): void
    {
        $admin = $this->make('admin');
        $target = $this->make('user');

        $this->actingAs($admin, 'sanctum')
            ->postJson("/api/v1/admin/users/{$target->id}/ban", ['reason' => 'Fraude répétée'])
            ->assertForbidden()
            ->assertJsonPath('error', 'password_confirmation_required');

        $this->actingAs($admin, 'sanctum')
            ->postJson("/api/v1/admin/users/{$target->id}/ban", ['reason' => 'Fraude répétée', 'admin_password' => 'StaffPass1'])
            ->assertOk();

        $this->assertSame('banned', $target->fresh()->account_status);
    }

    public function test_admin_cannot_act_on_another_admin_nor_on_himself(): void
    {
        $admin = $this->make('admin');
        $other = $this->make('admin');

        $this->actingAs($admin, 'sanctum')
            ->postJson("/api/v1/admin/users/{$other->id}/ban", ['reason' => 'Test hiérarchie', 'admin_password' => 'StaffPass1'])
            ->assertForbidden();

        $this->actingAs($admin, 'sanctum')
            ->postJson("/api/v1/admin/users/{$admin->id}/ban", ['reason' => 'Test hiérarchie', 'admin_password' => 'StaffPass1'])
            ->assertForbidden();

        $this->assertSame('active', $other->fresh()->account_status);
        $this->assertSame('active', $admin->fresh()->account_status);
    }

    public function test_super_admin_can_ban_an_admin_but_not_another_super_admin(): void
    {
        $super = $this->make('super_admin');
        $admin = $this->make('admin');
        $otherSuper = $this->make('super_admin');

        $this->actingAs($super, 'sanctum')
            ->postJson("/api/v1/admin/users/{$admin->id}/ban", ['reason' => 'Abus de pouvoir', 'admin_password' => 'StaffPass1'])
            ->assertOk();

        $this->actingAs($super, 'sanctum')
            ->postJson("/api/v1/admin/users/{$otherSuper->id}/ban", ['reason' => 'Abus de pouvoir', 'admin_password' => 'StaffPass1'])
            ->assertForbidden();
    }

    public function test_moderator_suspension_is_capped_at_seven_days(): void
    {
        $mod = $this->make('moderator');
        $target = $this->make('user');

        $this->actingAs($mod, 'sanctum')
            ->postJson("/api/v1/admin/users/{$target->id}/suspend", ['reason' => 'Spam répété', 'duration' => 30])
            ->assertForbidden();

        $this->actingAs($mod, 'sanctum')
            ->postJson("/api/v1/admin/users/{$target->id}/suspend", ['reason' => 'Spam répété', 'duration' => 7])
            ->assertOk();

        $fresh = $target->fresh();
        $this->assertSame('suspended', $fresh->account_status);
        $this->assertNotNull($fresh->suspended_until);
    }

    public function test_only_super_admin_can_change_roles(): void
    {
        $admin = $this->make('admin');
        $super = $this->make('super_admin');
        $target = $this->make('user');

        $this->actingAs($admin, 'sanctum')
            ->postJson("/api/v1/admin/users/{$target->id}/role", ['role' => 'moderator', 'reason' => 'Promotion test', 'admin_password' => 'StaffPass1'])
            ->assertForbidden();

        $this->actingAs($super, 'sanctum')
            ->postJson("/api/v1/admin/users/{$target->id}/role", ['role' => 'moderator', 'reason' => 'Promotion test', 'admin_password' => 'StaffPass1'])
            ->assertOk();

        $this->assertSame('moderator', $target->fresh()->role);
    }

    public function test_a_banned_user_with_an_existing_token_is_cut_off_from_the_api(): void
    {
        $user = $this->make('user');
        $token = $user->createToken('t')->plainTextToken;

        $user->forceFill(['account_status' => 'banned', 'ban_reason' => 'Test', 'banned_at' => now()])->save();

        $res = $this->withToken($token)->getJson('/api/v1/notifications/unread-count');

        $this->assertSame(403, $res->getStatusCode(), 'Un compte banni ne doit plus accéder à l\'API, même avec un jeton encore valide.');
    }

    public function test_a_suspended_user_is_cut_off_from_the_api_until_the_end_date(): void
    {
        $user = $this->make('user', ['account_status' => 'suspended', 'suspended_until' => now()->addDays(2)]);
        $token = $user->createToken('t')->plainTextToken;

        $this->withToken($token)->getJson('/api/v1/notifications/unread-count')->assertForbidden();

        // Suspension échue : l'accès revient sans intervention.
        $user->forceFill(['suspended_until' => now()->subMinute()])->save();
        // Dans un test, le garde Sanctum garde l'utilisateur déjà résolu d'une requête à
        // l'autre ; en production chaque requête repart de la base.
        $this->app['auth']->forgetGuards();
        $this->withToken($token)->getJson('/api/v1/notifications/unread-count')->assertOk();
    }
}
