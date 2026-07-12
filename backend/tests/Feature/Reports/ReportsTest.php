<?php

namespace Tests\Feature\Reports;

use App\Models\Product;
use App\Models\ProductReport;
use App\Models\SupportTicket;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class ReportsTest extends TestCase
{
    use RefreshDatabase;

    public function test_reporting_a_product_no_longer_crashes(): void
    {
        // Régression : l'ancien code utilisait DB::table()->insert() avec une
        // colonne "user_id" inexistante (la vraie colonne est "reporter_id"),
        // ce qui faisait planter cette route en 500 à chaque appel.
        $reporter = User::factory()->create();
        $product = Product::factory()->create();

        $response = $this->actingAs($reporter, 'sanctum')->postJson("/api/v1/products/{$product->id}/report", [
            'reason' => 'fraud',
        ]);

        $response->assertOk();
        $this->assertDatabaseHas('product_reports', [
            'reporter_id' => $reporter->id,
            'product_id' => $product->id,
            'reason' => 'fraud',
            'status' => 'pending',
        ]);
    }

    public function test_cannot_report_the_same_product_twice_while_pending(): void
    {
        $reporter = User::factory()->create();
        $product = Product::factory()->create();

        $this->actingAs($reporter, 'sanctum')->postJson("/api/v1/products/{$product->id}/report", ['reason' => 'spam']);
        $second = $this->actingAs($reporter, 'sanctum')->postJson("/api/v1/products/{$product->id}/report", ['reason' => 'spam']);

        $second->assertStatus(409);
    }

    public function test_support_ticket_is_actually_saved_to_database(): void
    {
        // Régression : avant, ce signalement partait uniquement dans les
        // logs applicatifs, jamais en base -> invisible pour tout admin.
        $user = User::factory()->create();

        $response = $this->actingAs($user, 'sanctum')->postJson('/api/v1/support/report', [
            'category' => 'bug',
            'description' => 'Le bouton favoris ne marche pas.',
        ]);

        $response->assertOk();
        $this->assertDatabaseHas('support_tickets', [
            'user_id' => $user->id,
            'category' => 'bug',
            'status' => 'pending',
        ]);
    }

    public function test_admin_can_list_pending_product_reports(): void
    {
        $admin = User::factory()->admin()->create();
        $reporter = User::factory()->create();
        $product = Product::factory()->create();
        ProductReport::create([
            'reporter_id' => $reporter->id,
            'product_id' => $product->id,
            'reason' => 'fraud',
        ]);

        $response = $this->actingAs($admin, 'sanctum')->getJson('/api/v1/admin/reports/products');

        $response->assertOk();
        $this->assertCount(1, $response->json('data'));
    }

    public function test_regular_user_cannot_list_reports(): void
    {
        $user = User::factory()->create();

        $response = $this->actingAs($user, 'sanctum')->getJson('/api/v1/admin/reports/products');

        $response->assertForbidden();
    }

    public function test_admin_can_resolve_a_support_ticket(): void
    {
        $admin = User::factory()->admin()->create();
        $user = User::factory()->create();
        $ticket = SupportTicket::create([
            'user_id' => $user->id,
            'category' => 'suggestion',
            'description' => 'Ajouter le mode sombre partout.',
        ]);

        $response = $this->actingAs($admin, 'sanctum')
            ->postJson("/api/v1/admin/reports/support-tickets/{$ticket->id}/resolve", [
                'status' => 'resolved',
                'admin_notes' => 'Merci, pris en compte pour la V2.',
            ]);

        $response->assertOk();
        $this->assertDatabaseHas('support_tickets', [
            'id' => $ticket->id,
            'status' => 'resolved',
            'reviewed_by' => $admin->id,
        ]);
    }
}
