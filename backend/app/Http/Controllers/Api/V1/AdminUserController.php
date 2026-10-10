<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Concerns\AdminHelpers;
use App\Http\Controllers\Controller;
use App\Models\AdminActionLog;
use App\Models\AuditLog;
use App\Models\Product;
use App\Models\ProductReport;
use App\Models\Transaction;
use App\Models\User;
use App\Models\UserReport;
use App\Services\Admin\AdminLogger;
use App\Services\Admin\SanctionService;
use App\Services\Admin\StrikeService;
use App\Services\NotificationService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class AdminUserController extends Controller
{
    use AdminHelpers;

    public function __construct(
        private NotificationService $notif,
        private SanctionService $sanctions,
        private StrikeService $strikes
    ) {}

    public function index(Request $request): JsonResponse
    {
        $query = User::query();

        if (!$request->boolean('include_deleted')) {
            $query->whereNull('anonymized_at');
        }

        if ($search = trim((string) $request->query('search', ''))) {
            // ILIKE + échappement : la recherche est insensible à la casse
            // (avant : LIKE sensible à la casse sous Postgres, % et _ non échappés).
            $this->ilike($query, ['full_name', 'phone_number', 'username', 'email'], $search, ['id']);
        }

        if ($status = $request->query('status')) {
            $query->where('account_status', $status);
        }

        if ($role = $request->query('role')) {
            $query->where('role', $role);
        }

        if ($kyc = $request->query('kyc')) {
            $query->where('kyc_status', $kyc);
        }

        if ($request->query('premium') === '1') {
            $query->where('is_premium', true)->where('premium_expires_at', '>', now());
        }

        if ($request->filled('trust_min')) {
            $query->where('trust_score', '>=', (float) $request->query('trust_min'));
        }

        if ($request->filled('trust_max')) {
            $query->where('trust_score', '<=', (float) $request->query('trust_max'));
        }

        $sort = $request->query('sort', 'created_at');
        $dir = $request->query('dir', 'desc') === 'asc' ? 'asc' : 'desc';
        if (in_array($sort, ['created_at', 'trust_score', 'full_name', 'last_seen_at'], true)) {
            $query->orderBy($sort, $dir);
        }

        $users = $query
            ->withCount([
                'products',
                'purchasedTransactions',
                'soldTransactions',
                'strikes as active_strikes_count' => fn ($q) => $q->active(),
            ])
            ->with('badges:id,user_id,badge_type')
            ->paginate($this->perPage($request, 20, 100));

        return response()->json($users);
    }

    public function show(Request $request, User $user): JsonResponse
    {
        $user->loadCount(['products', 'purchasedTransactions', 'soldTransactions']);
        $user->load('badges');

        $fingerprint = $user->device_fingerprint;
        $sharedQuery = $fingerprint
            ? User::where('device_fingerprint', $fingerprint)->where('id', '!=', $user->id)
            : null;

        return response()->json([
            'user' => $user,
            'can_manage' => $request->user()->canManage($user),
            'is_self_super' => $request->user()->id === $user->id && $request->user()->role === 'super_admin',
            'active_strikes' => $this->strikes->activeCount($user),
            'strikes' => $user->strikes()->with('issuer:id,full_name')->latest()->limit(20)->get(),
            'recent_activity' => AuditLog::forUser($user->id)->recent(30)->latest('created_at')->limit(20)->get(),
            'admin_actions' => AdminActionLog::where('target_id', $user->id)
                ->where('target_type', 'User')
                ->with('admin:id,full_name')
                ->latest()
                ->limit(30)
                ->get(),
            'products' => Product::withTrashed()
                ->where('user_id', $user->id)
                ->latest()
                ->limit(10)
                ->get(['id', 'title', 'slug', 'status', 'price', 'moderation_reason', 'created_at', 'deleted_at']),
            'transactions' => Transaction::where(fn ($q) => $q->where('buyer_id', $user->id)->orWhere('seller_id', $user->id))
                ->latest()
                ->limit(10)
                ->get(['id', 'buyer_id', 'seller_id', 'product_id', 'amount', 'payment_status', 'order_status', 'created_at']),
            'reports_received' => UserReport::where('reported_user_id', $user->id)
                ->with('reporter:id,full_name,username')->latest()->limit(10)->get(),
            'reports_made' => UserReport::where('reporter_id', $user->id)->latest()->limit(10)->get(),
            'product_reports_received' => ProductReport::whereHas('product', fn ($q) => $q->where('user_id', $user->id))
                ->latest()->limit(10)->get(['id', 'product_id', 'reason', 'status', 'created_at']),
            'shared_device_count' => $sharedQuery ? (clone $sharedQuery)->count() : 0,
            'shared_device_accounts' => $sharedQuery
                ? (clone $sharedQuery)->limit(5)->get(['id', 'full_name', 'username', 'account_status'])
                : [],
        ]);
    }

    public function suspend(Request $request, User $user): JsonResponse
    {
        $validated = $request->validate([
            'reason' => $this->reasonRules(),
            'duration' => ['nullable', 'integer', 'min:1', 'max:365'],
        ]);

        if ($deny = $this->denyIfCannotManage($request, $user)) {
            return $deny;
        }

        if ($user->account_status === 'banned') {
            return response()->json(['message' => 'Ce compte est déjà banni.'], 422);
        }

        $actor = $request->user();
        $days = !empty($validated['duration']) ? (int) $validated['duration'] : null;

        // Un modérateur ne peut suspendre que pour une durée limitée (7 j par défaut).
        if (!$actor->hasPermission('users.suspend')) {
            $max = (int) config('permissions.moderator_max_suspension_days', 7);
            if ($days === null || $days > $max) {
                return response()->json([
                    'message' => "Un modérateur ne peut suspendre que {$max} jours maximum.",
                    'error' => 'suspension_too_long',
                ], 403);
            }
        }

        $this->sanctions->suspend($user, $validated['reason'], $days, $actor);

        return response()->json(['message' => 'Utilisateur suspendu.', 'user' => $user->fresh()]);
    }

    /** Lève une suspension. Un compte BANNI ne se réactive pas ici (voir unban). */
    public function activate(Request $request, User $user): JsonResponse
    {
        $validated = $request->validate(['reason' => ['nullable', 'string', 'max:500']]);

        if ($deny = $this->denyIfCannotManage($request, $user)) {
            return $deny;
        }

        if ($user->account_status === 'banned') {
            return response()->json([
                'message' => 'Ce compte est banni : utilisez « Débannir » (avec un motif).',
                'error' => 'account_banned',
            ], 422);
        }

        if (!$this->sanctions->lift($user, $validated['reason'] ?? 'Levée manuelle', $request->user())) {
            return response()->json(['message' => "Ce compte n'est pas suspendu."], 422);
        }

        return response()->json(['message' => 'Utilisateur réactivé.', 'user' => $user->fresh()]);
    }

    public function ban(Request $request, User $user): JsonResponse
    {
        $validated = $request->validate(['reason' => $this->reasonRules()]);

        if ($deny = $this->denyIfCannotManage($request, $user)) {
            return $deny;
        }

        $this->sanctions->ban($user, $validated['reason'], $request->user());

        return response()->json(['message' => 'Utilisateur banni définitivement.', 'user' => $user->fresh()]);
    }

    public function unban(Request $request, User $user): JsonResponse
    {
        $validated = $request->validate(['reason' => $this->reasonRules()]);

        if ($deny = $this->denyIfCannotManage($request, $user)) {
            return $deny;
        }

        if (!$this->sanctions->unban($user, $validated['reason'], $request->user())) {
            return response()->json(['message' => "Ce compte n'est pas banni."], 422);
        }

        return response()->json(['message' => 'Utilisateur débanni.', 'user' => $user->fresh()]);
    }

    /** Avertissement manuel (compte dans le décompte des strikes). */
    public function warn(Request $request, User $user): JsonResponse
    {
        $validated = $request->validate(['reason' => $this->reasonRules()]);

        if ($deny = $this->denyIfCannotManage($request, $user)) {
            return $deny;
        }

        $strike = $this->strikes->add($user, $validated['reason'], $request->user());

        return response()->json([
            'message' => 'Avertissement envoyé.',
            'strike' => $strike,
            'active_strikes' => $this->strikes->activeCount($user),
            'user' => $user->fresh(),
        ]);
    }

    public function revokeStrike(Request $request, User $user, string $strike): JsonResponse
    {
        if ($deny = $this->denyIfCannotManage($request, $user)) {
            return $deny;
        }

        $row = $user->strikes()->whereKey($strike)->first();
        if (!$row) {
            return response()->json(['message' => 'Avertissement introuvable.'], 404);
        }

        $row->update(['revoked_at' => now()]);

        AdminLogger::log($request->user(), 'strike_revoked', 'User', $user->id, ['strike_id' => $row->id]);

        return response()->json(['message' => 'Avertissement retiré.', 'active_strikes' => $this->strikes->activeCount($user)]);
    }

    public function verifyKyc(Request $request, User $user): JsonResponse
    {
        $validated = $request->validate([
            'status' => ['required', 'in:verified,rejected'],
            'reason' => ['nullable', 'string', 'max:500'],
        ]);

        if ($deny = $this->denyIfCannotManage($request, $user)) {
            return $deny;
        }

        $user->forceFill(['kyc_status' => $validated['status']])->save();

        if ($validated['status'] === 'verified') {
            $user->incrementTrustScore(0.2);
        }

        AdminLogger::log($request->user(), 'kyc_' . $validated['status'], 'User', $user->id, ['reason' => $validated['reason'] ?? null]);

        $this->notif->notifyAdmin(
            $user->id,
            $validated['status'] === 'verified' ? 'KYC Vérifié' : 'KYC Rejeté',
            $validated['status'] === 'verified'
                ? 'Votre identité a été vérifiée avec succès.'
                : 'Votre vérification KYC a été rejetée. ' . ($validated['reason'] ?? ''),
            null,
            ['kind' => 'kyc']
        );

        return response()->json(['message' => 'Statut KYC mis à jour.', 'user' => $user->fresh()]);
    }

    public function adjustTrust(Request $request, User $user): JsonResponse
    {
        $validated = $request->validate([
            'score' => ['required', 'numeric', 'min:0', 'max:1'],
            'reason' => $this->reasonRules(),
        ]);

        // Le super admin peut régler le score de son propre compte ; personne d'autre.
        $selfAsSuperAdmin = $request->user()->id === $user->id && $request->user()->role === 'super_admin';

        if (!$selfAsSuperAdmin && ($deny = $this->denyIfCannotManage($request, $user))) {
            return $deny;
        }

        $old = $user->trust_score;
        $user->forceFill(['trust_score' => $validated['score']])->save();

        AdminLogger::log($request->user(), 'trust_score_adjusted', 'User', $user->id, [
            'old_score' => $old, 'new_score' => (float) $validated['score'], 'reason' => $validated['reason'],
        ], 'warning');

        return response()->json(['message' => 'Score de confiance ajusté.', 'user' => $user->fresh()]);
    }

    public function sendNotification(Request $request, User $user): JsonResponse
    {
        $validated = $request->validate([
            'title' => ['required', 'string', 'max:200'],
            'body' => ['required', 'string', 'max:1000'],
            'action_url' => ['nullable', 'string', 'max:300', 'regex:/^\/(?![\/\\])/'],
            // Autorise l'utilisateur à répondre / contester depuis la page du message.
            'allow_reply' => ['nullable', 'boolean'],
            'guide_anchor' => ['nullable', 'string', 'max:60', 'regex:/^[a-z0-9-]+$/'],
        ]);

        $meta = ['kind' => 'team_message', 'concerned_admin_id' => $request->user()->id];
        if (!empty($validated['guide_anchor'])) {
            $meta['guide_anchor'] = $validated['guide_anchor'];
        }
        $notification = $this->notif->notifyAdmin($user->id, $validated['title'], $validated['body'], $validated['action_url'] ?? null, $meta);
        if ($notification && !empty($validated['allow_reply'])) {
            $data = $notification->data ?? [];
            $data['contest'] = ['target_type' => 'message', 'target_id' => $notification->id];
            $notification->update(['data' => $data]);
        }

        AdminLogger::log($request->user(), 'notification_sent', 'User', $user->id, ['title' => $validated['title']]);

        return response()->json(['message' => 'Notification envoyée.']);
    }

    /**
     * « Suppression » = anonymisation. Avant : plantait en 500 dès que le compte
     * avait une transaction (clé étrangère), et ignorait la raison envoyée.
     */
    public function destroy(Request $request, User $user): JsonResponse
    {
        $validated = $request->validate(['reason' => $this->reasonRules()]);

        if ($deny = $this->denyIfCannotManage($request, $user)) {
            return $deny;
        }

        if ($user->anonymized_at) {
            return response()->json(['message' => 'Ce compte est déjà supprimé.'], 422);
        }

        $this->sanctions->anonymize($user, $validated['reason'], $request->user());

        return response()->json(['message' => 'Compte supprimé (données personnelles anonymisées).']);
    }

    /** Export RGPD : toutes les données liées au compte, en JSON téléchargeable. */
    public function export(Request $request, User $user): JsonResponse
    {
        $payload = [
            'exported_at' => now()->toIso8601String(),
            'user' => $user->makeVisible(['kyc_data'])->toArray(),
            'products' => Product::withTrashed()->where('user_id', $user->id)->get()->toArray(),
            'transactions' => Transaction::where('buyer_id', $user->id)->orWhere('seller_id', $user->id)->get()->toArray(),
            'reports_made' => UserReport::where('reporter_id', $user->id)->get()->toArray(),
            'reports_received' => UserReport::where('reported_user_id', $user->id)->get()->toArray(),
            'strikes' => $user->strikes()->get()->toArray(),
        ];

        AdminLogger::log($request->user(), 'user_data_exported', 'User', $user->id, [], 'warning');

        return response()->json($payload)
            ->header('Content-Disposition', 'attachment; filename="quinch-user-' . $user->id . '.json"');
    }
}
