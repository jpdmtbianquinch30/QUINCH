<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\Product;
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
        $user = $request->user();
        $isSaved = $product->savedByUsers()->where('user_id', $user->id)->exists();

        if ($isSaved) {
            $product->savedByUsers()->detach($user->id);
        } else {
            $product->savedByUsers()->attach($user->id);
        }

        return response()->json([
            'saved' => !$isSaved,
        ]);
    }

    public function report(Request $request, Product $product): JsonResponse
    {
        $request->validate([
            'reason' => ['sometimes', 'string', 'max:500'],
        ]);

        // Prevent duplicate reports
        $exists = \DB::table('product_reports')
            ->where('user_id', $request->user()->id)
            ->where('product_id', $product->id)
            ->exists();

        if ($exists) {
            return response()->json(['message' => 'Vous avez déjà signalé ce produit.'], 422);
        }

        \DB::table('product_reports')->insert([
            'user_id' => $request->user()->id,
            'product_id' => $product->id,
            'reason' => $request->reason ?? 'Non spécifié',
            'created_at' => now(),
            'updated_at' => now(),
        ]);

        return response()->json(['message' => 'Signalement envoyé. Merci pour votre vigilance.']);
    }
}
