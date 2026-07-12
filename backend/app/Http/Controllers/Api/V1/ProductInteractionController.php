<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\Product;
use App\Models\ProductReport;
use App\Services\NotificationService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class ProductInteractionController extends Controller
{
    public function __construct(private NotificationService $notif) {}
    /**
     * Get all products liked by the authenticated user.
     */
    public function myLikes(Request $request): JsonResponse
    {
        $products = $request->user()
            ->likedProducts()
            ->with(['video', 'user:id,username,full_name,avatar_url'])
            ->latest('product_likes.created_at')
            ->get();

        return response()->json(['data' => $products]);
    }

    public function view(Request $request, Product $product): JsonResponse
    {
        $product->increment('view_count');

        if ($product->video) {
            $product->video->increment('view_count');
        }

        return response()->json(['view_count' => $product->view_count]);
    }

    public function toggleLike(Request $request, Product $product): JsonResponse
    {
        $user = $request->user();
        $isLiked = $product->likedByUsers()->where('user_id', $user->id)->exists();

        if ($isLiked) {
            $product->likedByUsers()->detach($user->id);
            $product->decrement('like_count');
        } else {
            $product->likedByUsers()->attach($user->id);
            $product->increment('like_count');

            // Notify product owner (don't notify self)
            if ($product->user_id !== $user->id) {
                $this->notif->notifyLike($product->user_id, $user, $product->slug, $product->title);
            }
        }

        return response()->json([
            'liked' => !$isLiked,
            'like_count' => $product->fresh()->like_count,
        ]);
    }

    public function share(Request $request, Product $product): JsonResponse
    {
        $product->increment('share_count');

        return response()->json([
            'share_count' => $product->share_count,
        ]);
    }

    public function toggleSave(Request $request, Product $product): JsonResponse
    {
        // BUG CORRIGE : ce bouton (affiché partout dans le feed) manipulait
        // un pivot "product_saves" totalement déconnecté de la vraie page
        // Favoris (qui lit la table favorite_items via FavoriteController).
        // Résultat : un produit "sauvegardé" depuis le feed n'apparaissait
        // JAMAIS dans les Favoris de l'utilisateur. On utilise maintenant
        // la même table des deux côtés.
        $user = $request->user();
        $existing = \App\Models\FavoriteItem::where('user_id', $user->id)
            ->where('product_id', $product->id)
            ->first();

        if ($existing) {
            $existing->delete();
            return response()->json(['saved' => false]);
        }

        \App\Models\FavoriteItem::create([
            'user_id' => $user->id,
            'product_id' => $product->id,
            'price_at_save' => $product->price,
        ]);

        return response()->json(['saved' => true]);
    }

    public function report(Request $request, Product $product): JsonResponse
    {
        // BUG CRITIQUE CORRIGE : l'ancien code faisait un DB::table()->insert()
        // avec une colonne "user_id" qui n'existe pas dans product_reports (la
        // vraie colonne est "reporter_id") -> l'INSERT échouait en 500 à
        // CHAQUE appel. Aucun signalement produit n'a donc jamais été
        // réellement enregistré jusqu'ici.
        $validated = $request->validate([
            'reason' => ['required', 'string', 'in:fraud,inappropriate,counterfeit,spam,other'],
            'description' => ['nullable', 'string', 'max:2000'],
        ]);

        $exists = ProductReport::where('reporter_id', $request->user()->id)
            ->where('product_id', $product->id)
            ->where('status', 'pending')
            ->exists();

        if ($exists) {
            return response()->json(['message' => 'Vous avez déjà signalé ce produit. Le signalement est en cours de traitement.'], 409);
        }

        ProductReport::create([
            'reporter_id' => $request->user()->id,
            'product_id' => $product->id,
            'reason' => $validated['reason'],
            'description' => $validated['description'] ?? null,
        ]);

        return response()->json(['message' => 'Signalement envoyé. Merci pour votre vigilance.']);
    }
}
