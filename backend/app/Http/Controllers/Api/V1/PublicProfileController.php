<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\Product;
use App\Models\Transaction;
use App\Models\User;
use App\Models\UserBadge;
use App\Models\UserFollow;
use App\Models\UserReview;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class PublicProfileController extends Controller
{
    /**
     * Profil public : introuvable (404) s'il est banni ou anonymisé (compte supprimé).
     * Le chiffre d'affaires du vendeur n'est JAMAIS exposé publiquement.
     */
    private function findPublicUser(string $username): User
    {
        $user = User::where('username', $username)->firstOrFail();

        if ($user->isBanned() || $user->anonymized_at !== null) {
            abort(404, 'Profil introuvable.');
        }

        return $user;
    }

    public function show(Request $request, string $username): JsonResponse
    {
        $user = $this->findPublicUser($username);

        $authUser = auth('sanctum')->user();
        if (!$authUser || $authUser->id !== $user->id) {
            $viewer = $authUser?->id ?? $request->ip();
            if (\Illuminate\Support\Facades\Cache::add("profile_view:{$user->id}:{$viewer}", 1, now()->addMinutes(10))) {
                $user->increment('profile_views_count');
            }
        }

        $productsCount = Product::where('user_id', $user->id)->where('status', 'active')->count();
        $soldCount = Transaction::where('seller_id', $user->id)->where('payment_status', 'completed')->count();
        $followerCount = UserFollow::where('following_id', $user->id)->count();
        $followingCount = UserFollow::where('follower_id', $user->id)->count();
        $totalLikes = Product::where('user_id', $user->id)->sum('like_count');
        $avgRating = UserReview::where('seller_id', $user->id)->avg('rating') ?? 0;
        $reviewCount = UserReview::where('seller_id', $user->id)->count();

        // Sub-ratings
        $avgDelivery = UserReview::where('seller_id', $user->id)->avg('delivery_rating') ?? 0;
        $avgCommunication = UserReview::where('seller_id', $user->id)->avg('communication_rating') ?? 0;
        $avgAccuracy = UserReview::where('seller_id', $user->id)->avg('accuracy_rating') ?? 0;

        $badges = UserBadge::summaryFor($user->id);

        $isFollowing = $authUser
            ? UserFollow::where('follower_id', $authUser->id)->where('following_id', $user->id)->exists()
            : false;

        return response()->json([
            'user' => [
                'id' => $user->id,
                'username' => $user->username,
                'full_name' => $user->full_name,
                'avatar_url' => $user->avatar_url,
                'cover_url' => $user->cover_url,
                'bio' => $user->bio ?? null,
                'website' => $user->website ?? null,
                'city' => $user->city,
                'region' => $user->region,
                'trust_score' => $user->trust_score,
                'trust_badge' => $user->trust_badge,
                'kyc_status' => $user->kyc_status,
                'seller_policies' => $user->seller_policies ?? null,
                'is_premium' => $user->isPremiumActive(),
                'member_since' => $user->created_at->format('M Y'),
                'created_at' => $user->created_at->toISOString(),
                'account_age_days' => $user->account_age_days,
                'is_online' => $user->is_online,
                'last_seen_at' => $user->last_seen_at?->toISOString(),
            ],
            'stats' => [
                'products_count' => $productsCount,
                'sold_count' => $soldCount,
                'follower_count' => $followerCount,
                'following_count' => $followingCount,
                'total_likes' => (int)$totalLikes,
                'avg_rating' => round($avgRating, 1),
                'review_count' => $reviewCount,
                'avg_delivery' => round($avgDelivery, 1),
                'avg_communication' => round($avgCommunication, 1),
                'avg_accuracy' => round($avgAccuracy, 1),
            ],
            'badges' => $badges,
            'is_following' => $isFollowing,
        ]);
    }

    public function products(Request $request, string $username): JsonResponse
    {
        $user = $this->findPublicUser($username);

        $query = Product::where('user_id', $user->id)
            ->where('status', 'active')
            ->with('video', 'category');

        // Filters
        if (is_string($request->category) && \Illuminate\Support\Str::isUuid($request->category)) {
            $query->where('category_id', $request->category);
        }
        if ($request->has('condition') && $request->condition) {
            $query->where('condition', $request->condition);
        }
        if (is_numeric($request->min_price) && (float) $request->min_price > 0) {
            $query->where('price', '>=', (float) $request->min_price);
        }
        if (is_numeric($request->max_price) && (float) $request->max_price > 0) {
            $query->where('price', '<=', (float) $request->max_price);
        }
        if ($request->has('q') && $request->q) {
            $query->where('title', 'LIKE', '%' . $request->q . '%');
        }

        // Sort
        $sort = $request->get('sort', 'newest');
        switch ($sort) {
            case 'price_asc':
                $query->orderBy('price', 'asc');
                break;
            case 'price_desc':
                $query->orderBy('price', 'desc');
                break;
            case 'popular':
                $query->orderByDesc('like_count');
                break;
            case 'views':
                $query->orderByDesc('view_count');
                break;
            default:
                $query->latest();
        }

        $products = $query->paginate($this->perPage($request, 12, 30));

        return response()->json($products);
    }
}
