<?php

namespace Tests\Feature\Notifications;

use App\Models\ModerationAppeal;
use App\Models\User;
use App\Models\UserNotification;
use App\Models\UserStrike;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Hash;
use Tests\TestCase;

/** Messages de l'équipe : page détail, lu / non lu, contestation reçue par l'admin concerné. */
class TeamMessageContestTest extends TestCase
{
    use RefreshDatabase;

    private function staff(string $role = 'admin'): User
    {
        return User::factory()->create(['role' => $role, 'password' => Hash::make('StaffPass1')]);
    }

    public function test_warning_notification_carries_kind_anchor_and_contest_target(): void
    {
        $admin = $this->staff();
        $user = User::factory()->create();

        $this->actingAs($admin, 'sanctum')->postJson("/api/v1/admin/users/{$user->id}/warn", ['reason' => 'Propos déplacés'])->assertOk();

        $n = UserNotification::where('user_id', $user->id)->where('type', 'admin')->firstOrFail();
        $this->assertSame('warning', $n->data['kind']);
        $this->assertSame('avertissement', $n->data['guide_anchor']);
        $this->assertSame('strike', $n->data['contest']['target_type']);
        $this->assertSame($admin->id, $n->data['concerned_admin_id']);
    }

    public function test_user_reads_detail_toggles_unread_and_contests_a_warning_then_admin_accepts(): void
    {
        $admin = $this->staff();
        $user = User::factory()->create();
        $this->actingAs($admin, 'sanctum')->postJson("/api/v1/admin/users/{$user->id}/warn", ['reason' => 'Propos déplacés'])->assertOk();
        $n = UserNotification::where('user_id', $user->id)->where('type', 'admin')->firstOrFail();

        $this->actingAs($user, 'sanctum')->getJson("/api/v1/notifications/{$n->id}")
            ->assertOk()->assertJsonPath('contest.can_contest', true)->assertJsonPath('guide_anchor', 'avertissement');

        $this->actingAs($user, 'sanctum')->postJson("/api/v1/notifications/{$n->id}/read")->assertOk();
        $this->assertTrue($n->fresh()->is_read);
        $this->actingAs($user, 'sanctum')->postJson("/api/v1/notifications/{$n->id}/unread")->assertOk();
        $this->assertFalse($n->fresh()->is_read);

        $this->actingAs($user, 'sanctum')->postJson("/api/v1/notifications/{$n->id}/contest", ['message' => 'court'])->assertStatus(422);
        $this->actingAs($user, 'sanctum')->postJson("/api/v1/notifications/{$n->id}/contest", ['message' => 'Ce message a été sorti de son contexte.'])->assertCreated();

        // L'admin concerné reçoit une notification, et la contestation est dans la boîte « À traiter ».
        $this->assertTrue(UserNotification::where('user_id', $admin->id)->where('data->kind', 'appeal_received')->exists());
        $appeal = ModerationAppeal::firstOrFail();
        $this->assertSame($admin->id, $appeal->concerned_admin_id);

        // Une seule contestation à la fois.
        $this->actingAs($user, 'sanctum')->postJson("/api/v1/notifications/{$n->id}/contest", ['message' => 'Encore une fois, merci de revoir.'])->assertStatus(409);

        $this->actingAs($admin, 'sanctum')
            ->postJson("/api/v1/admin/moderation/appeals/{$appeal->id}/handle", ['decision' => 'accepted', 'response' => 'Vous avez raison.'])->assertOk();

        $this->assertNotNull(UserStrike::where('user_id', $user->id)->first()->revoked_at, "L'avertissement doit être retiré.");
        $this->actingAs($user, 'sanctum')->getJson("/api/v1/notifications/{$n->id}")
            ->assertJsonPath('contest.can_contest', false)->assertJsonPath('contest.appeal.status', 'accepted');
    }

    public function test_someone_else_cannot_read_or_contest_my_notification(): void
    {
        $admin = $this->staff();
        $user = User::factory()->create();
        $other = User::factory()->create();
        $this->actingAs($admin, 'sanctum')->postJson("/api/v1/admin/users/{$user->id}/warn", ['reason' => 'Propos déplacés'])->assertOk();
        $n = UserNotification::where('user_id', $user->id)->where('type', 'admin')->firstOrFail();

        $this->actingAs($other, 'sanctum')->getJson("/api/v1/notifications/{$n->id}")->assertForbidden();
        $this->actingAs($other, 'sanctum')->postJson("/api/v1/notifications/{$n->id}/contest", ['message' => 'Je conteste à sa place.'])->assertForbidden();
    }

    public function test_custom_team_message_with_reply_allowed_can_be_answered(): void
    {
        $admin = $this->staff();
        $user = User::factory()->create();

        $this->actingAs($admin, 'sanctum')->postJson("/api/v1/admin/users/{$user->id}/send-notification", [
            'title' => 'Bonjour', 'body' => "Pouvez-vous confirmer votre adresse ?\nMerci.", 'allow_reply' => true,
        ])->assertOk();

        $n = UserNotification::where('user_id', $user->id)->where('type', 'admin')->firstOrFail();
        $this->actingAs($user, 'sanctum')->postJson("/api/v1/notifications/{$n->id}/contest", ['message' => "Oui, c'est bien Dakar, Keur Massar."])->assertCreated();
        $this->assertSame('message', ModerationAppeal::firstOrFail()->target_type);
    }

    public function test_informational_notifications_point_to_the_guide_and_are_not_contestable(): void
    {
        $admin = $this->staff();
        $user = User::factory()->create();
        $user->forceFill(['account_status' => 'suspended'])->save();

        $this->actingAs($admin, 'sanctum')->postJson("/api/v1/admin/users/{$user->id}/activate", ['reason' => 'ok'])->assertOk();

        $n = UserNotification::where('user_id', $user->id)->where('data->kind', 'reactivation')->firstOrFail();
        $this->assertSame('guide', $n->data['detail']);
        $this->assertSame('compte-reactive', $n->data['guide_anchor']);
        $this->actingAs($user->fresh(), 'sanctum')->postJson("/api/v1/notifications/{$n->id}/contest", ['message' => 'Rien à contester ici.'])->assertStatus(422);
    }
}
