<?php

namespace Tests\Feature\Abuse;

use App\Models\Conversation;
use App\Models\Message;
use App\Models\Product;
use App\Models\ProductVideo;
use App\Models\Transaction;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class AbusePreventionTest extends TestCase
{
    use RefreshDatabase;

    // ── Avis ────────────────────────────────────────────────────────────
    public function test_review_is_refused_without_any_relation_with_the_seller(): void
    {
        $seller = User::factory()->create();
        $stranger = User::factory()->create();

        Sanctum::actingAs($stranger);
        $this->postJson('/api/v1/reviews', ['seller_id' => $seller->id, 'rating' => 1])
            ->assertStatus(422)->assertJsonPath('error', 'review_requires_interaction');
    }

    public function test_review_is_accepted_after_a_completed_purchase(): void
    {
        $seller = User::factory()->create();
        $buyer = User::factory()->create();
        $product = Product::factory()->create(['user_id' => $seller->id]);
        $t = Transaction::create([
            'buyer_id' => $buyer->id, 'seller_id' => $seller->id, 'product_id' => $product->id, 'quantity' => 1,
            'amount' => 1000, 'currency' => 'XOF', 'payment_method' => 'wave', 'payment_status' => 'completed',
            'order_status' => 'processing', 'security_check' => 'passed', 'delivery_type' => 'pickup', 'transaction_fee' => 0,
        ]);

        Sanctum::actingAs($buyer);
        $this->postJson('/api/v1/reviews', ['seller_id' => $seller->id, 'product_id' => $product->id, 'transaction_id' => $t->id, 'rating' => 5])
            ->assertCreated();
    }

    public function test_forged_transaction_id_is_refused(): void
    {
        $seller = User::factory()->create();
        $a = User::factory()->create();
        $b = User::factory()->create();
        $product = Product::factory()->create(['user_id' => $seller->id]);
        $t = Transaction::create([
            'buyer_id' => $a->id, 'seller_id' => $seller->id, 'product_id' => $product->id, 'quantity' => 1,
            'amount' => 1000, 'currency' => 'XOF', 'payment_method' => 'wave', 'payment_status' => 'completed',
            'order_status' => 'processing', 'security_check' => 'passed', 'delivery_type' => 'pickup', 'transaction_fee' => 0,
        ]);

        Sanctum::actingAs($b); // b n'est pas l'acheteur de cette transaction
        $this->postJson('/api/v1/reviews', ['seller_id' => $seller->id, 'transaction_id' => $t->id, 'rating' => 1])
            ->assertStatus(422);
    }

    // ── Vidéo d'un autre vendeur ────────────────────────────────────────
    public function test_cannot_attach_someone_elses_video_to_a_listing(): void
    {
        $owner = User::factory()->create();
        $thief = User::factory()->create();
        $video = ProductVideo::factory()->create(['user_id' => $owner->id]);

        Sanctum::actingAs($thief);
        $this->postJson('/api/v1/products', [
            'title' => 'Volé', 'description' => 'x', 'price' => 1000,
            'category_id' => \App\Models\Category::factory()->create()->id, 'video_id' => $video->id,
        ])->assertStatus(422);
    }

    // ── Blocage ─────────────────────────────────────────────────────────
    public function test_blocking_is_stored_and_enforced_in_both_directions(): void
    {
        $a = User::factory()->create();
        $b = User::factory()->create();

        Sanctum::actingAs($a);
        $this->postJson("/api/v1/users/{$b->id}/block")->assertOk();
        $this->assertTrue($a->isBlockedWith($b->id));
        $this->assertTrue($b->isBlockedWith($a->id));

        // a ne peut plus écrire à b, ni b à a.
        $this->postJson('/api/v1/conversations/start', ['seller_id' => $b->id, 'message' => 'salut'])->assertStatus(403);
        Sanctum::actingAs($b);
        $this->postJson('/api/v1/conversations/start', ['seller_id' => $a->id, 'message' => 'salut'])->assertStatus(403);
        config(['quinch.features.follow' => true]);
        $this->postJson("/api/v1/follow/{$a->id}")->assertStatus(403);
    }

    public function test_blocked_user_cannot_send_in_existing_conversation(): void
    {
        $a = User::factory()->create();
        $b = User::factory()->create();
        $c = Conversation::create(['buyer_id' => $a->id, 'seller_id' => $b->id, 'status' => 'active', 'last_message_at' => now()]);

        Sanctum::actingAs($a);
        $this->postJson("/api/v1/users/{$b->id}/block")->assertOk();

        Sanctum::actingAs($b);
        $this->postJson("/api/v1/conversations/{$c->id}/messages", ['body' => 'coucou'])->assertStatus(403);
    }

    // ── Métadonnées de messages ─────────────────────────────────────────
    public function test_client_cannot_forge_message_metadata(): void
    {
        $a = User::factory()->create();
        $b = User::factory()->create();
        $c = Conversation::create(['buyer_id' => $a->id, 'seller_id' => $b->id, 'status' => 'active', 'last_message_at' => now()]);

        Sanctum::actingAs($a);
        $this->postJson("/api/v1/conversations/{$c->id}/messages", [
            'body' => 'regarde', 'metadata' => ['audio_url' => 'https://evil.example/pixel.gif'],
        ])->assertOk();

        $this->assertNull(Message::first()->metadata);
    }

    // ── Pseudos ─────────────────────────────────────────────────────────
    public function test_usernames_are_case_insensitive_unique_and_reserved_names_are_refused(): void
    {
        User::factory()->create(['username' => 'Fatou_Diop']);
        $me = User::factory()->create();

        Sanctum::actingAs($me);
        foreach (['fatou_diop', 'Admin', 'QUINCH_Support', 'su', 'a b c'] as $bad) {
            $this->putJson('/api/v1/user/profile', ['username' => $bad])
                ->assertStatus(422)->assertJsonValidationErrors(['username']);
        }

        $this->putJson('/api/v1/user/profile', ['username' => 'moussa_ndiaye'])->assertOk();
    }

    public function test_registration_refuses_reserved_and_case_duplicates(): void
    {
        User::factory()->create(['username' => 'Awa_K']);

        foreach (['awa_k', 'support'] as $bad) {
            $this->postJson('/api/v1/auth/register', [
                'email' => $bad . '@example.com', 'full_name' => 'Test', 'username' => $bad,
                'password' => 'Secret123', 'password_confirmation' => 'Secret123', 'accept_terms' => true,
            ])->assertStatus(422)->assertJsonValidationErrors(['username']);
        }
    }
}
