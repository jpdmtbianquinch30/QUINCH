<?php

namespace Tests\Feature\Admin;

use App\Models\Product;
use App\Models\ProductReport;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Hash;
use Tests\TestCase;

/** Module produits de l'admin + signalements branchés sur de vraies actions. */
class AdminProductsAndReportsTest extends TestCase
{
    use RefreshDatabase;

    private function staff(string $role): User
    {
        return User::factory()->create(['role' => $role, 'phone_verified' => true, 'password' => Hash::make('StaffPass1')]);
    }

    private function reporter(): User
    {
        // Compte assez ancien et crédible pour peser dans le masquage automatique.
        $u = User::factory()->create(['phone_verified' => true, 'trust_score' => 0.6]);
        $u->forceFill(['created_at' => now()->subDays(30)])->save();

        return $u;
    }

    public function test_moderator_hides_then_restores_a_product_and_the_seller_is_told(): void
    {
        $mod = $this->staff('moderator');
        $product = Product::factory()->create(['status' => 'active']);

        $this->actingAs($mod, 'sanctum')
            ->postJson("/api/v1/admin/products/{$product->id}/hide", ['reason' => 'Annonce trompeuse'])
            ->assertOk();

        $fresh = $product->fresh();
        $this->assertSame('disabled', $fresh->status);
        $this->assertSame('Annonce trompeuse', $fresh->moderation_reason);
        $this->assertDatabaseHas('user_notifications', ['user_id' => $product->user_id, 'type' => 'admin']);

        $this->actingAs($mod, 'sanctum')->postJson("/api/v1/admin/products/{$product->id}/restore")->assertOk();
        $this->assertSame('active', $product->fresh()->status);
    }

    public function test_deleting_a_product_is_a_soft_delete_that_keeps_the_evidence(): void
    {
        $mod = $this->staff('moderator');
        $product = Product::factory()->create(['status' => 'active']);

        $this->actingAs($mod, 'sanctum')
            ->postJson("/api/v1/admin/products/{$product->id}/delete", ['reason' => 'Contenu illégal'])
            ->assertOk();

        $this->assertSoftDeleted('products', ['id' => $product->id]);
    }

    public function test_only_admin_can_change_price_or_force_a_status(): void
    {
        $mod = $this->staff('moderator');
        $admin = $this->staff('admin');
        $product = Product::factory()->create(['status' => 'active', 'price' => 1000]);

        $this->actingAs($mod, 'sanctum')
            ->putJson("/api/v1/admin/products/{$product->id}", ['price' => 1, 'reason' => 'Prix aberrant'])
            ->assertForbidden();
        $this->actingAs($mod, 'sanctum')
            ->postJson("/api/v1/admin/products/{$product->id}/force-status", ['status' => 'sold', 'reason' => 'Test'])
            ->assertForbidden();

        $this->actingAs($admin, 'sanctum')
            ->putJson("/api/v1/admin/products/{$product->id}", ['price' => 1500, 'reason' => 'Correction de prix'])
            ->assertOk();
        $this->assertEquals(1500, $product->fresh()->price);
    }

    public function test_a_moderator_can_correct_the_description_of_a_product(): void
    {
        $mod = $this->staff('moderator');
        $product = Product::factory()->create(['status' => 'active', 'description' => 'Appelez le 77 000 00 00']);

        $this->actingAs($mod, 'sanctum')
            ->putJson("/api/v1/admin/products/{$product->id}", ['description' => 'Description nettoyée', 'reason' => 'Numéro de téléphone interdit'])
            ->assertOk();

        $this->assertSame('Description nettoyée', $product->fresh()->description);
    }

    public function test_resolving_a_product_report_with_hide_acts_on_the_product_and_notifies_the_reporter(): void
    {
        $mod = $this->staff('moderator');
        $reporter = $this->reporter();
        $product = Product::factory()->create(['status' => 'active']);
        $report = ProductReport::create(['reporter_id' => $reporter->id, 'product_id' => $product->id, 'reason' => 'fraud']);

        $this->actingAs($mod, 'sanctum')
            ->postJson("/api/v1/admin/reports/products/{$report->id}/resolve", [
                'status' => 'resolved', 'action' => 'hide_product', 'reason' => 'Arnaque avérée',
            ])->assertOk();

        $this->assertSame('disabled', $product->fresh()->status);
        $this->assertSame('resolved', $report->fresh()->status);
        $this->assertDatabaseHas('user_notifications', ['user_id' => $reporter->id, 'type' => 'admin']);
    }

    public function test_an_action_on_a_report_requires_a_reason(): void
    {
        $mod = $this->staff('moderator');
        $report = ProductReport::create([
            'reporter_id' => $this->reporter()->id,
            'product_id' => Product::factory()->create(['status' => 'active'])->id,
            'reason' => 'spam',
        ]);

        $this->actingAs($mod, 'sanctum')
            ->postJson("/api/v1/admin/reports/products/{$report->id}/resolve", ['status' => 'resolved', 'action' => 'hide_product'])
            ->assertStatus(422);
    }

    public function test_three_credible_reporters_hide_a_product_automatically(): void
    {
        $product = Product::factory()->create(['status' => 'active']);

        foreach (range(1, 3) as $i) {
            $this->actingAs($this->reporter(), 'sanctum')
                ->postJson("/api/v1/products/{$product->id}/report", ['reason' => 'fraud', 'description' => 'Arnaque ' . $i])
                ->assertOk();
        }

        $this->assertSame('disabled', $product->fresh()->status);
        $this->assertTrue((bool) $product->fresh()->hidden_by_system);
    }

    public function test_brand_new_accounts_cannot_hide_a_product_by_mass_reporting(): void
    {
        $product = Product::factory()->create(['status' => 'active']);

        foreach (range(1, 5) as $i) {
            $fresh = User::factory()->create(['phone_verified' => true, 'trust_score' => 0.5]); // créé à l'instant
            $this->actingAs($fresh, 'sanctum')
                ->postJson("/api/v1/products/{$product->id}/report", ['reason' => 'spam', 'description' => 'x' . $i])
                ->assertOk();
        }

        $this->assertSame('active', $product->fresh()->status, 'Des comptes tout neufs ne doivent pas pouvoir faire masquer une annonce.');
    }

    public function test_admin_can_ban_an_ip_but_never_their_own_nor_a_private_one(): void
    {
        $super = $this->staff('super_admin');

        $this->actingAs($super, 'sanctum')
            ->postJson('/api/v1/admin/security/ip-ban', ['ip_address' => '127.0.0.1', 'reason' => 'Test', 'admin_password' => 'StaffPass1'])
            ->assertStatus(422);

        $this->actingAs($super, 'sanctum')
            ->postJson('/api/v1/admin/security/ip-ban', ['ip_address' => '192.168.1.20', 'reason' => 'Test', 'admin_password' => 'StaffPass1'])
            ->assertStatus(422);

        $this->actingAs($super, 'sanctum')
            ->postJson('/api/v1/admin/security/ip-ban', ['ip_address' => '41.82.10.5', 'reason' => 'Attaque répétée', 'duration_hours' => 24, 'admin_password' => 'StaffPass1'])
            ->assertOk();

        $this->assertDatabaseHas('banned_ips', ['ip_address' => '41.82.10.5']);
    }
}
