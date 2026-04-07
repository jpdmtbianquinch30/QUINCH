<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\User;
use App\Models\UserReview;
use App\Services\NotificationService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class ReviewController extends Controller
{
    public function __construct(private NotificationService $notif) {}
    public function sellerReviews(User $user): JsonResponse
    {
        $reviews = UserReview::where('seller_id', $user->id)
            ->with('reviewer:id,full_name,username,avatar_url')
            ->orderBy('created_at', 'desc')
            ->paginate(20);

        $stats = [
            'average' => UserReview::where('seller_id', $user->id)->avg('rating') ?? 0,
            'total' => UserReview::where('seller_id', $user->id)->count(),
            'distribution' => [
                5 => UserReview::where('seller_id', $user->id)->where('rating', 5)->count(),
                4 => UserReview::where('seller_id', $user->id)->where('rating', 4)->count(),
                3 => UserReview::where('seller_id', $user->id)->where('rating', 3)->count(),
                2 => UserReview::where('seller_id', $user->id)->where('rating', 2)->count(),
                1 => UserReview::where('seller_id', $user->id)->where('rating', 1)->count(),
            ],
            'avg_delivery' => UserReview::where('seller_id', $user->id)->avg('delivery_rating') ?? 0,
            'avg_communication' => UserReview::where('seller_id', $user->id)->avg('communication_rating') ?? 0,
            'avg_accuracy' => UserReview::where('seller_id', $user->id)->avg('accuracy_rating') ?? 0,
        ];

        return response()->json(['reviews' => $reviews, 'stats' => $stats]);
    }

    public function create(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'seller_id' => 'required|exists:users,id',
            'transaction_id' => 'nullable|exists:transactions,id',
            'rating' => 'required|integer|min:1|max:5',
            'comment' => 'nullable|string|max:1000',
            'delivery_rating' => 'nullable|numeric|min:1|max:5',
            'communication_rating' => 'nullable|numeric|min:1|max:5',
            'accuracy_rating' => 'nullable|numeric|min:1|max:5',
        ]);

        if ((string)$request->user()->id === (string)$validated['seller_id']) {
            return response()->json(['message' => 'Vous ne pouvez pas vous évaluer vous-même.'], 422);
        }

        // Prevent duplicate reviews: one review per reviewer per seller
        $existing = UserReview::where('reviewer_id', $request->user()->id)
            ->where('seller_id', $validated['seller_id'])
            ->first();

        if ($existing) {
            return response()->json(['message' => 'Vous avez déjà évalué ce vendeur.'], 422);
        }

        $review = UserReview::create([...$validated, 'reviewer_id' => $request->user()->id]);

        // Notify seller
        $this->notif->notifyReview(
            $validated['seller_id'],
            $request->user(),
            $validated['rating'],
            $validated['comment'] ?? 'Aucun commentaire'
        );

        return response()->json(['review' => $review->load('reviewer'), 'message' => 'Avis publié.'], 201);
    }

    public function respond(Request $request, UserReview $review): JsonResponse
    {
        if ($review->seller_id !== $request->user()->id) abort(403);

        $validated = $request->validate(['response' => 'required|string|max:1000']);
        $review->update(['seller_response' => $validated['response'], 'seller_responded_at' => now()]);

        return response()->json(['review' => $review->fresh(), 'message' => 'Réponse publiée.']);
    }
}
