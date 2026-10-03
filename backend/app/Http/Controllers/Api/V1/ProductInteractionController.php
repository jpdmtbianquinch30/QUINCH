<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\Product;
use App\Models\ProductReport;
use App\Services\NotificationService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

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

        [$liked, $isNewLike] = DB::transaction(function () use ($user, $product) {
            // detach() renvoie le nombre de lignes réellement supprimées :
            // l'opération est atomique côté SQL (pas de "exists puis delete").
            if ($product->likedByUsers()->detach($user->id) > 0) {
                // Le compteur ne descend jamais sous 0, même s'il était désynchronisé.
                Product::whereKey($product->id)->where('like_count', '>', 0)->decrement('like_count');

                return [false, false];
            }

            // insertOrIgnore = INSERT ... ON CONFLICT DO NOTHING (clé unique user+produit) :
            // un double clic simultané ne provoque plus d'erreur 500 ni de double comptage.
            $inserted = DB::table('product_likes')->insertOrIgnore([
                'user_id'    => $user->id,
                'product_id' => $product->id,
                'created_at' => now(),
                'updated_at' => now(),
            ]);

            if ($inserted > 0) {
                Product::whereKey($product->id)->increment('like_count');
            }

            return [true, $inserted > 0];
        });

        // Notifier le vendeur seulement pour un NOUVEAU like (pas pour soi-même).
        if ($isNewLike && $product->user_id !== $user->id) {
            $this->notif->notifyLike($product->user_id, $user, $product->slug, $product->title);
        }

        return response()->json([
            'liked' => $liked,
            'like_count' => (int) Product::whereKey($product->id)->value('like_count'),
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
        // Même table que la page Favoris (favorite_items).
        $user = $request->user();

        // delete() renvoie le nombre de lignes supprimées : atomique.
        $deleted = \App\Models\FavoriteItem::where('user_id', $user->id)
            ->where('product_id', $product->id)
            ->delete();

        if ($deleted > 0) {
            return response()->json(['saved' => false]);
        }

        try {
            \App\Models\FavoriteItem::create([
                'user_id' => $user->id,
                'product_id' => $product->id,
                'price_at_save' => $product->price,
            ]);
        } catch (\Illuminate\Database\UniqueConstraintViolationException $e) {
            // Une requête simultanée l'a déjà ajouté : résultat identique.
        }

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
