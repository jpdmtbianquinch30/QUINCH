<?php

namespace App\Services;

use App\Models\Conversation;
use App\Models\ConversationProductTag;
use App\Models\Message;
use App\Models\Product;
use App\Models\Transaction;
use Illuminate\Database\QueryException;

/**
 * Point d'entrée unique pour tagger un produit dans une conversation.
 * Remplace les deux implémentations parallèles qui existaient avant
 * (ConversationController::start et TransactionController::
 * tagProductInConversation) : elles dupliquaient la création du message
 * ET seule start() protégeait contre la course critique Postgres (23505).
 *
 * Idempotent : re-tagger le même produit dans la même conversation renvoie
 * le tag existant sans dupliquer la ligne ni reposter de message.
 *
 * Rappel : une conversation est unique par paire d'utilisateurs, dans les deux
 * sens. conversation.buyer_id / seller_id ne disent donc rien sur qui possède
 * un produit taggué ni sur qui a envoyé le message : on se base sur
 * $taggedBy (auteur) et sur product.user_id (propriétaire).
 */
class ConversationTaggingService
{
    public function tagProduct(
        Conversation $conversation,
        Product $product,
        ?string $taggedBy = null,
        ?Transaction $transaction = null,
        bool $postMessage = true,
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

            // Déjà taggé (course entre deux requêtes, ou re-déclenchement) :
            // on récupère la ligne existante plutôt que de planter.
            $tag = ConversationProductTag::where('conversation_id', $conversation->id)
                ->where('product_id', $product->id)
                ->first();

            if (!$tag) {
                throw $e;
            }

            return $tag;
        }

        if ($postMessage) {
            $this->postTagMessage($conversation, $product, $transaction, $taggedBy);
        }

        return $tag;
    }

    /**
     * Métadonnées d'un message de type product_tag.
     */
    public function tagMetadata(Product $product, ?Transaction $transaction = null): array
    {
        return [
            'product_id' => $product->id,
            // Sert à l'écran ET au backend à savoir qui peut répondre
            // « disponible / indisponible » (le propriétaire du produit).
            'product_owner_id' => $product->user_id,
            'product_slug' => $product->slug,
            'product_title' => $product->title,
            'product_price' => $product->price,
            'product_type' => $product->type ?? 'product',
            // Même fallback que MarketplaceController::index() pour la
            // vignette : poster_url n'est pas garanti (produit publié
            // via image_files sans couverture dédiée).
            'product_image' => $product->poster_full_url ?? ($product->images[0] ?? null),
            'transaction_id' => $transaction?->id,
        ];
    }

    private function postTagMessage(
        Conversation $conversation,
        Product $product,
        ?Transaction $transaction,
        ?string $taggedBy,
    ): void {
        // L'auteur est celui qui tague. Repli sur buyer_id uniquement si
        // personne n'est précisé (ancien comportement).
        $senderId = $transaction?->buyer_id ?? $taggedBy ?? $conversation->buyer_id;

        Message::create([
            'conversation_id' => $conversation->id,
            'sender_id' => $senderId,
            'body' => $transaction ? 'Commande passée : ' . $product->title : 'Produit : ' . $product->title,
            'type' => 'product_tag',
            'metadata' => $this->tagMetadata($product, $transaction),
        ]);

        $conversation->update(['last_message_at' => now()]);
    }
}