<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\ModerationAppeal;
use App\Models\NotificationPreference;
use App\Models\Product;
use App\Models\ProductVideo;
use App\Models\User;
use App\Models\UserStrike;
use App\Services\NotificationService;
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
     * Détail complet d'une notification (page « message de l'équipe »).
     * Renvoie aussi l'état de la contestation éventuelle : peut-on contester,
     * existe-t-il déjà une contestation et quelle est la réponse de l'équipe.
     */
    public function show(Request $request, UserNotification $notification): JsonResponse
    {
        if ($notification->user_id !== $request->user()->id) abort(403);

        $contest = $notification->data['contest'] ?? null;
        $appeal = ModerationAppeal::where('notification_id', $notification->id)
            ->where('user_id', $request->user()->id)->latest()->first();

        // Une contestation en cours, acceptée ou refusée clôt le sujet (réponse finale) ;
        // seules les réponses à un simple message peuvent se répéter une fois traitées.
        $canContest = $contest !== null
            && (!$appeal || (($contest['target_type'] ?? null) === 'message' && $appeal->status !== 'pending'));

        return response()->json([
            'notification' => $notification->only([
                'id', 'type', 'title', 'body', 'icon', 'action_url', 'data', 'is_read', 'read_at', 'created_at', 'priority',
            ]),
            'guide_anchor' => $notification->data['guide_anchor'] ?? null,
            'contest' => $contest ? [
                'type' => $contest['target_type'] ?? null,
                'can_contest' => $canContest,
                'appeal' => $appeal ? $appeal->only(['id', 'status', 'message', 'response', 'created_at', 'handled_at']) : null,
            ] : null,
        ]);
    }

    /** Remet une notification en « non lue ». */
    public function markUnread(Request $request, UserNotification $notification): JsonResponse
    {
        if ($notification->user_id !== $request->user()->id) abort(403);

        $notification->update(['is_read' => false, 'read_at' => null]);

        return response()->json(['message' => 'Marquée comme non lue.']);
    }

    /**
     * Contester une décision (avertissement, retrait de vidéo, annonce masquée,
     * suspension…) OU répondre à un message de l'équipe, depuis la notification.
     * La contestation arrive dans la boîte « À traiter » du staff ET prévient
     * directement le membre du staff qui a pris la décision.
     */
    public function contest(Request $request, UserNotification $notification): JsonResponse
    {
        $user = $request->user();
        if ($notification->user_id !== $user->id) abort(403);

        $validated = $request->validate([
            'message' => ['required', 'string', 'min:10', 'max:2000'],
        ], ['message.min' => 'Expliquez votre démarche en au moins 10 caractères.']);

        $contest = $notification->data['contest'] ?? null;
        if (!$contest || empty($contest['target_type']) || empty($contest['target_id'])) {
            return response()->json(['message' => 'Cette décision ne peut pas être contestée.'], 422);
        }

        $type = $contest['target_type'];
        $id = $contest['target_id'];

        // La cible doit appartenir à l'utilisateur et être réellement concernée.
        $ok = match ($type) {
            'video' => ProductVideo::where('id', $id)->where('user_id', $user->id)->whereIn('moderation_status', ['rejected', 'flagged'])->exists(),
            'product' => Product::withTrashed()->where('id', $id)->where('user_id', $user->id)
                ->where(fn ($q) => $q->where('status', 'disabled')->orWhereNotNull('deleted_at'))->exists(),
            'strike' => UserStrike::where('id', $id)->where('user_id', $user->id)->whereNull('revoked_at')->exists(),
            'account' => $id === $user->id,
            'message' => $id === $notification->id,
            default => false,
        };
        if (!$ok) {
            return response()->json(['message' => "Cette décision n'est plus contestable (déjà traitée ou rétablie)."], 422);
        }

        $pending = ModerationAppeal::where('user_id', $user->id)->where('target_type', $type)->where('target_id', $id)
            ->where('status', 'pending')->exists();
        if ($pending) {
            return response()->json(['message' => 'Une contestation est déjà en cours pour cette décision.'], 409);
        }

        $concerned = $notification->data['concerned_admin_id'] ?? null;
        $concerned = $concerned && User::where('id', $concerned)->whereIn('role', ['moderator', 'admin', 'super_admin'])->exists() ? $concerned : null;

        $appeal = ModerationAppeal::create([
            'user_id' => $user->id,
            'target_type' => $type,
            'target_id' => $id,
            'message' => $validated['message'],
            'notification_id' => $notification->id,
            'concerned_admin_id' => $concerned,
        ]);

        // Prévenir l'admin concerné ; à défaut (décision automatique), les super admins.
        $recipients = $concerned
            ? [$concerned]
            : User::where('role', 'super_admin')->where('account_status', 'active')->limit(10)->pluck('id')->all();
        $label = $type === 'message' ? 'Réponse' : 'Contestation';
        foreach ($recipients as $rid) {
            app(NotificationService::class)->notifyAdmin(
                $rid,
                "{$label} de {$user->full_name}",
                mb_substr($validated['message'], 0, 200),
                '/admin/inbox',
                ['kind' => 'appeal_received', 'detail' => 'guide']
            );
        }

        return response()->json(['message' => 'Votre message a été envoyé à l\'équipe. Vous recevrez une réponse ici.', 'appeal' => $appeal], 201);
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
