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

    // ─── Réinitialisation : prise de contrôle de compte ─────────────────────

    /**
     * L'ancienne route « téléphone + e-mail » (deux identifiants publics, pas
     * des secrets) permettait de changer le mot de passe de n'importe qui.
     * Elle n'existe plus : seul le code reçu PAR E-MAIL permet de réinitialiser.
     */
    public function test_ancienne_route_reset_par_email_n_existe_plus(): void
    {
        $this->postJson('/api/v1/auth/reset-password-email', [
            'phone_number' => '+221771234567',
            'email' => 'fatou@example.com',
            'password' => 'Hacked123',
            'password_confirmation' => 'Hacked123',
        ])->assertNotFound();
    }

    public function test_reset_refuse_sans_code(): void
    {
        $user = User::factory()->create([
            'email' => 'fatou@example.com',
            'password' => Hash::make('OldPassword1'),
        ]);

        $this->postJson('/api/v1/auth/reset-password', [
            'email' => 'fatou@example.com',
            'password' => 'Hacked123',
            'password_confirmation' => 'Hacked123',
        ])->assertUnprocessable()->assertJsonValidationErrors(['otp']);

        $this->assertTrue(Hash::check('OldPassword1', $user->fresh()->password));
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
        $this->postJson('/api/v1/auth/google/update-username', ['username' => 'test'])
            ->assertUnauthorized();
    }

    // ─── Compte sans numéro de téléphone (le numéro est facultatif) ─────────

    public function test_compte_sans_numero_accede_normalement(): void
    {
        $user = User::factory()->create(['phone_number' => null, 'phone_verified' => false]);

        $this->actingAs($user, 'sanctum')
            ->getJson('/api/v1/user/profile')
            ->assertOk();
    }

    public function test_ancienne_route_add_phone_n_existe_plus(): void
    {
        $user = User::factory()->create(['phone_number' => null]);

        $this->actingAs($user, 'sanctum')
            ->postJson('/api/v1/auth/google/add-phone', ['phone_number' => '+221771234567'])
            ->assertNotFound();
    }

    // ─── Google : pas de « pré-piratage » par e-mail non vérifié ────────────

    private function fakeGoogle(string $email, string $sub = 'google-sub-1'): void
    {
        config(['services.google.client_id' => 'test-client']);

        Http::fake([
            'oauth2.googleapis.com/*' => Http::response([
                'aud' => 'test-client',
                'iss' => 'https://accounts.google.com',
                'exp' => time() + 3600,
                'sub' => $sub,
                'email' => $email,
                'email_verified' => 'true',
                'name' => 'Proprietaire Reel',
            ], 200),
        ]);
    }

    /**
     * L'inscription par e-mail ne vérifie pas l'adresse : un pirate peut créer
     * un compte avec l'e-mail d'une victime et SON mot de passe. Quand la vraie
     * propriétaire se connecte avec Google, ce mot de passe doit être invalidé
     * et les sessions du pirate révoquées.
     */
    public function test_google_neutralise_le_mot_de_passe_d_un_compte_a_email_non_verifie(): void
    {
        $this->fakeGoogle('victime@example.com');

        $pirate = User::factory()->create([
            'email' => 'victime@example.com',
            'email_verified_at' => null,
            'password' => Hash::make('MotDePassePirate1'),
        ]);
        $pirate->createToken('session-pirate');

        $this->postJson('/api/v1/auth/google', ['id_token' => 'x'])
            ->assertOk()
            ->assertJsonPath('is_new_user', false);

        $fresh = $pirate->fresh();
        $this->assertFalse(Hash::check('MotDePassePirate1', $fresh->password));
        $this->assertSame('google-sub-1', $fresh->google_id);
        $this->assertNotNull($fresh->email_verified_at);
        $this->assertSame(1, $fresh->tokens()->count(), 'Seule la session Google doit subsister.');
    }

    public function test_google_conserve_le_mot_de_passe_d_un_compte_a_email_verifie(): void
    {
        $this->fakeGoogle('fatou@example.com');

        $user = User::factory()->create([
            'email' => 'fatou@example.com',
            'email_verified_at' => now(),
            'password' => Hash::make('MonMotDePasse1'),
        ]);

        $this->postJson('/api/v1/auth/google', ['id_token' => 'x'])->assertOk();

        $this->assertTrue(Hash::check('MonMotDePasse1', $user->fresh()->password));
    }

    public function test_google_cree_un_compte_sans_telephone_avec_email_verifie(): void
    {
        $this->fakeGoogle('nouvelle@example.com', 'google-sub-2');

        $this->postJson('/api/v1/auth/google', ['id_token' => 'x', 'accept_terms' => true])
            ->assertCreated()
            ->assertJsonPath('is_new_user', true)
            ->assertJsonMissingPath('needs_phone');

        $user = User::where('email', 'nouvelle@example.com')->firstOrFail();
        $this->assertNull($user->phone_number);
        $this->assertNotNull($user->email_verified_at);
    }

    public function test_compte_avec_numero_non_verifie_accede_normalement(): void
    {
        $user = User::factory()->unverified()->create();

        $this->actingAs($user, 'sanctum')
            ->getJson('/api/v1/user/profile')
            ->assertOk();
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
     * Les deux appels utilisent un vrai jeton porteur (`Authorization: Bearer`),
     * jamais `actingAs()` : ce dernier fixe l'utilisateur directement sur le
     * garde d'authentification sans passer par la résolution normale d'un
     * jeton, et cet état reste actif pour le reste du test — la requête
     * suivante hérite alors d'un utilisateur "connecté" qui n'a jamais eu de
     * vrai jeton associé, donc `currentAccessToken()` (utilisé par
     * `logout()`) reste `null` même avec un en-tête Bearer explicite ensuite.
     */
    public function test_routes_auth_de_base_accessibles_sans_verification(): void
    {
        $user = User::factory()->unverified()->create();
        $token = $user->createToken('session-test')->plainTextToken;

        $this->withHeader('Authorization', "Bearer $token")
            ->getJson('/api/v1/auth/me')
            ->assertOk();

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
