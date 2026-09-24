<?php

namespace App\Services;

use App\Models\Conversation;
use App\Models\ConversationProductTag;
use App\Models\Message;
use App\Models\Product;
use App\Models\Transaction;
use Illuminate\Database\QueryException;

/**
 * Point d'entree unique pour tagger un produit dans une conversation.
 * Remplace les deux implementations paralleles qui existaient avant
 * (ConversationController::start et TransactionController::
 * tagProductInConversation) : elles dupliquaient la creation du message
 * ET seule start() protegeait contre la course critique Postgres (23505).
 *
 * Idempotent : re-tagger le meme produit dans la meme conversation renvoie
 * le tag existant sans dupliquer la ligne ni reposter de message.
 */
class ConversationTaggingService
{
    public function tagProduct(
        Conversation $conversation,
        Product $product,
        ?string $taggedBy = null,
        ?Transaction $transaction = null,
    ): ConversationProductTag {
        try {
            $tag = ConversationProductTag::create([
                'conversation_id' => $conversation->id,
                'product_id' => $product->id,
                'tagged_by' => $taggedBy,
                'transaction_id' => $transaction?->id,
            ]);
        } catch (QueryException $e) {
            if (($e->errorInfo[0] ?? null) !== '23505') {
                throw $e;
            }

            // Deja tague (course entre deux requetes, ou re-declenchement) :
            // on recupere la ligne existante plutot que de planter.
            $tag = ConversationProductTag::where('conversation_id', $conversation->id)
                ->where('product_id', $product->id)
                ->first();

            if (!$tag) {
                throw $e;
            }

            return $tag;
        }

        $this->postTagMessage($conversation, $product, $transaction);

        return $tag;
    }

    private function postTagMessage(Conversation $conversation, Product $product, ?Transaction $transaction): void
    {
        $senderId = $transaction?->buyer_id ?? $conversation->buyer_id;

        Message::create([
            'conversation_id' => $conversation->id,
            'sender_id' => $senderId,
            'body' => $transaction ? 'Commande passee : ' . $product->title : 'Produit : ' . $product->title,
            'type' => 'product_tag',
            'metadata' => [
                'product_id' => $product->id,
                'product_slug' => $product->slug,
                'product_title' => $product->title,
                'product_price' => $product->price,
                // Meme fallback que MarketplaceController::index() pour la
                // vignette : poster_url n'est pas garanti (produit publie
                // via image_files sans couverture dediee).
                'product_image' => $product->poster_full_url ?? ($product->images[0] ?? null),
                'transaction_id' => $transaction?->id,
            ],
        ]);

        $conversation->update(['last_message_at' => now()]);
    }
}
