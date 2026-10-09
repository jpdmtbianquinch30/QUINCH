<?php

namespace Tests\Feature\Legal;

use App\Jobs\PurgeAnonymizedAccountData;
use App\Models\Product;
use App\Models\ProductVideo;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Storage;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

/**
 * Phase 5 : consentement, informations légales publiques, droit d'accès (export),
 * droit à l'effacement (suppression du compte) et effacement définitif programmé.
 */
class LegalComplianceTest extends TestCase
{
    use RefreshDatabase;

    private array $registration = [
        'email' => 'fatou@example.com',
        'full_name' => 'Fatou Diop',
        'username' => 'fatou_diop',
        'password' => 'Password1',
        'password_confirmation' => 'Password1',
    ];

    // ─── Consentement ────────────────────────────────────────────────────────

    public function test_register_requires_acceptance_of_the_terms(): void
    {
        $this->postJson('/api/v1/auth/register', $this->registration)
            ->assertUnprocessable()
            ->assertJsonValidationErrors(['accept_terms']);

        $this->postJson('/api/v1/auth/register', [...$this->registration, 'accept_terms' => false])
            ->assertUnprocessable()
            ->assertJsonValidationErrors(['accept_terms']);

        $this->assertDatabaseMissing('users', ['email' => 'fatou@example.com']);
    }

    public function test_register_records_the_consent_with_the_text_versions(): void
    {
        config(['legal.versions.terms' => '2026-10', 'legal.versions.privacy' => '2026-11']);

        $this->postJson('/api/v1/auth/register', [...$this->registration, 'accept_terms' => true])
            ->assertCreated();

        $user = User::where('email', 'fatou@example.com')->firstOrFail();
        $this->assertNotNull($user->terms_accepted_at);
        $this->assertSame('2026-10', $user->terms_version);
        $this->assertSame('2026-11', $user->privacy_version);
    }

    // ─── Google : consentement explicite pour un NOUVEAU compte ──────────────

