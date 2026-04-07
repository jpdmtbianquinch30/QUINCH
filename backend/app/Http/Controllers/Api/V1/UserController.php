<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\User;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Storage;

class UserController extends Controller
{
    public function profile(Request $request): JsonResponse
    {
        $user = $request->user()->load(['products' => function ($q) {
            $q->active()->latest()->limit(10);
        }]);

        return response()->json([
            'user' => $user,
            'stats' => [
                'products_count' => $user->products()->count(),
                'sales_count' => $user->soldTransactions()->completed()->count(),
                'purchases_count' => $user->purchasedTransactions()->completed()->count(),
                'total_earned' => $user->soldTransactions()->completed()->sum('amount'),
            ],
        ]);
    }

    public function updateProfile(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'username' => ['sometimes', 'string', 'max:50', 'unique:users,username,' . $request->user()->id],
            'full_name' => ['sometimes', 'string', 'max:100'],
            'email' => ['sometimes', 'email', 'unique:users,email,' . $request->user()->id],
            'bio' => ['sometimes', 'nullable', 'string', 'max:500'],
            'city' => ['sometimes', 'string', 'max:100'],
            'region' => ['sometimes', 'string', 'max:100'],
            'is_seller' => ['sometimes', 'boolean'],
            'is_buyer' => ['sometimes', 'boolean'],
            'avatar_url' => ['sometimes', 'string', 'max:500'],
            'cover_url' => ['sometimes', 'string', 'max:500'],
        ]);

        $request->user()->update($validated);

        return response()->json([
            'message' => 'Profil mis à jour.',
            'user' => $request->user()->fresh(),
        ]);
    }

    /**
     * Upload avatar image.
     */
    public function uploadAvatar(Request $request): JsonResponse
    {
        $request->validate([
            'avatar' => ['required', 'image', 'mimes:jpeg,jpg,png,webp', 'max:5120'],
        ]);

        $user = $request->user();

        // Delete old avatar if stored locally (use raw DB value, not the accessor)
        $rawAvatar = $user->getRawOriginal('avatar_url');
        if ($rawAvatar && str_starts_with($rawAvatar, '/storage/')) {
            $oldPath = str_replace('/storage/', '', $rawAvatar);
            Storage::disk('public')->delete($oldPath);
        }

        $path = $request->file('avatar')->store('avatars/' . $user->id, 'public');
        $url = '/storage/' . $path;

        $user->update(['avatar_url' => $url]);

        return response()->json([
            'message' => 'Photo de profil mise à jour.',
            'avatar_url' => url($url),
            'user' => $user->fresh(),
        ]);
    }

    /**
     * Upload cover image.
     */
    public function uploadCover(Request $request): JsonResponse
    {
        $request->validate([
            'cover' => ['required', 'image', 'mimes:jpeg,jpg,png,webp', 'max:10240'],
        ]);

        $user = $request->user();

        // Delete old cover if stored locally (use raw DB value, not the accessor)
        $rawCover = $user->getRawOriginal('cover_url');
        if ($rawCover && str_starts_with($rawCover, '/storage/')) {
            $oldPath = str_replace('/storage/', '', $rawCover);
            Storage::disk('public')->delete($oldPath);
        }

        $path = $request->file('cover')->store('covers/' . $user->id, 'public');
        $url = '/storage/' . $path;

        $user->update(['cover_url' => $url]);

        return response()->json([
            'message' => 'Photo de couverture mise à jour.',
            'cover_url' => url($url),
            'user' => $user->fresh(),
        ]);
    }

    public function savePreferences(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'categories' => ['sometimes', 'array'],
            'location' => ['sometimes', 'array'],
            'location.city' => ['sometimes', 'string'],
            'location.region' => ['sometimes', 'string'],
        ]);

        $user = $request->user();
        $user->update([
            'preferences' => array_merge($user->preferences ?? [], $validated),
            'onboarding_completed' => true,
            'city' => $validated['location']['city'] ?? $user->city,
            'region' => $validated['location']['region'] ?? $user->region,
        ]);

        return response()->json([
            'message' => 'Préférences sauvegardées.',
            'user' => $user->fresh(),
        ]);
    }

    // ─── Blocked Users ───────────────────────────────────────────────────
    public function blockedUsers(Request $request): JsonResponse
    {
        $user = $request->user();
        $blocked = $user->blockedUsers()
            ->select('users.id', 'users.full_name', 'users.avatar_url', 'blocked_users.created_at as blocked_at')
            ->get();

        return response()->json($blocked);
    }

    public function blockUser(Request $request, User $user): JsonResponse
    {
        $currentUser = $request->user();
        if ($currentUser->id === $user->id) {
            return response()->json(['message' => 'Vous ne pouvez pas vous bloquer vous-même.'], 422);
        }

        $currentUser->blockedUsers()->syncWithoutDetaching([$user->id]);

        return response()->json(['message' => 'Utilisateur bloqué.']);
    }

    public function unblockUser(Request $request, User $user): JsonResponse
    {
        $request->user()->blockedUsers()->detach($user->id);

        return response()->json(['message' => 'Utilisateur débloqué.']);
    }

    // ─── Data Export ─────────────────────────────────────────────────────
    public function exportData(Request $request): JsonResponse
    {
        $user = $request->user();

        $data = [
            'profile' => $user->toArray(),
            'products' => $user->products()->get()->toArray(),
            'transactions' => $user->transactions()->get()->toArray(),
            'favorites' => $user->favorites()->with('product:id,title,slug')->get()->toArray(),
            'followers' => $user->followers()->select('users.id', 'users.full_name')->get()->toArray(),
            'following' => $user->following()->select('users.id', 'users.full_name')->get()->toArray(),
            'exported_at' => now()->toIso8601String(),
        ];

        return response()->json($data);
    }

    // ─── Report Problem ──────────────────────────────────────────────────
    public function reportProblem(Request $request): JsonResponse
    {
        $request->validate([
            'category' => ['required', 'string', 'in:bug,suggestion,security,other'],
            'description' => ['required', 'string', 'max:2000'],
        ]);

        // Store the support ticket (could be a dedicated model, for now log it)
        \Log::info('Support report from user ' . $request->user()->id, [
            'category' => $request->category,
            'description' => $request->description,
        ]);

        return response()->json(['message' => 'Signalement reçu. Merci pour votre retour.']);
    }

    // ─── Report User ─────────────────────────────────────────────────────
    public function reportUser(Request $request, User $user): JsonResponse
    {
        $currentUser = $request->user();

        if ($currentUser->id === $user->id) {
            return response()->json(['message' => 'Vous ne pouvez pas vous signaler vous-même.'], 422);
        }

        $request->validate([
            'reason' => ['required', 'string', 'in:harassment,spam,inappropriate_content,fraud,impersonation,other'],
            'description' => ['nullable', 'string', 'max:2000'],
        ]);

        // Check for existing pending report from same user
        $existing = \App\Models\UserReport::where('reporter_id', $currentUser->id)
            ->where('reported_user_id', $user->id)
            ->where('status', 'pending')
            ->exists();

        if ($existing) {
            return response()->json(['message' => 'Vous avez déjà signalé cet utilisateur. Le signalement est en cours de traitement.'], 409);
        }

        \App\Models\UserReport::create([
            'reporter_id' => $currentUser->id,
            'reported_user_id' => $user->id,
            'reason' => $request->reason,
            'description' => $request->description,
        ]);

        return response()->json(['message' => 'Signalement envoyé. Notre équipe va examiner ce profil.']);
    }
}
