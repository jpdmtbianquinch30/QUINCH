<?php

namespace Tests\Feature\Auth;

use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Mail;
use Tests\TestCase;

/**
 * Un jeton volé ne doit pas suffire à prendre le contrôle d'un compte.
 */
class AccountTakeoverProtectionTest extends TestCase
{
    use RefreshDatabase;

    private function user(): User
    {
        return User::factory()->create(['password' => Hash::make('Secret123')]);
    }

    private function bearer(User $user, string $name = 'quinch-app'): string
    {
        return $user->createToken($name)->plainTextToken;
    }

    public function test_changing_email_requires_current_password(): void
    {
        Mail::fake();
        $user = $this->user();
        $old = $user->email;

        $this->withToken($this->bearer($user))
            ->putJson('/api/v1/user/profile', ['email' => 'pirate@example.com'])
            ->assertStatus(422)->assertJsonPath('error', 'password_required');

        $this->withToken($this->bearer($user))
            ->putJson('/api/v1/user/profile', ['email' => 'pirate@example.com', 'current_password' => 'mauvais'])
            ->assertStatus(422);

        $this->assertSame($old, $user->fresh()->email);
    }

    public function test_changing_email_with_password_works_and_cuts_other_sessions(): void
    {
        Mail::fake();
        $user = $this->user();
        $stolen = $this->bearer($user, 'autre-appareil');
        $mine = $this->bearer($user);

        $this->withToken($mine)
            ->putJson('/api/v1/user/profile', ['email' => 'Nouveau@Example.com', 'current_password' => 'Secret123'])
            ->assertOk();

        $user->refresh();
        $this->assertSame('nouveau@example.com', $user->email);
        $this->assertNull($user->email_verified_at);
        $this->assertSame(1, $user->tokens()->count()); // seule la session en cours survit
    }

    public function test_profile_update_without_email_change_needs_no_password(): void
    {
        $user = $this->user();

        $this->withToken($this->bearer($user))
            ->putJson('/api/v1/user/profile', ['email' => $user->email, 'bio' => 'Bonjour'])
            ->assertOk();
    }

    public function test_change_password_revokes_other_tokens_but_keeps_current(): void
    {
        $user = $this->user();
        $this->bearer($user, 'volé');
        $mine = $this->bearer($user);

        $this->withToken($mine)->putJson('/api/v1/auth/change-password', [
            'current_password' => 'Secret123',
            'new_password' => 'Nouveau123',
            'new_password_confirmation' => 'Nouveau123',
        ])->assertOk();

        $this->assertSame(1, $user->tokens()->count());
    }

    public function test_change_password_and_delete_account_are_throttled(): void
    {
        $user = $this->user();
        $token = $this->bearer($user);

        $codes = [];
        for ($i = 0; $i < 7; $i++) {
            $codes[] = $this->withToken($token)->putJson('/api/v1/auth/change-password', [
                'current_password' => 'faux', 'new_password' => 'Nouveau123', 'new_password_confirmation' => 'Nouveau123',
            ])->status();
        }
        $this->assertContains(429, $codes);

        $codes = [];
        for ($i = 0; $i < 7; $i++) {
            $codes[] = $this->withToken($token)->deleteJson('/api/v1/auth/delete-account', ['password' => 'faux'])->status();
        }
        $this->assertContains(429, $codes);
        $this->assertNull($user->fresh()->anonymized_at ?? null);
    }
}
