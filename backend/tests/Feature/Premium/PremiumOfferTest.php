<?php

namespace Tests\Feature\Premium;

use App\Models\PremiumApplication;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class PremiumOfferTest extends TestCase
{
    use RefreshDatabase;

    private function verifiedUser(): User
    {
        $u = User::factory()->create();
        $u->forceFill(['email_verified_at' => now()])->save();

        return $u;
    }

    public function test_beta_flag_forces_free_listing_and_disables_premium_payments(): void
    {
        config(['quinch.beta' => true, 'quinch.premium.listing_fee_with_video' => 150]);
        $this->getJson('/api/v1/public-config')->assertOk()
            ->assertJsonPath('beta', true)->assertJsonPath('listing_fee_with_video', 0);
    }

    public function test_premium_click_message_in_beta(): void
    {
        config(['quinch.premium.payments_enabled' => false]);
        Sanctum::actingAs($this->verifiedUser());
        $this->postJson('/api/v1/premium/subscribe', ['plan' => 'monthly', 'payment_method' => 'wave'])
            ->assertStatus(403)
            ->assertJsonPath('message', "Le mode de paiement n'est pas actif actuellement pour la version bêta.");
    }

    public function test_user_can_apply_once_and_see_status(): void
    {
        $u = $this->verifiedUser();
        Sanctum::actingAs($u);
        $this->postJson('/api/v1/premium/offer/apply')->assertCreated();
        $this->postJson('/api/v1/premium/offer/apply')->assertOk();
        $this->assertSame(1, PremiumApplication::count());
        $this->getJson('/api/v1/premium/offer')->assertOk()
            ->assertJsonPath('my_status', 'pending')->assertJsonPath('slots_left', 100);
    }

    public function test_unverified_email_cannot_apply(): void
    {
        $u = User::factory()->create();
        $u->forceFill(['email_verified_at' => null])->save();
        Sanctum::actingAs($u);
        $this->postJson('/api/v1/premium/offer/apply')->assertStatus(403);
    }

    public function test_admin_grants_until_cap_then_refuses(): void
    {
        config(['quinch.premium.offer.slots' => 1, 'quinch.premium.offer.days' => 30]);
        $a = PremiumApplication::create(['user_id' => $this->verifiedUser()->id]);
        $b = PremiumApplication::create(['user_id' => $this->verifiedUser()->id]);

        $admin = User::factory()->create(['role' => 'admin']);
        Sanctum::actingAs($admin);

        $this->postJson("/api/v1/admin/premium-offer/{$a->id}/grant")->assertOk();
        $this->assertTrue($a->user->fresh()->isPremiumActive());
        $this->postJson("/api/v1/admin/premium-offer/{$b->id}/grant")->assertStatus(422);
        $this->assertFalse($b->user->fresh()->isPremiumActive());
    }

    public function test_regular_user_cannot_use_admin_endpoints(): void
    {
        $a = PremiumApplication::create(['user_id' => $this->verifiedUser()->id]);
        Sanctum::actingAs($this->verifiedUser());
        $this->postJson("/api/v1/admin/premium-offer/{$a->id}/grant")->assertStatus(403);
    }
}
