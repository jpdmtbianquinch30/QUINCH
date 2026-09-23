<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\UserBadge;
use App\Models\User;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class BadgeController extends Controller
{
    public function myBadges(Request $request): JsonResponse
    {
        $badges = UserBadge::where('user_id', $request->user()->id)
            ->orderBy('created_at', 'desc')
            ->get()
            ->map(fn ($b) => $this->enrichBadge($b));

        return response()->json(['badges' => $badges]);
    }

    public function userBadges(User $user): JsonResponse
    {
        $badges = UserBadge::where('user_id', $user->id)
            ->orderBy('created_at', 'desc')
            ->get()
            ->map(fn ($b) => $this->enrichBadge($b));

        return response()->json(['badges' => $badges]);
    }

    public function allBadgeDefinitions(): JsonResponse
    {
        return response()->json(['badges' => UserBadge::badgeDefinitions()]);
    }

    // Admin: award badge
    public function award(Request $request, User $user): JsonResponse
    {
        $validated = $request->validate([
            'badge_type' => 'required|string|max:50',
            'reason' => 'nullable|string|max:500',
        ]);

        $badge = UserBadge::updateOrCreate(
            ['user_id' => $user->id, 'badge_type' => $validated['badge_type']],
            ['awarded_by' => $request->user()->id, 'reason' => $validated['reason'] ?? null]
        );

        return response()->json(['badge' => $this->enrichBadge($badge), 'message' => 'Badge attribué.']);
    }

    // Admin: revoke badge
    public function revoke(Request $request, User $user, string $badgeType): JsonResponse
    {
        UserBadge::where('user_id', $user->id)->where('badge_type', $badgeType)->delete();
        return response()->json(['message' => 'Badge retiré.']);
    }

    /**
     * Vendeur : liste ses clients ayant au moins un achat finalisé chez lui,
     * pour choisir à qui attribuer le badge "Client Fidèle".
     */
    public function myCustomers(Request $request): JsonResponse
    {
        $sellerId = $request->user()->id;

        $customers = \App\Models\Transaction::query()
            ->where('seller_id', $sellerId)
            ->where('payment_status', 'completed')
            ->with('buyer:id,full_name,username,avatar_url')
            ->get()
            ->filter(fn ($t) => $t->buyer !== null)
            ->groupBy('buyer_id')
            ->map(function ($txs) {
                $buyer = $txs->first()->buyer;
                return [
                    'id' => $buyer->id,
                    'full_name' => $buyer->full_name,
                    'username' => $buyer->username,
                    'avatar_url' => $buyer->avatar_url,
                    'orders_count' => $txs->count(),
                    'has_loyal_badge' => UserBadge::where('user_id', $buyer->id)
                        ->where('badge_type', 'loyal_customer')
                        ->exists(),
                ];
            })
            ->values();

        return response()->json(['customers' => $customers]);
    }

    /**
     * Vendeur : attribue le badge "Client Fidèle" à un acheteur ayant
     * réellement acheté chez lui (achat finalisé) — jamais un autre type de
     * badge, réservé à l'admin (voir award() ci-dessus).
     */
    public function sellerAward(Request $request, User $user): JsonResponse
    {
        $seller = $request->user();

        if ($seller->id === $user->id) {
            return response()->json(['message' => 'Vous ne pouvez pas vous attribuer un badge.'], 422);
        }

        $hasBought = \App\Models\Transaction::where('seller_id', $seller->id)
            ->where('buyer_id', $user->id)
            ->where('payment_status', 'completed')
            ->exists();

        if (!$hasBought) {
            return response()->json(['message' => "Ce client n'a jamais acheté chez vous."], 403);
        }

        $validated = $request->validate([
            'reason' => 'nullable|string|max:300',
        ]);

        $badge = UserBadge::updateOrCreate(
            ['user_id' => $user->id, 'badge_type' => 'loyal_customer'],
            ['awarded_by' => $seller->id, 'reason' => $validated['reason'] ?? null]
        );

        return response()->json(['badge' => $this->enrichBadge($badge), 'message' => 'Badge Client Fidèle attribué.']);
    }

    /**
     * Vendeur : retire le badge "Client Fidèle" qu'il a lui-même attribué —
     * jamais celui attribué par un autre vendeur au même client.
     */
    public function sellerRevoke(Request $request, User $user): JsonResponse
    {
        UserBadge::where('user_id', $user->id)
            ->where('badge_type', 'loyal_customer')
            ->where('awarded_by', $request->user()->id)
            ->delete();

        return response()->json(['message' => 'Badge retiré.']);
    }

    private function enrichBadge(UserBadge $badge): array
    {
        $defs = UserBadge::badgeDefinitions();
        $def = $defs[$badge->badge_type] ?? ['name' => $badge->badge_type, 'icon' => 'stars', 'color' => '#666'];

        return [
            'id' => $badge->id,
            'type' => $badge->badge_type,
            'name' => $def['name'],
            'icon' => $def['icon'],
            'color' => $def['color'],
            'level' => $badge->badge_level,
            'reason' => $badge->reason,
            'awarded_at' => $badge->created_at,
            'expires_at' => $badge->expires_at,
        ];
    }
}
