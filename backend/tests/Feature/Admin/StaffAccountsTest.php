<?php

namespace Tests\Feature\Admin;

use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Hash;
use Tests\TestCase;

/** Création de comptes modérateur / admin par le super admin. */
class StaffAccountsTest extends TestCase
{
    use RefreshDatabase;

    private function make(string $role): User
    {
        return User::factory()->create(['role' => $role, 'password' => Hash::make('StaffPass1')]);
    }

    private function payload(array $over = []): array
    {
        return array_merge([
            'full_name' => 'Awa Ndiaye',
            'username' => 'awa_mod',
            'phone_number' => '+221771112233',
            'role' => 'moderator',
            'password' => 'Moderat0rPass',
            'admin_password' => 'StaffPass1',
        ], $over);
    }

    public function test_super_admin_creates_a_moderator_who_can_log_in_and_reach_the_panel(): void
    {
        $super = $this->make('super_admin');

        $this->actingAs($super, 'sanctum')->postJson('/api/v1/admin/staff', $this->payload())->assertCreated();

        $mod = User::where('username', 'awa_mod')->firstOrFail();
        $this->assertSame('moderator', $mod->role);
        $this->assertTrue($mod->phone_verified);

        $this->postJson('/api/v1/auth/login', ['phone_number' => '+221771112233', 'password' => 'Moderat0rPass'])
            ->assertOk();
        $this->actingAs($mod, 'sanctum')->getJson('/api/v1/admin/me')->assertOk();
    }

    public function test_super_admin_can_create_an_admin(): void
    {
        $super = $this->make('super_admin');

        $this->actingAs($super, 'sanctum')
            ->postJson('/api/v1/admin/staff', $this->payload(['role' => 'admin', 'username' => 'chef_admin', 'phone_number' => '+221772223344']))
            ->assertCreated();

        $this->assertSame('admin', User::where('username', 'chef_admin')->value('role'));
    }

    public function test_super_admin_role_cannot_be_created_through_the_api(): void
    {
        $this->actingAs($this->make('super_admin'), 'sanctum')
            ->postJson('/api/v1/admin/staff', $this->payload(['role' => 'super_admin']))
            ->assertStatus(422);
    }

    public function test_admin_and_moderator_cannot_create_staff(): void
    {
        foreach (['admin', 'moderator'] as $role) {
            $this->actingAs($this->make($role), 'sanctum')
                ->postJson('/api/v1/admin/staff', $this->payload())
                ->assertForbidden();
        }
    }

    public function test_creation_requires_the_super_admin_password_and_a_strong_password(): void
    {
        $super = $this->make('super_admin');

        $this->actingAs($super, 'sanctum')
            ->postJson('/api/v1/admin/staff', $this->payload(['admin_password' => 'wrong']))
            ->assertForbidden()->assertJsonPath('error', 'password_confirmation_required');

        $this->actingAs($super, 'sanctum')
            ->postJson('/api/v1/admin/staff', $this->payload(['password' => 'short1A']))
            ->assertStatus(422);

        $this->assertDatabaseMissing('users', ['username' => 'awa_mod']);
    }

    public function test_duplicate_phone_is_rejected(): void
    {
        $super = $this->make('super_admin');
        User::factory()->create(['phone_number' => '+221771112233']);

        $this->actingAs($super, 'sanctum')->postJson('/api/v1/admin/staff', $this->payload())->assertStatus(422);
    }

    public function test_super_admin_resets_a_staff_password_and_sessions_are_revoked(): void
    {
        $super = $this->make('super_admin');
        $mod = $this->make('moderator');
        $mod->createToken('t');

        $this->actingAs($super, 'sanctum')
            ->postJson("/api/v1/admin/staff/{$mod->id}/password", ['password' => 'NewStrongPass9', 'admin_password' => 'StaffPass1'])
            ->assertOk();

        $this->assertTrue(Hash::check('NewStrongPass9', $mod->fresh()->password));
        $this->assertSame(0, $mod->tokens()->count());
    }

    public function test_account_deletion_needs_the_password_and_anonymizes(): void
    {
        $user = User::factory()->create(['password' => Hash::make('Password1')]);

        $this->actingAs($user, 'sanctum')->deleteJson('/api/v1/auth/delete-account', ['password' => 'bad'])->assertStatus(422);
        $this->actingAs($user, 'sanctum')->postJson('/api/v1/auth/delete-account', ['password' => 'Password1'])->assertOk();

        $fresh = $user->fresh();
        $this->assertNotNull($fresh->anonymized_at);
        $this->assertNull($fresh->phone_number);
    }

    public function test_staff_cannot_self_delete(): void
    {
        $admin = $this->make('admin');

        $this->actingAs($admin, 'sanctum')->postJson('/api/v1/auth/delete-account', ['password' => 'StaffPass1'])->assertForbidden();
    }
}
