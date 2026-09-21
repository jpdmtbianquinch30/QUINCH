<?php

namespace Tests\Feature\Auth;

use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Http;
use Tests\TestCase;

/**
 * Tests de non-régression des correctifs de sécurité de l'audit.
 *
 * Chaque test décrit ici une faille réellement présente avant correction :
 * s'il repasse au rouge, la faille est réintroduite.
 */
class SecurityHardeningTest extends TestCase
{
    use RefreshDatabase;

    // ─── Réinitialisation par e-mail : prise de contrôle de compte ──────────

    /**
     * Avant correction : téléphone + e-mail suffisaient à changer le mot de
     * passe de n'importe qui. Or ce sont deux identifiants publics, pas des
     * secrets — le numéro est communiqué à chaque acheteur.
     */
    public function test_reset_by_email_refuse_sans_otp(): void
    {
        User::factory()->create([
            'phone_number' => '+221771234567',
            'email'        => 'victime@example.com',
            'password'     => Hash::make('OldPassword1'),
        ]);

        $response = $this->postJson('/api/v1/auth/reset-password-email', [
            'phone_number'          => '+221771234567',
            'email'                 => 'victime@example.com',
            'password'              => 'AttaquantPass1',
            'password_confirmation' => 'AttaquantPass1',
        ]);

        // Champ `otp` désormais obligatoire.
        $response->assertUnprocessable();

        // Et surtout : l'ancien mot de passe doit toujours fonctionner.
        $this->postJson('/api/v1/auth/login', [
            'phone_number' => '+221771234567',
            'password'     => 'OldPassword1',
        ])->assertOk();
    }

    public function test_reset_by_email_refuse_avec_otp_invalide(): void
    {
        $user = User::factory()->create([
            'phone_number' => '+221771234567',
            'email'        => 'victime@example.com',
            'password'     => Hash::make('OldPassword1'),
        ]);
        $user->generateOtp();

        $this->postJson('/api/v1/auth/reset-password-email', [
            'phone_number'          => '+221771234567',
            'email'                 => 'victime@example.com',
            'otp'                   => '000000',
            'password'              => 'AttaquantPass1',
            'password_confirmation' => 'AttaquantPass1',
        ])->assertUnprocessable()->assertJsonPath('error', 'invalid_credentials');
    }

    public function test_reset_by_email_reussit_avec_otp_valide(): void
    {
        $user = User::factory()->create([
            'phone_number' => '+221771234567',
            'email'        => 'proprietaire@example.com',
            'password'     => Hash::make('OldPassword1'),
        ]);
        $otp = $user->generateOtp();

        $this->postJson('/api/v1/auth/reset-password-email', [
            'phone_number'          => '+221771234567',
            'email'                 => 'proprietaire@example.com',
            'otp'                   => $otp,
            'password'              => 'NewPassword1',
            'password_confirmation' => 'NewPassword1',
        ])->assertOk();

        $this->postJson('/api/v1/auth/login', [
            'phone_number' => '+221771234567',
            'password'     => 'NewPassword1',
        ])->assertOk();
    }

    /**
     * L'e-mail reste un second facteur : un OTP valide seul ne suffit pas
     * sur cette route (sinon elle ferait doublon avec /reset-password).
     */
    public function test_reset_by_email_refuse_si_email_ne_correspond_pas(): void
    {
        $user = User::factory()->create([
            'phone_number' => '+221771234567',
            'email'        => 'proprietaire@example.com',
            'password'     => Hash::make('OldPassword1'),
        ]);
        $otp = $user->generateOtp();

        $this->postJson('/api/v1/auth/reset-password-email', [
            'phone_number'          => '+221771234567',
            'email'                 => 'autre@example.com',
            'otp'                   => $otp,
            'password'              => 'NewPassword1',
            'password_confirmation' => 'NewPassword1',
        ])->assertUnprocessable()->assertJsonPath('error', 'invalid_credentials');
    }

    // ─── Connexion Google : la route doit être publique ─────────────────────

    /**
     * Avant correction, `auth/google` était déclarée à l'intérieur du groupe
     * `auth:sanctum` : il fallait être connecté pour pouvoir se connecter,
     * la route répondait donc toujours 401. Le test vérifie qu'un appel
     * anonyme atteint bien le contrôleur (422 de validation) et non le
     * middleware d'authentification (401).
     */
    public function test_route_google_accessible_sans_authentification(): void
    {
        $this->postJson('/api/v1/auth/google', [])
            ->assertUnprocessable()
            ->assertJsonValidationErrors('id_token');
    }

