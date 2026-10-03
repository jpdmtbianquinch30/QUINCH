<?php

namespace Tests\Feature\Security;

use App\Models\AuditLog;
use App\Models\Product;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

/**
 * Le journal d'audit ne doit contenir que les champs réellement modifiés
 * (et jamais une copie complète de la ligne).
 */
class AuditLogRedactionTest extends TestCase
{
    use RefreshDatabase;

    public function test_audit_log_records_only_the_changed_fields(): void
    {
        $product = Product::factory()->create(['title' => 'Ancien titre']);
        AuditLog::query()->delete(); // on ignore la ligne "created"

        $product->update(['title' => 'Nouveau titre']);

        $log = AuditLog::where('entity_type', 'Product')
            ->where('action_type', 'updated')
            ->latest('id')
            ->first();

        $this->assertNotNull($log, 'La modification du titre doit être journalisée.');
        $this->assertSame('Nouveau titre', $log->new_values['title']);
        $this->assertSame('Ancien titre', $log->old_values['title']);

        // Pas de copie complète de la ligne : les champs inchangés sont absents.
        $this->assertArrayNotHasKey('user_id', $log->new_values);
        $this->assertArrayNotHasKey('status', $log->new_values);
    }

    public function test_touching_only_updated_at_creates_no_audit_log(): void
    {
        $product = Product::factory()->create();
        AuditLog::query()->delete();

        $product->touch();

        $this->assertSame(0, AuditLog::where('action_type', 'updated')->count());
    }
}
