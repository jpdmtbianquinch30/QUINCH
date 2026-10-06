<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Concerns\AdminHelpers;
use App\Http\Controllers\Controller;
use App\Models\UserReview;
use App\Services\Admin\AdminLogger;
use App\Services\NotificationService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class AdminReviewController extends Controller
{
    use AdminHelpers;

    public function index(Request $request): JsonResponse
    {
        $query = UserReview::with(['reviewer:id,full_name,username', 'seller:id,full_name,username']);

        if ($search = trim((string) $request->query('search', ''))) {
            $query->where('comment', 'ILIKE', $this->likeTerm($search));
        }
        if ($request->filled('rating')) {
            $query->where('rating', (int) $request->query('rating'));
        }

        return response()->json($query->latest()->paginate($this->perPage($request, 20, 100)));
    }

    public function destroy(Request $request, UserReview $review, NotificationService $notif): JsonResponse
    {
        $validated = $request->validate(['reason' => $this->reasonRules()]);

        AdminLogger::log($request->user(), 'review_removed', 'UserReview', $review->id, [
            'reason' => $validated['reason'], 'reviewer_id' => $review->reviewer_id, 'seller_id' => $review->seller_id,
            'comment' => mb_substr((string) $review->comment, 0, 300),
        ], 'warning');

        $notif->notifyAdmin($review->reviewer_id, 'Votre avis a été retiré', 'Motif : ' . $validated['reason'], null, ['kind' => 'review_removed']);
        $review->delete();

        return response()->json(['message' => 'Avis supprimé.']);
    }
}
