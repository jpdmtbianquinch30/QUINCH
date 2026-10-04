<?php

namespace Tests\Feature\Admin;

use App\Models\ModerationAppeal;
use App\Models\Product;
use App\Models\ProductVideo;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Hash;
use Tests\TestCase;

/**
 * Parcours de modération de bout en bout : un rejet fait TOUT (vidéo retirée du produit,
 * empreinte bloquée, vendeur prévenu, strike, journal) ; 3 strikes suspendent ; le vendeur
 * peut contester ; un modérateur ne dépasse pas ses droits.
 */
class AdminModerationFlowTest extends TestCase
{
    use RefreshDatabase;

    private function staff(string $role): User
    {
        return User::factory()->create([
            'role' => $role,
            'phone_verified' => true,
            'password' => Hash::make('StaffPass1'),
        ]);
    }

    private function seller(): User
    {
        return User::factory()->create(['phone_verified' => true, 'is_seller' => true]);
    }

    private function productWithVideo(User $seller, string $moderation = 'pending'): Product
    {
        $video = ProductVideo::factory()->create([
            'user_id' => $seller->id,
            'moderation_status' => $moderation,
            'hash_sha256' => hash('sha256', uniqid('', true)),
        ]);

        return Product::factory()->create(['user_id' => $seller->id, 'status' => 'active', 'video_id' => $video->id]);
    }

    public function test_rejecting_a_video_removes_it_blocks_the_hash_warns_the_seller_and_logs(): void
    {
        $mod = $this->staff('moderator');
        $seller = $this->seller();
        $product = $this->productWithVideo($seller);
        $video = $product->video;

        $this->actingAs($mod, 'sanctum')
            ->postJson("/api/v1/admin/videos/{$video->id}/moderate", ['status' => 'rejected', 'reason' => 'Contenu interdit'])
            ->assertOk();

        $this->assertSame('rejected', $video->fresh()->moderation_status);
        $this->assertNull($product->fresh()->video_id, 'La vidéo refusée doit être retirée du produit.');
        $this->assertSame('active', $product->fresh()->status, 'Par défaut le produit reste en ligne, sans vidéo.');
        $this->assertDatabaseHas('blocked_video_hashes', ['hash_sha256' => $video->hash_sha256]);
        $this->assertDatabaseHas('user_notifications', ['user_id' => $seller->id, 'type' => 'admin']);
        $this->assertDatabaseHas('user_strikes', ['user_id' => $seller->id]);
        $this->assertDatabaseHas('admin_action_logs', ['admin_id' => $mod->id, 'target_id' => $video->id]);
    }

    public function test_rejecting_requires_a_reason(): void
    {
        $mod = $this->staff('moderator');
        $video = $this->productWithVideo($this->seller())->video;

        $this->actingAs($mod, 'sanctum')
            ->postJson("/api/v1/admin/videos/{$video->id}/moderate", ['status' => 'rejected'])
            ->assertStatus(422);
    }

    public function test_three_strikes_suspend_the_seller_automatically(): void
    {
        $mod = $this->staff('moderator');
        $seller = $this->seller();

        foreach (range(1, 3) as $i) {
            $video = $this->productWithVideo($seller)->video;
            $this->actingAs($mod, 'sanctum')
                ->postJson("/api/v1/admin/videos/{$video->id}/moderate", ['status' => 'rejected', 'reason' => "Infraction {$i}"])
                ->assertOk();
        }

        $fresh = $seller->fresh();
        $this->assertSame('suspended', $fresh->account_status);
        $this->assertNotNull($fresh->suspended_until);
    }

    public function test_seller_can_appeal_and_staff_accepting_restores_the_video(): void
    {
        $mod = $this->staff('moderator');
        $seller = $this->seller();
        $product = $this->productWithVideo($seller);
        $video = $product->video;

        $this->actingAs($mod, 'sanctum')
            ->postJson("/api/v1/admin/videos/{$video->id}/moderate", ['status' => 'rejected', 'reason' => 'Erreur de jugement'])
            ->assertOk();

        $this->actingAs($seller, 'sanctum')
            ->postJson('/api/v1/moderation/appeals', [
                'target_type' => 'video',
                'target_id' => $video->id,
                'message' => 'Cette vidéo est ma propre création, merci de revoir.',
            ])->assertCreated();

        $appeal = ModerationAppeal::firstOrFail();

        $this->actingAs($mod, 'sanctum')
            ->postJson("/api/v1/admin/moderation/appeals/{$appeal->id}/handle", ['decision' => 'accepted', 'response' => 'Vous avez raison.'])
            ->assertOk();

        $this->assertSame('approved', $video->fresh()->moderation_status);
        $this->assertSame($video->id, $product->fresh()->video_id, 'La vidéo doit être rattachée de nouveau au produit.');
        $this->assertDatabaseMissing('blocked_video_hashes', ['hash_sha256' => $video->hash_sha256]);
    }

    public function test_seller_cannot_appeal_someone_elses_video(): void
    {
        $mod = $this->staff('moderator');
        $owner = $this->seller();
        $intruder = $this->seller();
        $video = $this->productWithVideo($owner)->video;

        $this->actingAs($mod, 'sanctum')
            ->postJson("/api/v1/admin/videos/{$video->id}/moderate", ['status' => 'rejected', 'reason' => 'Contenu interdit'])
            ->assertOk();

        $this->actingAs($intruder, 'sanctum')
            ->postJson('/api/v1/moderation/appeals', [
                'target_type' => 'video',
                'target_id' => $video->id,
                'message' => 'Je conteste la vidéo de quelqu\'un d\'autre.',
            ])->assertStatus(422);
    }

    public function test_rejected_video_is_no_longer_streamed_to_the_public(): void
    {
        $mod = $this->staff('moderator');
        $video = $this->productWithVideo($this->seller())->video;

        $this->actingAs($mod, 'sanctum')
            ->postJson("/api/v1/admin/videos/{$video->id}/moderate", ['status' => 'rejected', 'reason' => 'Contenu interdit'])
            ->assertOk();

        $res = $this->getJson("/api/v1/videos/{$video->id}/stream");
        $this->assertContains($res->getStatusCode(), [403, 404], 'Une vidéo rejetée ne doit plus être servie publiquement.');
    }
}
