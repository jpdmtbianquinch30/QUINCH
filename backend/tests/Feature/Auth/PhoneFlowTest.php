<?php

namespace Tests\Feature\Auth;

use App\Models\User;
use App\Services\OtpService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Hash;
use Tests\TestCase;

/**
 * Parcours téléphone : saisie du numéro après Google, changement de numéro,
 * et règle d'exposition du code de démonstration.
 */
class PhoneFlowTest extends TestCase
{
    use RefreshDatabase;

    private function unverifiedGoogleUser(): User
    {
        $user = User::factory()->create([
            'phone_number' => null,
            'phone_verified' => false,
        ]);
        $user->forceFill(['google_id' => 'g-' . uniqid()])->save();

        return $user;
    }

    public function test_account_without_phone_can_add_one_and_gets_a_code(): void
    {
        $user = $this->unverifiedGoogleUser();

        $this->actingAs($user, 'sanctum')
            ->postJson('/api/v1/auth/google/add-phone', ['phone_number' => '+221771234567'])
            ->assertOk()
            ->assertJsonPath('otp_sent', true)
            ->assertJsonStructure(['demo_otp']);

        $this->assertDatabaseHas('users', [
            'id' => $user->id,
            'phone_number' => '+221771234567',
            'phone_verified' => false,
        ]);
    }

    public function test_unverified_user_can_correct_a_wrong_number_before_verification(): void
    {
        $user = User::factory()->create(['phone_number' => '+221770000000', 'phone_verified' => false]);

        $this->actingAs($user, 'sanctum')
            ->postJson('/api/v1/auth/google/add-phone', ['phone_number' => '+221771234567'])
            ->assertOk();

        $this->assertDatabaseHas('users', ['id' => $user->id, 'phone_number' => '+221771234567']);
    }

    public function test_verified_account_cannot_swap_its_number_through_add_phone(): void
    {
        $user = User::factory()->create(['phone_number' => '+221770000000', 'phone_verified' => true]);

        $this->actingAs($user, 'sanctum')
            ->postJson('/api/v1/auth/google/add-phone', ['phone_number' => '+221771234567'])
            ->assertForbidden()
            ->assertJsonPath('error', 'phone_already_verified');

        $this->assertDatabaseHas('users', ['id' => $user->id, 'phone_number' => '+221770000000', 'phone_verified' => true]);
    }

    public function test_protected_routes_answer_phone_not_verified_for_an_unverified_account(): void
    {
        $user = $this->unverifiedGoogleUser();

        // Les routes protégées répondent 403 phone_not_verified : c'est ce qui,
        // côté Angular, déclenchait la redirection parasite vers l'écran OTP.
        $this->actingAs($user, 'sanctum')
            ->getJson('/api/v1/notifications/unread-count')
            ->assertForbidden()
            ->assertJsonPath('error', 'phone_not_verified');
    }

    public function test_confirming_a_phone_change_wipes_the_code(): void
    {
        $user = User::factory()->create([
            'phone_number' => '+221771111111',
            'phone_verified' => true,
            'password' => Hash::make('CurrentPass1'),
        ]);

        $otp = $this->actingAs($user, 'sanctum')->postJson('/api/v1/user/phone/request-change', [
            'new_phone_number' => '+221772222222',
            'current_password' => 'CurrentPass1',
        ])->json('demo_otp');

        $this->actingAs($user, 'sanctum')
            ->postJson('/api/v1/user/phone/confirm-change', ['otp' => $otp])
            ->assertOk();

        $fresh = $user->fresh();
        $this->assertSame('+221772222222', $fresh->phone_number);
        $this->assertNull($fresh->otp_code);
        $this->assertNull($fresh->otp_expires_at);
    }

    public function test_phone_change_is_refused_if_the_number_was_taken_in_between(): void
    {
        $user = User::factory()->create([
            'phone_number' => '+221771111111',
            'phone_verified' => true,
            'password' => Hash::make('CurrentPass1'),
        ]);

        $otp = $this->actingAs($user, 'sanctum')->postJson('/api/v1/user/phone/request-change', [
            'new_phone_number' => '+221772222222',
            'current_password' => 'CurrentPass1',
        ])->json('demo_otp');

        User::factory()->create(['phone_number' => '+221772222222']);

        $this->actingAs($user, 'sanctum')
            ->postJson('/api/v1/user/phone/confirm-change', ['otp' => $otp])
            ->assertStatus(422)
            ->assertJsonPath('error', 'phone_taken');

        $this->assertSame('+221771111111', $user->fresh()->phone_number);
    }

    public function test_a_code_sent_to_the_old_number_cannot_confirm_a_pending_change(): void
    {
        $user = User::factory()->create([
            'phone_number' => '+221771111111',
            'phone_verified' => true,
            'password' => Hash::make('CurrentPass1'),
        ]);

        // 1. Demande de changement vers un nouveau numéro (jamais confirmée).
        $this->actingAs($user, 'sanctum')->postJson('/api/v1/user/phone/request-change', [
            'new_phone_number' => '+221772222222',
            'current_password' => 'CurrentPass1',
        ])->assertOk();

        // 2. « Mot de passe oublié » : le code part vers l'ANCIEN numéro.
        $oldNumberCode = $this->postJson('/api/v1/auth/forgot-password', [
            'phone_number' => '+221771111111',
        ])->json('demo_otp');

        // 3. Ce code ne doit pas pouvoir valider le changement en attente.
        $this->actingAs($user, 'sanctum')
            ->postJson('/api/v1/user/phone/confirm-change', ['otp' => $oldNumberCode])
            ->assertStatus(422);

        $this->assertSame('+221771111111', $user->fresh()->phone_number);
    }

    public function test_demo_code_is_hidden_as_soon_as_a_real_sms_driver_is_configured(): void
    {
        $otp = app(OtpService::class);

        // En local avec le driver « log » (simulation) : code exposé.
        $this->app['env'] = 'local';
        config(['services.sms.driver' => 'log']);
        $this->assertTrue($otp->shouldExposeDemoCode());

        // En local avec un vrai driver : le code n'arrive que par SMS.
        config(['services.sms.driver' => 'orange']);
        $this->assertFalse($otp->shouldExposeDemoCode());

        // En production : jamais.
        $this->app['env'] = 'production';
        config(['services.sms.driver' => 'log']);
        $this->assertFalse($otp->shouldExposeDemoCode());
    }
}
