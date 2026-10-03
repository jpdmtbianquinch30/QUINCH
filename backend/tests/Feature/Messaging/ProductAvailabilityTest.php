<?php

namespace Tests\Feature\Messaging;

use App\Models\Conversation;
use App\Models\Message;
use App\Models\Product;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

/**
 * Régression : le droit de répondre « disponible / indisponible » vient du
 * propriétaire du PRODUIT, pas du rôle buyer/seller de la conversation (qui est
 * unique par paire d'utilisateurs, dans les deux sens).
 */
class ProductAvailabilityTest extends TestCase
{
    use RefreshDatabase;

    private function makeTag(User $conversationBuyer, User $conversationSeller, User $sender, Product $product): array
    {
        $conversation = Conversation::create([
            'buyer_id' => $conversationBuyer->id,
            'seller_id' => $conversationSeller->id,
            'status' => 'active',
            'last_message_at' => now(),
        ]);

        $message = Message::create([
            'conversation_id' => $conversation->id,
            'sender_id' => $sender->id,
            'body' => 'Produit : ' . $product->title,
            'type' => 'product_tag',
            'metadata' => ['product_id' => $product->id, 'product_owner_id' => $product->user_id],
        ]);

        return [$conversation, $message];
    }

    private function url(Conversation $c, Message $m): string
    {
        return "/api/v1/conversations/{$c->id}/messages/{$m->id}/availability";
    }

    private function users(): array
    {
        return [
            User::factory()->create(['phone_verified' => true, 'is_seller' => true, 'account_status' => 'active']),
            User::factory()->create(['phone_verified' => true, 'is_seller' => true, 'account_status' => 'active']),
        ];
    }

    public function test_product_owner_can_answer_even_when_he_is_the_conversation_buyer(): void
    {
        [$a, $b] = $this->users();
        $product = Product::factory()->create(['user_id' => $a->id, 'status' => 'active']);

        // La conversation a été ouverte par A (buyer_id = A), mais B demande le produit de A.
        [$conv, $msg] = $this->makeTag($a, $b, $b, $product);

        $this->actingAs($a, 'sanctum')
            ->postJson($this->url($conv, $msg), ['status' => 'available'])
            ->assertOk()
            ->assertJsonPath('tag_message.metadata.availability', 'available');

        $this->assertDatabaseHas('messages', [
            'conversation_id' => $conv->id,
            'sender_id' => $a->id,
            'body' => 'Produit disponible ✅',
        ]);
    }

    public function test_non_owner_gets_403(): void
    {
        [$a, $b] = $this->users();
        $product = Product::factory()->create(['user_id' => $a->id, 'status' => 'active']);
        [$conv, $msg] = $this->makeTag($a, $b, $a, $product);

        $this->actingAs($b, 'sanctum')
            ->postJson($this->url($conv, $msg), ['status' => 'available'])
            ->assertForbidden();
    }

    public function test_owner_cannot_answer_his_own_request(): void
    {
        [$a, $b] = $this->users();
        $product = Product::factory()->create(['user_id' => $a->id, 'status' => 'active']);
        [$conv, $msg] = $this->makeTag($b, $a, $a, $product);

        $this->actingAs($a, 'sanctum')
            ->postJson($this->url($conv, $msg), ['status' => 'available'])
            ->assertStatus(422);
    }

    public function test_second_answer_is_refused_and_no_duplicate_reply_is_posted(): void
    {
        [$a, $b] = $this->users();
        $product = Product::factory()->create(['user_id' => $a->id, 'status' => 'active']);
        [$conv, $msg] = $this->makeTag($b, $a, $b, $product);

        $this->actingAs($a, 'sanctum')->postJson($this->url($conv, $msg), ['status' => 'unavailable'])->assertOk();
        $this->actingAs($a, 'sanctum')->postJson($this->url($conv, $msg), ['status' => 'available'])->assertStatus(422);

        $this->assertSame(1, Message::where('conversation_id', $conv->id)
            ->where('sender_id', $a->id)->count());
    }

    public function test_stranger_outside_the_conversation_gets_403(): void
    {
        [$a, $b] = $this->users();
        $stranger = User::factory()->create(['phone_verified' => true]);
        $product = Product::factory()->create(['user_id' => $a->id, 'status' => 'active']);
        [$conv, $msg] = $this->makeTag($b, $a, $b, $product);

        $this->actingAs($stranger, 'sanctum')
            ->postJson($this->url($conv, $msg), ['status' => 'available'])
            ->assertForbidden();
    }
}