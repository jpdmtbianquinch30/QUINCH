<?php

namespace Tests\Feature\Admin;

use App\Models\User;
use App\Services\TrustScoring\TrustScoreCalculator;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class StaffTrustScoreTest extends TestCase
{
    use RefreshDatabase;

    public function test_super_admin_sets_his_own_trust_and_the_nightly_recalculation_keeps_it(): void
    {
        $superAdmin = User::factory()->create(['role' => 'super_admin', 'trust_score' => 0.50]);
        $regular = User::factory()->create(['role' => 'user', 'trust_score' => 0.90]);

        $this->actingAs($superAdmin, 'sanctum')
            ->postJson("/api/v1/admin/users/{$superAdmin->id}/adjust-trust", ['score' => 1, 'reason' => 'Compte officiel'])
            ->assertOk();

        (new TrustScoreCalculator())->recalculateAll();

        $this->assertEquals(1.0, (float) $superAdmin->fresh()->trust_score);
        $this->assertNotEquals(0.90, (float) $regular->fresh()->trust_score);
    }

    public function test_an_admin_cannot_adjust_his_own_trust(): void
    {
        $admin = User::factory()->create(['role' => 'admin', 'trust_score' => 0.50]);

        $this->actingAs($admin, 'sanctum')
            ->postJson("/api/v1/admin/users/{$admin->id}/adjust-trust", ['score' => 1, 'reason' => 'Test'])
            ->assertForbidden();
    }
}
