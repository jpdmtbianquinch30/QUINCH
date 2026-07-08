<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\Product;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class MarketplaceController extends Controller
{
    /**
     * Explorer endpoint — filtrable par catégorie, recherche, type, prix, tri.
     * Différent du feed (pas d'algo de scoring, juste tri classique).
     */
    public function index(Request $request): JsonResponse
    {
        $query = Product::with(['user:id,username,avatar_url,trust_score', 'category:id,name,slug', 'video'])
            ->where('status', 'active')
            ->where(function ($q) {
                $q->whereNotNull('poster_url')
                  ->orWhereHas('video', fn($s) => $s->whereIn('moderation_status', ['approved', 'pending']))
                  ->orWhere(function ($s) {
                      $s->whereNotNull('images')->whereRaw("images::jsonb != '[]'::jsonb");
                  });
            });

        // Recherche texte
        if ($request->filled('q')) {
            $search = '%' . $request->q . '%';
            $query->where(function ($q) use ($search) {
                $q->where('title', 'ilike', $search)
                  ->orWhere('description', 'ilike', $search);
            });
        }

        // Filtre catégorie
        if ($request->filled('category')) {
            $query->where('category_id', $request->category);
        }

        // Filtre type (product / service)
        if ($request->filled('type') && in_array($request->type, ['product', 'service'])) {
            $query->where('type', $request->type);
        }

        // Filtre vendeur
        if ($request->filled('seller_id')) {
            $query->where('user_id', $request->seller_id);
        }

        // Filtre prix
        if ($request->filled('price_min')) {
            $query->where('price', '>=', (int) $request->price_min);
        }
        if ($request->filled('price_max')) {
            $query->where('price', '<=', (int) $request->price_max);
        }

        // Tri
        $sortBy = $request->get('sort_by', 'recent');
        match ($sortBy) {
            'price_asc'  => $query->orderBy('price', 'asc'),
            'price_desc' => $query->orderBy('price', 'desc'),
            'popular'    => $query->orderByDesc('like_count'),
            default      => $query->latest(),
        };

        $perPage = min((int) $request->get('per_page', 20), 50);
        $products = $query->paginate($perPage);

        $authUser = $request->user();
        $productIds = $products->pluck('id')->toArray();
        $likedIds = $savedIds = [];

        if ($authUser && count($productIds)) {
            $likedIds = $authUser->likedProducts()->whereIn('product_id', $productIds)->pluck('product_id')->toArray();
            $savedIds = $authUser->savedProducts()->whereIn('product_id', $productIds)->pluck('product_id')->toArray();
        }

        $items = $products->getCollection()->map(function ($product) use ($likedIds, $savedIds) {
            $thumbnail = $product->poster_full_url
                ?? ($product->video?->id ? '/api/v1/videos/' . $product->video->id . '/thumbnail' : null)
                ?? ($product->images[0] ?? null);

            return [
                'id'           => $product->id,
                'title'        => $product->title,
                'slug'         => $product->slug,
                'description'  => $product->description,
                'price'        => $product->price,
                'currency'     => $product->currency ?? 'XOF',
                'type'         => $product->type ?? 'product',
                'poster'       => $product->poster_full_url,
                'thumbnail'    => $thumbnail,
                'images'       => $product->images ?? [],
                'like_count'   => $product->like_count ?? 0,
                'view_count'   => $product->view_count ?? 0,
                'category'     => $product->category?->name,
                'category_id'  => $product->category_id,
                'seller'       => [
                    'id'          => $product->user?->id,
                    'username'    => $product->user?->username,
                    'avatar'      => $product->user?->avatar_url,
                    'trust_score' => $product->user?->trust_score,
                ],
                'is_liked'     => in_array($product->id, $likedIds),
                'is_saved'     => in_array($product->id, $savedIds),
                'created_at'   => $product->created_at,
            ];
        });

        return response()->json([
            'data'         => $items,
            'current_page' => $products->currentPage(),
            'last_page'    => $products->lastPage(),
            'total'        => $products->total(),
            'per_page'     => $products->perPage(),
        ]);
    }
}