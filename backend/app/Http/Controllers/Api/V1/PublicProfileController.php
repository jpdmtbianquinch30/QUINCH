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
    public function show(Request $request, string $username): JsonResponse
    {
        $user = User::where('username', $username)->firstOrFail();

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

        $badges = UserBadge::where('user_id', $user->id)->get()->map(fn ($b) => [
            'type' => $b->badge_type,
            'name' => UserBadge::badgeDefinitions()[$b->badge_type]['name'] ?? $b->badge_type,
            'icon' => UserBadge::badgeDefinitions()[$b->badge_type]['icon'] ?? 'stars',
            'color' => UserBadge::badgeDefinitions()[$b->badge_type]['color'] ?? '#666',
            'description' => UserBadge::badgeDefinitions()[$b->badge_type]['description'] ?? '',
            'awarded_at' => $b->created_at?->toISOString(),
        ]);

        $authUser = auth('sanctum')->user();
        $isFollowing = $authUser
            ? UserFollow::where('follower_id', $authUser->id)->where('following_id', $user->id)->exists()
            : false;

        // Total revenue for seller
        $totalRevenue = Transaction::where('seller_id', $user->id)
            ->where('payment_status', 'completed')
            ->sum('amount');

        return response()->json([
            'user' => [
                'id' => $user->id,
                'username' => $user->username,
                'full_name' => $user->full_name,
                'avatar_url' => $user->avatar_url,
                'cover_url' => $user->cover_url,
                'bio' => $user->bio ?? null,
                'city' => $user->city,
                'region' => $user->region,
                'trust_score' => $user->trust_score,
                'trust_badge' => $user->trust_badge,
                'kyc_status' => $user->kyc_status,
                'member_since' => $user->created_at->format('M Y'),
                'created_at' => $user->created_at->toISOString(),
                'account_age_days' => $user->account_age_days,
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
                'total_revenue' => $totalRevenue,
            ],
            'badges' => $badges,
            'is_following' => $isFollowing,
        ]);
    }

    public function products(Request $request, string $username): JsonResponse
    {
        $user = User::where('username', $username)->firstOrFail();

        $query = Product::where('user_id', $user->id)
            ->where('status', 'active')
            ->with('video', 'category');

        // Filters
        if ($request->has('category') && $request->category) {
            $query->where('category_id', $request->category);
        }
        if ($request->has('condition') && $request->condition) {
            $query->where('condition', $request->condition);
        }
        if ($request->has('min_price') && $request->min_price) {
            $query->where('price', '>=', $request->min_price);
        }
        if ($request->has('max_price') && $request->max_price) {
            $query->where('price', '<=', $request->max_price);
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

        $products = $query->paginate($request->get('per_page', 12));

        return response()->json($products);
    }
}
