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

        // Une seule requête d'agrégat. IMPORTANT : avg() renvoie une CHAÎNE avec
        // PostgreSQL ("4.5000000000000000") ; le frontend appelait .toFixed() dessus
        // et plantait (page Avis du profil vendeur). On renvoie de vrais nombres.
        $agg = UserReview::where('seller_id', $user->id)
            ->selectRaw('COUNT(*) as total, AVG(rating) as avg_rating, AVG(delivery_rating) as avg_delivery, AVG(communication_rating) as avg_communication, AVG(accuracy_rating) as avg_accuracy')
            ->first();

        $counts = UserReview::where('seller_id', $user->id)
            ->selectRaw('rating, COUNT(*) as c')
            ->groupBy('rating')
            ->pluck('c', 'rating');

        $stats = [
            'average' => round((float) ($agg->avg_rating ?? 0), 1),
            'total' => (int) ($agg->total ?? 0),
            'distribution' => [
                5 => (int) ($counts[5] ?? 0),
                4 => (int) ($counts[4] ?? 0),
                3 => (int) ($counts[3] ?? 0),
                2 => (int) ($counts[2] ?? 0),
                1 => (int) ($counts[1] ?? 0),
            ],
            'avg_delivery' => round((float) ($agg->avg_delivery ?? 0), 1),
            'avg_communication' => round((float) ($agg->avg_communication ?? 0), 1),
            'avg_accuracy' => round((float) ($agg->avg_accuracy ?? 0), 1),
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