    private function fakeGoogle(string $email, string $sub): void
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
                'name' => 'Nouvelle Utilisatrice',
            ], 200),
        ]);
    }

    public function test_google_refuses_to_create_an_account_without_explicit_consent(): void
    {
        $this->fakeGoogle('nouvelle@example.com', 'google-sub-consent');

        $this->postJson('/api/v1/auth/google', ['id_token' => 'x'])
            ->assertUnprocessable()
            ->assertJsonPath('error', 'terms_required');

        $this->postJson('/api/v1/auth/google', ['id_token' => 'x', 'accept_terms' => false])
            ->assertUnprocessable()
            ->assertJsonPath('error', 'terms_required');

        $this->assertDatabaseMissing('users', ['email' => 'nouvelle@example.com']);
    }

    public function test_google_creates_the_account_and_records_consent_once_accepted(): void
    {
        $this->fakeGoogle('nouvelle@example.com', 'google-sub-consent');

        $this->postJson('/api/v1/auth/google', ['id_token' => 'x', 'accept_terms' => true])
            ->assertCreated();

        $user = User::where('email', 'nouvelle@example.com')->firstOrFail();
        $this->assertNotNull($user->terms_accepted_at);
        $this->assertSame(config('legal.versions.terms'), $user->terms_version);
    }

    public function test_google_login_of_an_existing_account_does_not_ask_for_consent_again(): void
    {
        $this->fakeGoogle('ancienne@example.com', 'google-sub-existing');
        $user = User::factory()->create(['email' => 'ancienne@example.com', 'google_id' => 'google-sub-existing']);

        $this->postJson('/api/v1/auth/google', ['id_token' => 'x'])
            ->assertSuccessful()
            ->assertJsonPath('is_new_user', false);

        $this->assertSame($user->id, User::where('email', 'ancienne@example.com')->value('id'));
    }

    // ─── Informations légales publiques ──────────────────────────────────────

    public function test_legal_info_is_public_and_comes_from_the_configuration(): void
    {
        config([
            'legal.publisher.name' => 'Jean Philippe Bianquinch',
            'legal.contact_email' => 'contact@quinch.sn',
            'legal.hosting.provider' => 'Contabo GmbH',
        ]);

        $this->getJson('/api/v1/legal/info')
            ->assertOk()
            ->assertJsonPath('publisher.name', 'Jean Philippe Bianquinch')
            ->assertJsonPath('contact_email', 'contact@quinch.sn')
            ->assertJsonPath('hosting.provider', 'Contabo GmbH')
            ->assertJsonStructure(['publisher', 'contact_email', 'privacy_email', 'hosting', 'versions' => ['terms', 'privacy'], 'retention']);
    }

    // ─── Droit d'accès / portabilité ─────────────────────────────────────────

    public function test_export_contains_the_whole_account_and_no_secret(): void
    {
        $user = User::factory()->create(['full_name' => 'Awa Ndiaye']);
        $user->recordLegalConsent();
        Product::factory()->create(['user_id' => $user->id]);

        Sanctum::actingAs($user);

        $response = $this->getJson('/api/v1/users/export-data')
            ->assertOk()
            ->assertJsonStructure([
                'exported_at', 'profile', 'products', 'videos', 'transactions', 'conversations', 'negotiations',
                'reviews', 'favorite_collections', 'favorite_items', 'liked_products', 'saved_products', 'follows',
                'notifications', 'support_tickets', 'reports_made', 'premium_subscriptions', 'badges', 'strikes',
                'messages_sent',
            ])
            ->assertJsonPath('profile.id', $user->id)
            ->assertJsonPath('profile.terms_version', config('legal.versions.terms'))
            ->assertJsonMissingPath('profile.password')
            ->assertJsonMissingPath('profile.otp_code');

        $this->assertCount(1, $response->json('products'));
        $this->assertStringContainsString('attachment', (string) $response->headers->get('Content-Disposition'));
    }

    public function test_export_requires_authentication(): void
    {
        $this->getJson('/api/v1/users/export-data')->assertUnauthorized();
    }

    // ─── Droit à l'effacement ────────────────────────────────────────────────

    public function test_deleting_the_account_erases_location_identity_and_profile_pictures(): void
    {
        Storage::fake('public');

        $user = User::factory()->create([
            'password' => 'MotDePasse1',
            'city' => 'Dakar',
            'region' => 'Dakar',
            'latitude' => 14.6928,
            'longitude' => -17.4467,
            'preferences' => ['categories' => ['mode']],
        ]);
        Storage::disk('public')->put("avatars/{$user->id}/a.jpg", 'x');
        Storage::disk('public')->put("covers/{$user->id}/c.jpg", 'x');

        Sanctum::actingAs($user);

        $this->postJson('/api/v1/auth/delete-account', ['password' => 'MotDePasse1'])->assertOk();

        $fresh = $user->fresh();
        $this->assertNotNull($fresh->anonymized_at);
        $this->assertNull($fresh->email);
        $this->assertNull($fresh->city);
        $this->assertNull($fresh->region);
        $this->assertNull($fresh->latitude);
        $this->assertNull($fresh->longitude);
        $this->assertNull($fresh->preferences);
        $this->assertNull($fresh->content_purged_at, 'Les contenus sont effacés plus tard, après le délai légal.');
        Storage::disk('public')->assertMissing("avatars/{$user->id}/a.jpg");
        Storage::disk('public')->assertMissing("covers/{$user->id}/c.jpg");
    }

    public function test_deleting_the_account_requires_the_right_password(): void
    {
        $user = User::factory()->create(['password' => 'MotDePasse1']);
        Sanctum::actingAs($user);

        $this->postJson('/api/v1/auth/delete-account', ['password' => 'mauvais'])->assertUnprocessable();

        $this->assertNull($user->fresh()->anonymized_at);
    }

    // ─── Effacement définitif programmé ──────────────────────────────────────

    private function anonymizedUserWithContent(int $anonymizedDaysAgo): array
    {
        Storage::fake('public');

        $user = User::factory()->create();
        $user->forceFill(['anonymized_at' => now()->subDays($anonymizedDaysAgo)])->save();

        $video = ProductVideo::factory()->create([
            'user_id' => $user->id,
            'video_path' => 'videos/v.mp4',
            'thumbnail_path' => 'thumbnails/v.jpg',
        ]);
        $product = Product::factory()->create([
            'user_id' => $user->id,
            'video_id' => $video->id,
            'title' => 'Robe wax',
            'poster_url' => 'products/posters/p.jpg',
            'images' => ['products/images/a.jpg', 'products/images/b.jpg'],
        ]);

        $files = ['videos/v.mp4', 'thumbnails/v.jpg', 'products/posters/p.jpg', 'products/images/a.jpg', 'products/images/b.jpg'];
        foreach ($files as $file) {
            Storage::disk('public')->put($file, 'x');
        }

        return [$user, $product, $files];
    }

    public function test_content_of_an_old_deleted_account_is_erased_for_good(): void
    {
        [$user, $product, $files] = $this->anonymizedUserWithContent(40);

        (new PurgeAnonymizedAccountData)->handle();

        foreach ($files as $file) {
            Storage::disk('public')->assertMissing($file);
        }

        $row = DB::table('products')->where('id', $product->id)->first();
        $this->assertSame('Annonce supprimée', $row->title);
        $this->assertNull($row->description);
        $this->assertNull($row->images);
        $this->assertNull($row->poster_url);
        $this->assertSame(0, DB::table('product_videos')->where('user_id', $user->id)->count());
        $this->assertNotNull($user->fresh()->content_purged_at);
    }

    public function test_content_of_a_recently_deleted_account_is_kept_for_now(): void
    {
        [$user, $product, $files] = $this->anonymizedUserWithContent(5);

        (new PurgeAnonymizedAccountData)->handle();

        foreach ($files as $file) {
            Storage::disk('public')->assertExists($file);
        }
        $this->assertSame('Robe wax', DB::table('products')->where('id', $product->id)->value('title'));
        $this->assertNull($user->fresh()->content_purged_at);
    }

    public function test_active_accounts_are_never_purged(): void
    {
        Storage::fake('public');
        $user = User::factory()->create();
        $product = Product::factory()->create(['user_id' => $user->id, 'title' => 'Sac en cuir']);

        (new PurgeAnonymizedAccountData)->handle();

        $this->assertSame('Sac en cuir', DB::table('products')->where('id', $product->id)->value('title'));
        $this->assertNull($user->fresh()->content_purged_at);
    }
}