    public function test_token_google_invalide_renvoie_401_et_non_500(): void
    {
        // Aucun appel réseau réel en test : on simule le refus de Google.
        Http::fake([
            'oauth2.googleapis.com/*' => Http::response(['error' => 'invalid_token'], 400),
        ]);

        $this->postJson('/api/v1/auth/google', ['id_token' => 'token-bidon'])
            ->assertUnauthorized()
            ->assertJsonPath('error', 'invalid_token');
    }

    /**
     * Les étapes post-connexion Google, elles, restent protégées.
     */
    public function test_etapes_post_google_restent_protegees(): void
    {
        $this->postJson('/api/v1/auth/google/add-phone', ['phone_number' => '+221771234567'])
            ->assertUnauthorized();

        $this->postJson('/api/v1/auth/google/update-username', ['username' => 'test'])
            ->assertUnauthorized();
    }

    // ─── SEC-06 : téléphone non vérifié bloqué côté serveur ─────────────────

    /**
     * Avant correction, seul le routeur Angular (authGuard) empêchait un
     * compte non vérifié d'atteindre les routes métier — contournable par
     * tout appel direct à l'API (Postman, script, extension navigateur).
     */
    public function test_compte_non_verifie_bloque_sur_une_route_metier(): void
    {
        $user = User::factory()->unverified()->create();

        $this->actingAs($user, 'sanctum')
            ->getJson('/api/v1/user/profile')
            ->assertForbidden()
            ->assertJsonPath('error', 'phone_not_verified');

        $this->actingAs($user, 'sanctum')
            ->postJson('/api/v1/cart/add', ['product_id' => (string) \Illuminate\Support\Str::uuid()])
            ->assertForbidden()
            ->assertJsonPath('error', 'phone_not_verified');
    }

    public function test_compte_verifie_accede_normalement(): void
    {
        $user = User::factory()->create(); // phone_verified => true par défaut

        $this->actingAs($user, 'sanctum')
            ->getJson('/api/v1/user/profile')
            ->assertOk();
    }

    /**
     * Les routes qui SERVENT à sortir de l'état "non vérifié" doivent, elles,
     * rester joignables par un compte non vérifié — sinon impossible de s'en
     * sortir.
     */
    public function test_routes_google_post_connexion_accessibles_sans_verification(): void
    {
        $user = User::factory()->unverified()->create();

        $this->actingAs($user, 'sanctum')
            ->postJson('/api/v1/auth/google/update-username', ['username' => 'nouveau_pseudo'])
            ->assertOk();
    }

    /**
     * Les routes du groupe `auth` (déconnexion, statut) doivent rester
     * utilisables même sans téléphone vérifié.
     *
     * `actingAs()` seul ne convient pas ici : `AuthController::logout()`
     * appelle `currentAccessToken()`, qui n'est renseigné que si la requête
     * passe par une vraie authentification par jeton porteur (comme le
     * fait un vrai client HTTP) — d'où l'en-tête `Authorization` explicite
     * plutôt que `actingAs`, à la manière de `ForgotPasswordTest`.
     */
    public function test_routes_auth_de_base_accessibles_sans_verification(): void
    {
        $user = User::factory()->unverified()->create();

        $this->actingAs($user, 'sanctum')->getJson('/api/v1/auth/me')->assertOk();

        $token = $user->createToken('session-test')->plainTextToken;
        $this->withHeader('Authorization', "Bearer $token")
            ->postJson('/api/v1/auth/logout')
            ->assertOk();
    }

    // ─── SEC-05 : jetons désormais dotés d'une expiration ───────────────────

    /**
     * Avant correction, `config('sanctum.expiration')` valait `null` : les
     * jetons émis n'expiraient jamais, y compris en cas de vol.
     */
    public function test_expiration_des_jetons_est_configuree(): void
    {
        $this->assertNotNull(config('sanctum.expiration'));
        $this->assertIsInt(config('sanctum.expiration'));
        $this->assertGreaterThan(0, config('sanctum.expiration'));
    }

    public function test_refresh_reinitialise_la_duree_de_vie_du_jeton(): void
    {
        $user = User::factory()->create();
        $plainToken = $user->createToken('ancienne-session')->plainTextToken;
        $oldTokenId = explode('|', $plainToken)[0];

        // Même remarque que ci-dessus : `refresh()` appelle
        // `currentAccessToken()`, qui exige une authentification par jeton
        // porteur réel plutôt que `actingAs`.
        $response = $this->withHeader('Authorization', "Bearer $plainToken")
            ->postJson('/api/v1/auth/refresh');

        $response->assertOk()->assertJsonStructure(['token', 'user']);
        $this->assertDatabaseMissing('personal_access_tokens', ['id' => $oldTokenId]);
    }
}
