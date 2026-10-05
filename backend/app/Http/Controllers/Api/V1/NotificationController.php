<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\NotificationPreference;
use App\Models\UserNotification;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class NotificationController extends Controller
{
    /**
     * Get paginated notifications with optional tab filtering.
     * Tabs: all, interactions, messages, system
     */
    public function index(Request $request): JsonResponse
    {
        $userId = $request->user()->id;
        $tab = $request->query('tab', 'all');

        $notifications = UserNotification::where('user_id', $userId)
            ->forTab($tab)
            ->with('sender:id,full_name,avatar_url,username,is_premium,premium_expires_at')
            ->orderBy('created_at', 'desc')
            ->paginate(30);

        // Badges + statut premium de l'expéditeur (une seule requête pour la page).
        $senderIds = $notifications->getCollection()->pluck('sender_id')->filter()->unique()->values()->all();
        if ($senderIds) {
            $badges = \App\Models\UserBadge::summaryForMany($senderIds);
            foreach ($notifications->getCollection() as $n) {
                if ($n->sender) {
                    $n->sender->setAttribute('badges', $badges[$n->sender->id] ?? []);
                    $n->sender->setAttribute('is_premium', $n->sender->isPremiumActive());
                }
            }
        }

        // Also return tab counts
        $counts = [
            'all'          => UserNotification::where('user_id', $userId)->unread()->count(),
            'interactions' => UserNotification::where('user_id', $userId)->forTab('interactions')->unread()->count(),
            'messages'     => UserNotification::where('user_id', $userId)->forTab('messages')->unread()->count(),
            'system'       => UserNotification::where('user_id', $userId)->forTab('system')->unread()->count(),
        ];

        return response()->json([
            'data' => $notifications->items(),
            'meta' => [
                'current_page' => $notifications->currentPage(),
                'last_page'    => $notifications->lastPage(),
                'total'        => $notifications->total(),
            ],
            'counts' => $counts,
        ]);
    }

    /**
     * Get unread count (overall + per tab).
     */
    public function unreadCount(Request $request): JsonResponse
    {
        $userId = $request->user()->id;

        return response()->json([
            'count' => UserNotification::where('user_id', $userId)->unread()->count(),
            'tabs' => [
                'interactions' => UserNotification::where('user_id', $userId)->forTab('interactions')->unread()->count(),
                'messages'     => UserNotification::where('user_id', $userId)->forTab('messages')->unread()->count(),
                'system'       => UserNotification::where('user_id', $userId)->forTab('system')->unread()->count(),
            ],
        ]);
    }

    /**
     * Annonces à afficher en haut du feed dès l'arrivée de l'utilisateur :
     * message de bienvenue (objectif 80 % de confiance), messages de l'équipe
     * (corrections effectuées, informations…). Non lues uniquement, 30 jours max.
     */
    public function announcements(Request $request): JsonResponse
    {
        $items = UserNotification::where('user_id', $request->user()->id)
            ->whereIn('type', ['admin', 'admin_message', 'welcome'])
            ->unread()
            ->where('created_at', '>=', now()->subDays(30))
            ->orderByRaw("CASE WHEN type = 'welcome' THEN 0 ELSE 1 END")
            ->orderByDesc('created_at')
            ->limit(3)
            ->get(['id', 'type', 'title', 'body', 'icon', 'action_url', 'data', 'created_at']);

        return response()->json(['data' => $items]);
    }

    /**
     * Mark a single notification as read.
     */
    public function markRead(Request $request, UserNotification $notification): JsonResponse
    {
        if ($notification->user_id !== $request->user()->id) abort(403);

        $notification->update(['is_read' => true, 'read_at' => now()]);
        return response()->json(['message' => 'Notification lue.']);
    }

    /**
     * Mark all notifications as read (optionally by tab).
     */
    public function markAllRead(Request $request): JsonResponse
    {
        $userId = $request->user()->id;
        $tab = $request->query('tab', 'all');

        UserNotification::where('user_id', $userId)
            ->forTab($tab)
            ->unread()
            ->update(['is_read' => true, 'read_at' => now()]);

        return response()->json(['message' => 'Toutes les notifications marquées comme lues.']);
    }

    /**
     * Delete a notification.
     */
    public function destroy(Request $request, UserNotification $notification): JsonResponse
    {
        if ($notification->user_id !== $request->user()->id) abort(403);

        $notification->delete();
        return response()->json(['message' => 'Notification supprimée.']);
    }

    // ─── Notification Preferences ────────────────────────────────────────

    /**
     * Get user's notification preferences.
     */
    public function getPreferences(Request $request): JsonResponse
    {
        $userId = $request->user()->id;
        $defaults = NotificationPreference::defaultTypes();
        $labels = NotificationPreference::typeLabels();
        $saved = NotificationPreference::where('user_id', $userId)->get()->keyBy('type');

        $preferences = [];
        foreach ($defaults as $type => $defaultSettings) {
            $pref = $saved->get($type);
            $preferences[] = [
                'type'         => $type,
                'label'        => $labels[$type] ?? $type,
                'push_enabled' => $pref ? $pref->push_enabled : $defaultSettings['push'],
                'in_app_enabled' => $pref ? $pref->in_app_enabled : $defaultSettings['in_app'],
                'email_enabled' => $pref ? $pref->email_enabled : $defaultSettings['email'],
            ];
        }

        return response()->json(['preferences' => $preferences]);
    }

    /**
     * Update user's notification preferences.
     */
    public function updatePreferences(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'preferences' => 'required|array',
            'preferences.*.type' => 'required|string',
            'preferences.*.push_enabled' => 'sometimes|boolean',
            'preferences.*.in_app_enabled' => 'sometimes|boolean',
            'preferences.*.email_enabled' => 'sometimes|boolean',
        ]);

        $userId = $request->user()->id;

        foreach ($validated['preferences'] as $pref) {
            NotificationPreference::updateOrCreate(
                ['user_id' => $userId, 'type' => $pref['type']],
                [
                    'push_enabled'   => $pref['push_enabled'] ?? true,
                    'in_app_enabled' => $pref['in_app_enabled'] ?? true,
                    'email_enabled'  => $pref['email_enabled'] ?? false,
                ]
            );
        }

        return response()->json(['message' => 'Préférences mises à jour.']);
    }
}
