<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\Product;
use App\Models\User;
use App\Models\UserFollow;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

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
            ->withCount(['savedByUsers', 'reviews'])
            ->with(['user:id,full_name,username,avatar_url,trust_score,is_premium,premium_expires_at', 'category:id,name,icon', 'video']);

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
            // Borne la liste et ne garde que des chaînes.
            $excludeIds = array_slice(array_values(array_filter($excludeIds, 'is_string')), 0, 200);
            if (!empty($excludeIds)) {
                $query->whereNotIn('products.id', $excludeIds);
            }
        }


        if (!$request->has('q') || empty($request->q)) {
            // Publication immédiate, modération après : une vidéo « pending » est visible ;
            // seules les vidéos rejetées ou mises en vérification sont exclues.
            $query->whereHas('video', function ($sub) {
                $sub->whereNotIn('moderation_status', ['rejected', 'flagged']);
            });
        }


        if ($request->has('type') && in_array($request->type, ['product', 'service'])) {
            $query->where('type', $request->type);
        }


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
            $searchTerm = $this->likeTerm((string) $request->q);
            $query->where(function ($q) use ($searchTerm) {
                $q->where('products.title', 'ILIKE', $searchTerm)
                  ->orWhere('products.description', 'ILIKE', $searchTerm)
                  ->orWhere('products.slug', 'ILIKE', $searchTerm)
                  ->orWhereRaw('products.id::text ILIKE ?', [$searchTerm]);
            });
        }

        // Price range
        if ($request->has('min_price') || $request->has('max_price')) {
            $query->priceRange($request->min_price, $request->max_price);
        }

        // ═══ TRI ═══
        // ?sort=recent | popular | day (dernières 24 h, classées par popularité).
        // Sans paramètre : "Pour toi" (paliers) ; onglet abonnements : du plus
        // récent au plus ancien (l'ancien ordre aléatoire dupliquait des
        // annonces d'une page à l'autre).
        $sort = $request->get('sort');

        if ($sort === 'day') {
            $query->where('products.created_at', '>=', now()->subDay());
        }

        if ($sort === 'day' || $sort === 'popular') {
            $query->orderByRaw('(products.like_count * 3 + products.view_count + COALESCE(products.share_count, 0) * 2) DESC')
                  ->orderByDesc('products.created_at');
        } elseif ($sort === 'recent' || $request->has('q') || $tab === 'following') {
            $query->orderByDesc('products.created_at');
        } else {
            // "Pour toi" : même algorithme de paliers que l'Explorer et la recherche.
            $query->tieredRank();
        }

        $products = $query->paginate($this->perPage($request, 10, 30));
        $sellerIds = $products->pluck('user_id')->unique()->all();
        $sellerBadges = \App\Models\UserBadge::summaryForMany($sellerIds);
        $sellerReviewCounts = \App\Models\UserReview::whereIn('seller_id', $sellerIds)
            ->selectRaw('seller_id, count(*) as cnt')
            ->groupBy('seller_id')
            ->pluck('cnt', 'seller_id');

        // Get liked/saved status for authenticated user
        $likedIds = [];
        $savedIds = [];
        $followingIds = [];
        if ($authUser) {
            $productIds = $products->pluck('id')->toArray();
            $likedIds = $authUser->likedProducts()->whereIn('product_id', $productIds)->pluck('product_id')->toArray();
            $savedIds = \App\Models\FavoriteItem::where('user_id', $authUser->id)->whereIn('product_id', $productIds)->pluck('product_id')->toArray();
            $followingIds = UserFollow::where('follower_id', $authUser->id)->pluck('following_id')->toArray();
        }

        // Transform for feed display
        $products->getCollection()->transform(function ($product) use ($likedIds, $savedIds, $followingIds, $authUser, $sellerBadges, $sellerReviewCounts) {
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
                'save_count' => $product->saved_by_users_count ?? 0,
                'review_count' => $product->reviews_count ?? 0,
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
                    'badges' => $sellerBadges[$product->user->id] ?? [],
'is_premium' => $product->user->isPremiumActive(),
'review_count' => $sellerReviewCounts[$product->user->id] ?? 0,
                ],
                'created_at' => $product->created_at,
            ];
        });

        return response()->json($products);
    }

    /**
     * Friends feed: products from mutual followers only.
     */

    private function suggestedSellers(int $limit = 6)
{
    return \App\Models\User::query()
        ->where('is_seller', true)
        ->where('account_status', 'active')
        ->whereHas('products', fn ($q) => $q->where('status', 'active'))
        ->select('id', 'full_name', 'username', 'avatar_url', 'trust_score', 'city', 'is_premium', 'premium_expires_at')
        ->orderByRaw("(CASE WHEN is_premium = true AND premium_expires_at > NOW() THEN 1 ELSE 0 END) DESC")
        ->orderByDesc('trust_score')
        ->limit($limit)
        ->get()
        ->map(fn ($u) => [
            'id' => $u->id,
            'full_name' => $u->full_name,
            'username' => $u->username,
            'avatar_url' => $u->avatar_url,
            'trust_score' => $u->trust_score,
            'city' => $u->city,
            'is_premium' => $u->isPremiumActive(),
        ]);
}

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
            ->withCount(['savedByUsers', 'reviews'])
            ->with(['user:id,full_name,username,avatar_url,trust_score,is_premium,premium_expires_at', 'category:id,name,icon', 'video'])
            ->where(function ($q) {
                $q->whereNotNull('poster_url')
                  ->orWhereHas('video', function ($sub) {
                      $sub->whereNotIn('moderation_status', ['rejected', 'flagged']);
                  })
                  ->orWhere(function ($sub) {
                      $sub->whereNotNull('images')->whereRaw("images::jsonb != '[]'::jsonb");
                  });
            })
            ->latest();

        $products = $query->paginate($request->get('per_page', 10));
        $sellerIds = $products->pluck('user_id')->unique()->all();
        $sellerBadges = \App\Models\UserBadge::summaryForMany($sellerIds);
        $sellerReviewCounts = \App\Models\UserReview::whereIn('seller_id', $sellerIds)
            ->selectRaw('seller_id, count(*) as cnt')
            ->groupBy('seller_id')
            ->pluck('cnt', 'seller_id');

        // Get interaction status
        $productIds = $products->pluck('id')->toArray();
        $likedIds = $authUser->likedProducts()->whereIn('product_id', $productIds)->pluck('product_id')->toArray();
        $savedIds = \App\Models\FavoriteItem::where('user_id', $authUser->id)->whereIn('product_id', $productIds)->pluck('product_id')->toArray();

        $products->getCollection()->transform(function ($product) use ($likedIds, $savedIds, $sellerBadges, $sellerReviewCounts) {
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
                'save_count' => $product->saved_by_users_count ?? 0,
                'review_count' => $product->reviews_count ?? 0,
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
                    'is_premium' => $product->user->isPremiumActive(),
                    'badges' => $sellerBadges[$product->user->id] ?? [],
                    'review_count' => $sellerReviewCounts[$product->user->id] ?? 0,
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
    ->with(['user:id,full_name,username,avatar_url,is_premium,premium_expires_at', 'video'])
    ->where(function ($query) use ($q) {
        // ILIKE : insensible à la casse (LIKE ne l'est pas sous PostgreSQL).
        // Recherche aussi par identifiant (début d'UUID) et par lien (slug).
        $term = $this->likeTerm((string) $q);
        $query->where('products.title', 'ILIKE', $term)
              ->orWhere('products.description', 'ILIKE', $term)
              ->orWhere('products.slug', 'ILIKE', $term)
              ->orWhereRaw('products.id::text ILIKE ?', [$term]);
    })
    ->tieredRank()
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
            'seller_is_premium' => $product->user?->isPremiumActive() ?? false,
        ];
    });

        // Search users (sellers)
         $userResults = User::query()
            ->where('account_status', 'active')
            ->where(function ($query) use ($q) {
                $term = $this->likeTerm((string) $q);
                $query->where('full_name', 'ILIKE', $term)
                      ->orWhere('username', 'ILIKE', $term)
                      ->orWhereRaw('users.id::text ILIKE ?', [$term]);
            })
            ->select('id', 'full_name', 'username', 'avatar_url', 'trust_score', 'city', 'is_premium', 'premium_expires_at')
            ->orderByRaw("(CASE WHEN is_premium = true AND premium_expires_at > NOW() THEN 1 ELSE 0 END) DESC")
            ->limit(10)
            ->get();

        $userBadges = \App\Models\UserBadge::summaryForMany($userResults->pluck('id')->all());

        $users = $userResults->map(fn ($u) => [
            'id' => $u->id,
            'full_name' => $u->full_name,
            'username' => $u->username,
            'avatar_url' => $u->avatar_url,
            'trust_score' => $u->trust_score,
            'city' => $u->city,
            'is_premium' => $u->isPremiumActive(),
            'badges' => $userBadges[$u->id] ?? [],
        ]);

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
        $sharedProductIds = DB::table('product_shares')
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
                'seller_is_premium' => $p->user?->isPremiumActive() ?? false,
            ]);

        return response()->json(['suggestions' => $suggestions, 'sellers' => $this->suggestedSellers()]);
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
                'seller_is_premium' => $p->user?->isPremiumActive() ?? false,
            ]);

        return response()->json(['suggestions' => $trending, 'sellers' => $this->suggestedSellers()]);
    }
    /**
     * Vendeurs les plus actifs — triés par engagement (likes + vues + produits actifs)
     */
        public function activeSellers(Request $request): JsonResponse
    {
        $sellers = \App\Models\User::query()
            ->where('is_seller', true)
            ->where('account_status', 'active')
            ->whereHas('products', function ($q) {
                $q->where('status', 'active');
            })
            ->withCount(['products as active_products_count' => function ($q) {
                $q->where('status', 'active');
            }])
            ->withSum(['products as total_likes' => function ($q) {
                $q->where('status', 'active');
            }], 'like_count')
            ->withSum(['products as total_views' => function ($q) {
                $q->where('status', 'active');
            }], 'view_count')
            // Borne la charge : on ne score que les 60 vendeurs les plus actifs (au lieu de toute la table).
            ->orderByDesc('active_products_count')
            ->limit(60)
            ->get()
            ->map(function ($u) {
                $premiumBoost = $u->isPremiumActive() ? config('quinch.premium.feed_boost', 30) : 0;
                $u->engagement_score = ((float) ($u->total_likes ?? 0)) * 3
                    + ((float) ($u->total_views ?? 0))
                    + ((float) ($u->active_products_count ?? 0)) * 5
                    + $premiumBoost;
                return $u;
            })
            ->sortByDesc('engagement_score')
            ->take(15)
            ->values();

        $sellerBadges = \App\Models\UserBadge::summaryForMany($sellers->pluck('id')->all());

        $sellers = $sellers
            ->map(function ($u) use ($sellerBadges) {
                $avatar = $u->avatar_url;
                if ($avatar && !str_starts_with($avatar, 'http')) {
                    $avatar = url('storage/' . $avatar);
                }
                return [
                    'id'             => $u->id,
                    'username'       => $u->username,
                    'full_name'      => $u->full_name,
                    'avatar_url'     => $avatar,
                    'city'           => $u->city,
                    'trust_score'    => $u->trust_score,
                    'products_count' => $u->active_products_count,
                    'total_likes'    => (int) ($u->total_likes ?? 0),
                    'is_premium'     => $u->isPremiumActive(),
                    'badges'         => $sellerBadges[$u->id] ?? [],
                ];
            });

        return response()->json(['sellers' => $sellers]);
    }
}
