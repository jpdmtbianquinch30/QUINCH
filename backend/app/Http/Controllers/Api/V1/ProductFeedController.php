<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\Product;
use App\Models\User;
use App\Models\UserFollow;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class ProductFeedController extends Controller
{
    /**
     * TikTok-like infinite scroll feed with dynamic ranking.
     *
     * Supports:
     *   ?tab=following|friends|foryou (default: foryou)
     *   ?exclude_ids=id1,id2,...  — skip already-displayed items
     *   ?seed=<int>              — per-session random seed for consistency within a session
     */
    public function index(Request $request): JsonResponse
    {
        $tab = $request->get('tab', 'foryou');
        $authUser = $request->user('sanctum');

        $query = Product::query()
            ->active()
            ->with(['user:id,full_name,username,avatar_url,trust_score', 'category:id,name,icon', 'video']);

        // For "following" tab, filter by followed users
        if ($tab === 'following' && $authUser) {
            $followingIds = UserFollow::where('follower_id', $authUser->id)->pluck('following_id');
            $query->whereIn('user_id', $followingIds);
        }

        // ═══ Exclude already-seen products ═══
        if ($request->has('exclude_ids') && !empty($request->exclude_ids)) {
            $excludeIds = is_array($request->exclude_ids)
                ? $request->exclude_ids
                : array_filter(explode(',', $request->exclude_ids));
            if (!empty($excludeIds)) {
                $query->whereNotIn('products.id', $excludeIds);
            }
        }

        // Require at least one visual: poster, video, or images
        if (!$request->has('q') || empty($request->q)) {
            $query->where(function ($q) {
                $q->whereNotNull('poster_url')
                  ->orWhereHas('video', function ($sub) {
                      $sub->where('moderation_status', 'approved')
                          ->orWhere('moderation_status', 'pending');
                  })
                  ->orWhere(function ($sub) {
                      $sub->whereNotNull('images')->where('images', '!=', '[]');
                  });
            });
        }

        // Filter by type (product / service)
        if ($request->has('type') && in_array($request->type, ['product', 'service'])) {
            $query->where('type', $request->type);
        }

        // Filter by category
        if ($request->has('category')) {
            $query->where('category_id', $request->category);
        }

        // Filter by city/region
        if ($request->has('city')) {
            $query->whereHas('user', function ($q) use ($request) {
                $q->where('city', $request->city);
            });
        }

        // Search
        if ($request->has('q') && !empty($request->q)) {
            $searchTerm = $request->q;
            $query->where(function ($q) use ($searchTerm) {
                $q->where('title', 'LIKE', "%{$searchTerm}%")
                  ->orWhere('description', 'LIKE', "%{$searchTerm}%");
            });
        }

        // Price range
        if ($request->has('min_price') || $request->has('max_price')) {
            $query->priceRange($request->min_price, $request->max_price);
        }

        // ═══ SORTING ═══
        if ($request->has('q')) {
            // Search: relevance then newest
            $query->latest();
        } elseif ($tab === 'following') {
            // Following: newest first with slight randomness
            $query->inRandomOrder()->latest();
        } else {
            // "Pour toi" — DYNAMIC RANKING
            // Composite score = engagement + freshness + video quality + randomness
            // The random factor ensures different ordering on every refresh
            $seed = (int) $request->get('seed', time());

            $query->leftJoin('product_videos', 'products.video_id', '=', 'product_videos.id')
                  ->select('products.*')
                  ->selectRaw("(
                      -- Engagement score (weighted interactions)
                      (COALESCE(products.like_count, 0) * 3
                       + COALESCE(products.view_count, 0) * 0.5
                       + COALESCE(products.share_count, 0) * 5)

                      -- Freshness boost: newer posts get higher score (decays over hours)
                      + (200.0 / (TIMESTAMPDIFF(HOUR, products.created_at, NOW()) + 1))

                      -- Video quality bonus
                      + CASE
                          WHEN product_videos.resolution = '4k' THEN 15
                          WHEN product_videos.resolution = '1080p' THEN 10
                          WHEN product_videos.resolution = '720p' THEN 6
                          WHEN product_videos.resolution = '480p' THEN 3
                          ELSE 0
                        END

                      -- Has video boost (video content preferred in Pour toi)
                      + CASE WHEN products.video_id IS NOT NULL THEN 20 ELSE 0 END

                      -- Random factor: adds variation so the feed is never the same
                      -- RAND with CRC32 of id+seed gives per-row deterministic randomness for a session
                      + RAND(CRC32(CONCAT(products.id, ?))) * 40
                  ) as feed_score", [$seed])
                  ->orderByDesc('feed_score');
        }

        $products = $query->paginate($request->get('per_page', 10));

        // Get liked/saved status for authenticated user
        $likedIds = [];
        $savedIds = [];
        $followingIds = [];
        if ($authUser) {
            $productIds = $products->pluck('id')->toArray();
            $likedIds = $authUser->likedProducts()->whereIn('product_id', $productIds)->pluck('product_id')->toArray();
            $savedIds = $authUser->savedProducts()->whereIn('product_id', $productIds)->pluck('product_id')->toArray();
            $followingIds = UserFollow::where('follower_id', $authUser->id)->pluck('following_id')->toArray();
        }

        // Transform for feed display
        $products->getCollection()->transform(function ($product) use ($likedIds, $savedIds, $followingIds, $authUser) {
            return [
                'id' => $product->id,
                'type' => $product->type ?? 'product',
                'title' => $product->title,
                'slug' => $product->slug,
                'description' => \Illuminate\Support\Str::limit($product->description, 120),
                'price' => $product->price,
                'formatted_price' => $product->formatted_price,
                'currency' => $product->currency,
                'condition' => $product->condition,
                'is_negotiable' => $product->is_negotiable,
                'stock_quantity' => $product->stock_quantity,
                'view_count' => $product->view_count,
                'like_count' => $product->like_count,
                'share_count' => $product->share_count,
                'is_liked' => in_array($product->id, $likedIds),
                'is_saved' => in_array($product->id, $savedIds),
                'poster' => $product->poster_full_url,
                'payment_methods' => $product->payment_methods ?? [],
                'delivery_option' => $product->delivery_option ?? 'contact',
                'delivery_fee' => $product->delivery_fee ?? 0,
                'video' => $product->video ? [
                    'id' => $product->video->id,
                    'url' => '/api/v1/videos/' . $product->video->id . '/stream',
                    'thumbnail' => $product->video->thumbnail_path
                        ? '/api/v1/videos/' . $product->video->id . '/thumbnail'
                        : null,
                    'duration' => $product->video->duration_seconds,
                    'format' => $product->video->format,
                ] : null,
                'images' => $product->images,
                'metadata' => $product->metadata ?? [],
                'category' => $product->category,
                'seller' => [
                    'id' => $product->user->id,
                    'full_name' => $product->user->full_name,
                    'name' => $product->user->full_name,
                    'username' => $product->user->username,
                    'avatar' => $product->user->avatar_url,
                    'avatar_url' => $product->user->avatar_url,
                    'trust_score' => $product->user->trust_score,
                    'city' => $product->user->city,
                    'member_since' => $product->user->created_at?->format('M Y'),
                    'is_following' => in_array($product->user->id, $followingIds),
                ],
                'created_at' => $product->created_at,
            ];
        });

        return response()->json($products);
    }

    /**
     * Friends feed: products from mutual followers only.
     */
    public function friendsFeed(Request $request): JsonResponse
    {
        $authUser = $request->user();
        if (!$authUser) {
            return response()->json(['data' => [], 'message' => 'Authentication required.'], 401);
        }

        // Get IDs of mutual friends (I follow them AND they follow me)
        $friendIds = UserFollow::where('follower_id', $authUser->id)
            ->whereIn('following_id', function ($q) use ($authUser) {
                $q->select('follower_id')
                  ->from('user_follows')
                  ->where('following_id', $authUser->id);
            })
            ->pluck('following_id');

        $query = Product::query()
            ->active()
            ->whereIn('user_id', $friendIds)
            ->with(['user:id,full_name,username,avatar_url,trust_score', 'category:id,name,icon', 'video'])
            ->where(function ($q) {
                $q->whereNotNull('poster_url')
                  ->orWhereHas('video', function ($sub) {
                      $sub->where('moderation_status', 'approved')
                          ->orWhere('moderation_status', 'pending');
                  })
                  ->orWhere(function ($sub) {
                      $sub->whereNotNull('images')->where('images', '!=', '[]');
                  });
            })
            ->latest();

        $products = $query->paginate($request->get('per_page', 10));

        // Get interaction status
        $productIds = $products->pluck('id')->toArray();
        $likedIds = $authUser->likedProducts()->whereIn('product_id', $productIds)->pluck('product_id')->toArray();
        $savedIds = $authUser->savedProducts()->whereIn('product_id', $productIds)->pluck('product_id')->toArray();

        $products->getCollection()->transform(function ($product) use ($likedIds, $savedIds) {
            return [
                'id' => $product->id,
                'type' => $product->type ?? 'product',
                'title' => $product->title,
                'slug' => $product->slug,
                'description' => \Illuminate\Support\Str::limit($product->description, 120),
                'price' => $product->price,
                'formatted_price' => $product->formatted_price,
                'currency' => $product->currency,
                'condition' => $product->condition,
                'is_negotiable' => $product->is_negotiable,
                'stock_quantity' => $product->stock_quantity,
                'view_count' => $product->view_count,
                'like_count' => $product->like_count,
                'share_count' => $product->share_count,
                'is_liked' => in_array($product->id, $likedIds),
                'is_saved' => in_array($product->id, $savedIds),
                'poster' => $product->poster_full_url,
                'payment_methods' => $product->payment_methods ?? [],
                'delivery_option' => $product->delivery_option ?? 'contact',
                'delivery_fee' => $product->delivery_fee ?? 0,
                'video' => $product->video ? [
                    'id' => $product->video->id,
                    'url' => '/api/v1/videos/' . $product->video->id . '/stream',
                    'thumbnail' => $product->video->thumbnail_path
                        ? '/api/v1/videos/' . $product->video->id . '/thumbnail'
                        : null,
                    'duration' => $product->video->duration_seconds,
                    'format' => $product->video->format,
                ] : null,
                'images' => $product->images,
                'metadata' => $product->metadata ?? [],
                'category' => $product->category,
                'seller' => [
                    'id' => $product->user->id,
                    'full_name' => $product->user->full_name,
                    'name' => $product->user->full_name,
                    'username' => $product->user->username,
                    'avatar' => $product->user->avatar_url,
                    'avatar_url' => $product->user->avatar_url,
                    'trust_score' => $product->user->trust_score,
                    'city' => $product->user->city,
                    'member_since' => $product->user->created_at?->format('M Y'),
                    'is_following' => true,
                ],
                'created_at' => $product->created_at,
            ];
        });

        return response()->json($products);
    }

    /**
     * Search products and users.
     */
    public function search(Request $request): JsonResponse
    {
        $q = $request->get('q', '');
        if (empty($q)) {
            return response()->json(['products' => [], 'users' => []]);
        }

        // Search products
        $products = Product::query()
            ->active()
            ->with(['user:id,full_name,username,avatar_url', 'video'])
            ->where(function ($query) use ($q) {
                $query->where('title', 'LIKE', "%{$q}%")
                      ->orWhere('description', 'LIKE', "%{$q}%");
            })
            ->limit(10)
            ->get()
            ->map(function ($product) {
                return [
                    'id' => $product->id,
                    'type' => $product->type ?? 'product',
                    'title' => $product->title,
                    'slug' => $product->slug,
                    'price' => $product->price,
                    'poster' => $product->poster_full_url,
                    'image' => $product->poster_full_url ?? $product->video?->thumbnail_url ?? ($product->images[0] ?? null),
                    'seller' => $product->user?->username,
                ];
            });

        // Search users (sellers)
        $users = User::query()
            ->where('account_status', 'active')
            ->where(function ($query) use ($q) {
                $query->where('full_name', 'LIKE', "%{$q}%")
                      ->orWhere('username', 'LIKE', "%{$q}%");
            })
            ->select('id', 'full_name', 'username', 'avatar_url', 'trust_score', 'city')
            ->limit(10)
            ->get();

        return response()->json([
            'products' => $products,
            'users' => $users,
        ]);
    }

    /**
     * Personalized suggestions based on user's liked/shared content categories.
     */
    public function suggestions(Request $request): JsonResponse
    {
        $authUser = $request->user();
        if (!$authUser) {
            // Fallback: trending products for non-authenticated users
            return $this->trending($request);
        }

        // Get categories of products the user liked
        $likedCategoryIds = $authUser->likedProducts()
            ->whereNotNull('category_id')
            ->pluck('category_id')
            ->unique()
            ->toArray();

        // Get categories of products the user shared
        $sharedProductIds = \DB::table('product_shares')
            ->where('user_id', $authUser->id)
            ->pluck('product_id')
            ->toArray();
        $sharedCategoryIds = Product::whereIn('id', $sharedProductIds)
            ->whereNotNull('category_id')
            ->pluck('category_id')
            ->unique()
            ->toArray();

        $categoryIds = array_unique(array_merge($likedCategoryIds, $sharedCategoryIds));

        if (empty($categoryIds)) {
            return $this->trending($request);
        }

        // Suggest products from those categories the user hasn't seen much
        $suggestions = Product::query()
            ->active()
            ->whereIn('category_id', $categoryIds)
            ->where('user_id', '!=', $authUser->id)
            ->with(['user:id,full_name,username,avatar_url', 'category:id,name,icon', 'video'])
            ->orderByDesc('like_count')
            ->limit(8)
            ->get()
            ->map(fn ($p) => [
                'id' => $p->id,
                'title' => $p->title,
                'slug' => $p->slug,
                'price' => $p->price,
                'type' => $p->type ?? 'product',
                'poster' => $p->poster_full_url,
                'image' => $p->poster_full_url ?? ($p->video?->thumbnail_path
                    ? '/api/v1/videos/' . $p->video->id . '/thumbnail'
                    : ($p->images[0] ?? null)),
                'category' => $p->category?->name,
                'seller' => $p->user?->username,
                'like_count' => $p->like_count,
            ]);

        return response()->json(['suggestions' => $suggestions]);
    }

    /**
     * Trending products (most liked/viewed recently).
     */
    public function trending(Request $request): JsonResponse
    {
        $trending = Product::query()
            ->active()
            ->with(['user:id,full_name,username,avatar_url', 'category:id,name,icon', 'video'])
            ->orderByDesc('like_count')
            ->orderByDesc('view_count')
            ->limit(8)
            ->get()
            ->map(fn ($p) => [
                'id' => $p->id,
                'title' => $p->title,
                'slug' => $p->slug,
                'price' => $p->price,
                'type' => $p->type ?? 'product',
                'poster' => $p->poster_full_url,
                'image' => $p->poster_full_url ?? ($p->video?->thumbnail_path
                    ? '/api/v1/videos/' . $p->video->id . '/thumbnail'
                    : ($p->images[0] ?? null)),
                'category' => $p->category?->name,
                'seller' => $p->user?->username,
                'like_count' => $p->like_count,
            ]);

        return response()->json(['suggestions' => $trending]);
    }
}
