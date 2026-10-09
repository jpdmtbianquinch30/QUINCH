<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\FavoriteCollection;
use App\Models\FavoriteItem;
use App\Models\Product;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class FavoriteController extends Controller
{
    public function index(Request $request): JsonResponse
    {
        $favorites = FavoriteItem::where('user_id', $request->user()->id)
            ->with('product.video', 'product.category', 'collection')
            ->orderBy('created_at', 'desc')
            ->paginate(20);

        return response()->json($favorites);
    }

    public function toggle(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'product_id' => 'required|uuid|exists:products,id',
            'collection_id' => 'nullable|uuid|exists:favorite_collections,id',
        ]);

        $userId = $request->user()->id;

        // La collection doit appartenir à l'utilisateur.
        if (!empty($validated['collection_id'])
            && !\App\Models\FavoriteCollection::where('id', $validated['collection_id'])->where('user_id', $userId)->exists()) {
            return response()->json(['message' => 'Collection introuvable.', 'errors' => ['collection_id' => ['Collection introuvable.']]], 422);
        }

        // delete() renvoie le nombre de lignes supprimées : atomique.
        $deleted = FavoriteItem::where('user_id', $userId)
            ->where('product_id', $validated['product_id'])
            ->delete();

        if ($deleted > 0) {
            return response()->json(['favorited' => false, 'message' => 'Retiré des favoris.']);
        }

        $product = Product::findOrFail($validated['product_id']);

        try {
            FavoriteItem::create([
                'user_id' => $userId,
                'product_id' => $product->id,
                'collection_id' => $validated['collection_id'] ?? null,
                'price_at_save' => $product->price,
            ]);
        } catch (\Illuminate\Database\UniqueConstraintViolationException $e) {
            // Ajout simultané déjà effectué : résultat identique.
        }

        return response()->json([
            'favorited' => true,
            'message' => 'Ajouté aux favoris.',
            'favorites_count' => FavoriteItem::where('user_id', $userId)->count(),
        ]);
    }

    // Collections
    public function collections(Request $request): JsonResponse
    {
        $collections = FavoriteCollection::where('user_id', $request->user()->id)
            ->withCount('items')
            ->orderBy('created_at', 'desc')
            ->get();

        return response()->json(['collections' => $collections]);
    }

    public function createCollection(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'name' => 'required|string|max:100',
            'is_public' => 'sometimes|boolean',
        ]);

        $collection = FavoriteCollection::create([
            'user_id' => $request->user()->id,
            'name' => $validated['name'],
            'is_public' => $validated['is_public'] ?? false,
        ]);

        return response()->json(['collection' => $collection], 201);
    }

    public function count(Request $request): JsonResponse
    {
        return response()->json([
            'count' => FavoriteItem::where('user_id', $request->user()->id)->count(),
        ]);
    }
}
