<?php

namespace Tests\Feature\Badges;

use App\Models\BadgeDefinition;
use App\Models\Product;
use App\Models\Transaction;
use App\Models\User;
use App\Models\UserBadge;
use App\Services\BadgeService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Hash;
use Tests\TestCase;

/** Badges pilotés par l'admin : catalogue, règles automatiques, zones, affichage. */
class AdminBadgeSystemTest extends TestCase
{
    use RefreshDatabase;

    private function staff(string $role): User
    {
        return User::factory()->create(['role' => $role, 'password' => Hash::make('StaffPass1')]);
    }

    private function body(array $over = []): array
    {
        return array_merge([
            'key' => 'super_vendeur', 'name' => 'Super vendeur', 'description' => 'Top', 'how_to_get' => 'Être top',
            'icon' => 'bolt', 'color' => '#10b981', 'auto_rule' => null, 'zones' => ['messages', 'seller_profile'],
            'is_active' => true,
        ], $over);
    }

    public function test_the_ten_original_badges_are_seeded_by_the_migration(): void
    {
        $this->assertSame(10, BadgeDefinition::count());
        $this->assertSame('premium', BadgeDefinition::where('key', 'premium')->value('auto_rule'));
    }

    public function test_admin_creates_updates_and_deletes_a_badge_but_not_a_system_one(): void
    {
        $admin = $this->staff('admin');

        $id = $this->actingAs($admin, 'sanctum')->postJson('/api/v1/admin/badges', $this->body())->assertCreated()->json('badge.id');
        $this->actingAs($admin, 'sanctum')->putJson("/api/v1/admin/badges/{$id}", $this->body(['name' => 'Renommé']))->assertOk();
        $this->assertSame('Renommé', BadgeDefinition::find($id)->name);
        $this->actingAs($admin, 'sanctum')->deleteJson("/api/v1/admin/badges/{$id}")->assertOk();

        $premium = BadgeDefinition::where('key', 'premium')->first();
        $this->actingAs($admin, 'sanctum')->deleteJson("/api/v1/admin/badges/{$premium->id}")->assertStatus(422);
    }

    public function test_moderator_cannot_manage_badges_and_validation_rejects_bad_input(): void
    {
        $this->actingAs($this->staff('moderator'), 'sanctum')->getJson('/api/v1/admin/badges')->assertForbidden();

        $admin = $this->staff('admin');
        $this->actingAs($admin, 'sanctum')->postJson('/api/v1/admin/badges', $this->body(['color' => 'red']))->assertStatus(422);
        $this->actingAs($admin, 'sanctum')->postJson('/api/v1/admin/badges', $this->body(['auto_rule' => 'sales_completed']))->assertStatus(422);
        $this->actingAs($admin, 'sanctum')->postJson('/api/v1/admin/badges', $this->body(['zones' => ['nowhere']]))->assertStatus(422);
    }

    public function test_premium_badge_is_wired_automatically_and_removed_at_expiry(): void
    {
        $user = User::factory()->create();

        $user->forceFill(['is_premium' => true, 'premium_expires_at' => now()->addMonth()])->save();
        $this->assertTrue(UserBadge::where('user_id', $user->id)->where('badge_type', 'premium')->where('source', 'auto')->exists());

        $user->forceFill(['is_premium' => false])->save();
        $this->assertFalse(UserBadge::where('user_id', $user->id)->where('badge_type', 'premium')->exists());
    }

    public function test_sales_rule_syncs_in_bulk_and_keeps_manual_badges(): void
    {
        $seller = User::factory()->create();
        $buyer = User::factory()->create();
        $product = Product::factory()->create(['user_id' => $seller->id]);
        Transaction::create([
            'buyer_id' => $buyer->id, 'seller_id' => $seller->id, 'product_id' => $product->id, 'amount' => 1000,
            'currency' => 'XOF', 'payment_method' => 'wave', 'payment_status' => 'completed', 'order_status' => 'delivered',
        ]);
        // Badge manuel du même type chez quelqu'un qui ne remplit pas la règle : il doit rester.
        UserBadge::create(['user_id' => $buyer->id, 'badge_type' => 'first_sale', 'source' => 'manual']);

        app(BadgeService::class)->sync();

        $this->assertTrue(UserBadge::where('user_id', $seller->id)->where('badge_type', 'first_sale')->exists());
        $this->assertTrue(UserBadge::where('user_id', $buyer->id)->where('badge_type', 'first_sale')->where('source', 'manual')->exists());
    }

    public function test_only_active_admin_badges_are_displayed_with_their_zones(): void
    {
        config(['quinch.features.badges' => true]);
        $user = User::factory()->create();
        UserBadge::create(['user_id' => $user->id, 'badge_type' => 'ambassador', 'source' => 'manual']);
        UserBadge::create(['user_id' => $user->id, 'badge_type' => 'top_seller', 'source' => 'manual']);
        BadgeDefinition::where('key', 'top_seller')->update(['is_active' => false]);
        BadgeDefinition::where('key', 'ambassador')->update(['zones' => ['messages']]);
        BadgeDefinition::flushCache();

        $badges = UserBadge::summaryFor($user->id);

        $this->assertCount(1, $badges);
        $this->assertSame('ambassador', $badges[0]['type']);
        $this->assertSame(['messages'], $badges[0]['zones']);

        $public = $this->getJson('/api/v1/badges/definitions')->assertOk()->json('badges');
        $this->assertNotContains('top_seller', array_column($public, 'key'));
        $this->assertContains('ambassador', array_column($public, 'key'));
    }

    public function test_admin_cannot_award_an_unknown_badge(): void
    {
        $admin = $this->staff('admin');
        $target = User::factory()->create();

        $this->actingAs($admin, 'sanctum')->postJson("/api/v1/admin/users/{$target->id}/badges", ['badge_type' => 'inexistant'])->assertStatus(422);
        $this->actingAs($admin, 'sanctum')->postJson("/api/v1/admin/users/{$target->id}/badges", ['badge_type' => 'ambassador'])->assertOk();
    }
}
