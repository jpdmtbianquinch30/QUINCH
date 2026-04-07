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
            ['awarded_by' => $request->user()->id, 'reason' => $validated['reason']]
        );

        return response()->json(['badge' => $this->enrichBadge($badge), 'message' => 'Badge attribué.']);
    }

    // Admin: revoke badge
    public function revoke(Request $request, User $user, string $badgeType): JsonResponse
    {
        UserBadge::where('user_id', $user->id)->where('badge_type', $badgeType)->delete();
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
