<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\Product;
use App\Models\User;
use App\Models\UserReview;
use App\Services\NotificationService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Database\QueryException;
use Illuminate\Support\Str;

class ReviewController extends Controller
{
    public function __construct(private NotificationService $notif) {}
    public function sellerReviews(Request $request, User $user): JsonResponse
    {
        // ?product_id=… : avis de CE produit uniquement (détail produit / feed vidéo).
        // Sans paramètre : tous les avis du vendeur (profil vendeur).
        $productId = $request->query('product_id');
        if ($productId !== null && !Str::isUuid((string) $productId)) {
            return response()->json(['message' => 'Produit invalide.'], 422);
        }
        $scope = fn ($q) => $q->where('seller_id', $user->id)
            ->when($productId, fn ($w) => $w->where('product_id', $productId));

        $reviews = $scope(UserReview::query())
            ->with('reviewer:id,full_name,username,avatar_url')
            ->orderBy('created_at', 'desc')
            ->paginate(20);

        // Une seule requête d'agrégat. IMPORTANT : avg() renvoie une CHAÎNE avec
        // PostgreSQL ("4.5000000000000000") ; le frontend appelait .toFixed() dessus
        // et plantait (page Avis du profil vendeur). On renvoie de vrais nombres.
        $agg = $scope(UserReview::query())
            ->selectRaw('COUNT(*) as total, AVG(rating) as avg_rating, AVG(delivery_rating) as avg_delivery, AVG(communication_rating) as avg_communication, AVG(accuracy_rating) as avg_accuracy')
            ->first();

        $counts = $scope(UserReview::query())
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
            'product_id' => 'nullable|uuid|exists:products,id',
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

        // Le produit doit appartenir au vendeur évalué.
        if (!empty($validated['product_id'])) {
            $owns = Product::where('id', $validated['product_id'])
                ->where('user_id', $validated['seller_id'])
                ->exists();
            if (!$owns) {
                return response()->json(['message' => 'Ce produit n\'appartient pas à ce vendeur.'], 422);
            }
        }

        // Un avis par personne et par produit (ou par vendeur si aucun produit n'est précisé).
        $existing = UserReview::where('reviewer_id', $request->user()->id)
            ->where('seller_id', $validated['seller_id'])
            ->when(
                !empty($validated['product_id']),
                fn ($q) => $q->where('product_id', $validated['product_id']),
                fn ($q) => $q->whereNull('product_id')
            )
            ->exists();

        if ($existing) {
            return response()->json(['message' => 'Vous avez déjà donné votre avis sur cette annonce.'], 422);
        }

        try {
            $review = UserReview::create([...$validated, 'reviewer_id' => $request->user()->id]);
        } catch (QueryException $e) {
            // Double envoi simultané : l'index unique de la base l'arrête.
            return response()->json(['message' => 'Vous avez déjà donné votre avis sur cette annonce.'], 422);
        }

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
