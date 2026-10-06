<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Concerns\AdminHelpers;
use App\Http\Controllers\Controller;
use App\Models\ModerationAppeal;
use App\Models\Product;
use App\Models\ProductReport;
use App\Models\ProductVideo;
use App\Models\SupportTicket;
use App\Models\User;
use App\Models\UserReport;
use App\Services\Admin\AdminLogger;
use App\Services\Admin\ModerationService;
use App\Services\Admin\SanctionService;
use App\Services\Admin\StrikeService;
use App\Services\NotificationService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

class ContentModerationController extends Controller
{
    use AdminHelpers;

    public const REJECTION_REASONS = [
        'prohibited_item'  => 'Article interdit',
        'inappropriate'    => 'Contenu inapproprié',
        'misleading'       => 'Contenu trompeur ou faux',
        'contact_info'     => 'Coordonnées ou lien externe dans la vidéo',
        'copyright'        => 'Contenu volé ou protégé',
        'low_quality'      => 'Qualité insuffisante / illisible',
        'spam'             => 'Spam',
    ];

    public function __construct(
        private ModerationService $moderation,
        private SanctionService $sanctions,
        private StrikeService $strikes,
        private NotificationService $notif
    ) {}

    public function reasons(): JsonResponse
    {
        return response()->json(['reasons' => self::REJECTION_REASONS]);
    }

    // ─── File de post-modération vidéo ───────────────────────────────────

    /**
     * File priorisée : signalements en attente > compte récent > confiance basse
     * > première vidéo du vendeur. (Avant : latest() sans aucune priorité.)
     */
    public function pending(Request $request): JsonResponse
    {
        $status = $request->query('status', 'pending');
        if (!in_array($status, ['pending', 'flagged', 'rejected', 'approved'], true)) {
            $status = 'pending';
        }

        $query = ProductVideo::query()
            ->join('users', 'users.id', '=', 'product_videos.user_id')
            ->select('product_videos.*')
            ->selectRaw("(
                SELECT COUNT(*) FROM product_reports pr
                JOIN products p ON p.id = pr.product_id
                WHERE (p.video_id = product_videos.id OR p.id = product_videos.removed_from_product_id)
                  AND pr.status = 'pending'
            ) AS reports_count")
            ->selectRaw("(
                COALESCE((SELECT COUNT(*) FROM product_reports pr JOIN products p ON p.id = pr.product_id
                          WHERE p.video_id = product_videos.id AND pr.status = 'pending'), 0) * 3
                + CASE WHEN users.created_at > NOW() - INTERVAL '3 days' THEN 2 ELSE 0 END
                + CASE WHEN users.trust_score < 0.4 THEN 2 ELSE 0 END
                + CASE WHEN NOT EXISTS (SELECT 1 FROM product_videos v2 WHERE v2.user_id = product_videos.user_id
                                        AND v2.created_at < product_videos.created_at) THEN 1 ELSE 0 END
            ) AS priority")
            ->where('product_videos.moderation_status', $status)
            ->with([
                'user:id,full_name,username,avatar_url,trust_score,created_at,account_status',
                'product:id,title,slug,video_id,status,user_id,poster_url,images,description,price',
            ]);

        if ($search = trim((string) $request->query('search', ''))) {
            $like = $this->likeTerm($search);
            $query->where(fn ($q) => $q->where('users.full_name', 'ILIKE', $like)->orWhere('users.username', 'ILIKE', $like));
        }

        $page = $query->orderByDesc('priority')->orderBy('product_videos.created_at')
            ->paginate($this->perPage($request, 20, 50));

        // Historique du vendeur (quelques compteurs) pour décider sans changer d'écran.
        $userIds = $page->getCollection()->pluck('user_id')->unique()->all();
        $history = ProductVideo::query()
            ->whereIn('user_id', $userIds)
            ->selectRaw("user_id,
                COUNT(*) FILTER (WHERE moderation_status = 'rejected') AS rejected,
                COUNT(*) FILTER (WHERE moderation_status = 'approved') AS approved,
                COUNT(*) AS total")
            ->groupBy('user_id')->get()->keyBy('user_id');

        $page->getCollection()->transform(function ($video) use ($history) {
            $h = $history[$video->user_id] ?? null;
            $video->preview = $video->adminPreviewUrls();
            $video->seller_history = [
                'videos_total' => (int) ($h->total ?? 0),
                'videos_rejected' => (int) ($h->rejected ?? 0),
                'videos_approved' => (int) ($h->approved ?? 0),
            ];

            return $video;
        });

        return response()->json($page);
    }

    public function moderate(Request $request, ProductVideo $video): JsonResponse
    {
        $validated = $request->validate([
            'status' => ['required', 'in:approved,rejected,flagged'],
            'reason' => ['required_if:status,rejected,flagged', 'nullable', 'string', 'min:3', 'max:500'],
            'action' => ['nullable', 'in:video_only,hide_product'],
            'strike' => ['nullable', 'boolean'],
        ]);

        if ($validated['status'] === 'approved') {
            $this->moderation->approveVideo($video, $request->user(), $validated['reason'] ?? null);
        } else {
            $this->moderation->rejectVideo(
                $video,
                $request->user(),
                $validated['reason'],
                $validated['status'],
                $validated['action'] ?? 'video_only',
                $validated['status'] === 'rejected' && ($validated['strike'] ?? true)
            );
        }

        return response()->json(['message' => 'Vidéo modérée avec succès.', 'video' => $video->fresh()]);
    }

    public function bulkAction(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'video_ids' => ['required', 'array', 'min:1', 'max:100'],
            'video_ids.*' => ['uuid', 'exists:product_videos,id'],
            'action' => ['required', 'in:approved,rejected'],
            'reason' => ['required_if:action,rejected', 'nullable', 'string', 'min:3', 'max:500'],
        ]);

        $done = 0;
        foreach (ProductVideo::whereIn('id', $validated['video_ids'])->get() as $video) {
            if ($validated['action'] === 'approved') {
                $this->moderation->approveVideo($video, $request->user());
            } else {
                $this->moderation->rejectVideo($video, $request->user(), $validated['reason']);
            }
            $done++;
        }

        return response()->json(['message' => "{$done} vidéo(s) modérée(s)."]);
    }

    // ─── Signalements produits ───────────────────────────────────────────

    public function productReports(Request $request): JsonResponse
    {
        $status = $request->query('status', 'pending');
        $query = ProductReport::with([
            'reporter:id,full_name,username,trust_score,false_reports_count',
            'product' => fn ($q) => $q->withTrashed()->select('id', 'title', 'slug', 'user_id', 'status', 'video_id', 'poster_url', 'images', 'deleted_at'),
            'assignee:id,full_name',
        ]);

        if ($status !== 'all') {
            $query->where('status', $status);
        }

        $page = $query->latest()->paginate($this->perPage($request, 20, 50));

        // Regroupement : combien de signalements (et de comptes distincts) pour le même produit.
        $ids = $page->getCollection()->pluck('product_id')->unique()->all();
        $groups = ProductReport::whereIn('product_id', $ids)->where('status', 'pending')
            ->selectRaw('product_id, COUNT(*) AS total, COUNT(DISTINCT reporter_id) AS reporters')
            ->groupBy('product_id')->get()->keyBy('product_id');

        $page->getCollection()->transform(function ($r) use ($groups) {
            $r->group_total = (int) ($groups[$r->product_id]->total ?? 0);
            $r->group_reporters = (int) ($groups[$r->product_id]->reporters ?? 0);

            return $r;
        });

        return response()->json($page);
    }

    /**
     * Traite un signalement ET agit : masquer / supprimer l'annonce, avertir ou
     * suspendre le vendeur. Notifie le signaleur. Option `resolve_all` : clôt
     * tous les signalements en attente du même produit d'un coup.
     */
    public function resolveProductReport(Request $request, ProductReport $report): JsonResponse
    {
        $validated = $request->validate([
            'status' => ['required', 'in:reviewed,resolved,dismissed'],
            'admin_notes' => ['nullable', 'string', 'max:1000'],
            'action' => ['nullable', 'in:none,hide_product,delete_product,warn_seller,suspend_seller'],
            'reason' => ['nullable', 'string', 'min:3', 'max:500'],
            'false_report' => ['nullable', 'boolean'],
            'resolve_all' => ['nullable', 'boolean'],
            'notify_reporter' => ['nullable', 'boolean'],
        ]);

        $admin = $request->user();
        $action = $validated['action'] ?? 'none';
        $reason = $validated['reason'] ?? ($validated['admin_notes'] ?? null);

        if ($action !== 'none' && !$reason) {
            return response()->json(['message' => 'Un motif est obligatoire pour cette action.'], 422);
        }

        $product = Product::withTrashed()->find($report->product_id);
        $seller = $product ? User::find($product->user_id) : null;

        if ($seller && $action === 'suspend_seller') {
            if ($deny = $this->denyIfCannotManage($request, $seller)) {
                return $deny;
            }
            $max = (int) config('permissions.moderator_max_suspension_days', 7);
            if (!$admin->hasPermission('users.suspend') && $max < 7) {
                return response()->json(['message' => 'Suspension non autorisée.'], 403);
            }
        }
        if ($seller && $action === 'warn_seller' && ($deny = $this->denyIfCannotManage($request, $seller))) {
            return $deny;
        }

        DB::transaction(function () use ($report, $validated, $admin, $product, $seller, $action, $reason) {
            if ($product && $action === 'hide_product' && $product->status !== 'disabled') {
                $this->moderation->hideProduct($product, $admin, $reason);
            } elseif ($product && $action === 'delete_product' && !$product->trashed()) {
                $this->moderation->deleteProduct($product, $admin, $reason);
            } elseif ($seller && $action === 'warn_seller') {
                $this->strikes->add($seller, $reason, $admin, $product?->id);
            } elseif ($seller && $action === 'suspend_seller') {
                $this->sanctions->suspend($seller, $reason, 7, $admin);
            }

            $query = $report->newQuery()->where('id', $report->id);
            if (!empty($validated['resolve_all'])) {
                $query = ProductReport::where('product_id', $report->product_id)->where('status', 'pending');
            }

            $affected = $query->get();
            foreach ($affected as $r) {
                $r->update([
                    'status' => $validated['status'],
                    'admin_notes' => $validated['admin_notes'] ?? $r->admin_notes,
                    'reviewed_by' => $admin->id,
                    'action_taken' => $action,
                    'resolved_at' => now(),
                ]);

                if ($validated['status'] === 'dismissed' && !empty($validated['false_report']) && $r->reporter) {
                    $r->reporter->forceFill(['false_reports_count' => $r->reporter->false_reports_count + 1])->save();
                }

                if ($validated['notify_reporter'] ?? true) {
                    $this->notifyReporter($r->reporter_id, $validated['status'], 'votre signalement');
                }
            }

            AdminLogger::log($admin, 'product_report_resolved', 'ProductReport', $report->id, [
                'status' => $validated['status'], 'action' => $action, 'count' => $affected->count(),
                'product_id' => $report->product_id,
            ]);
        });

        return response()->json(['message' => 'Signalement traité.', 'report' => $report->fresh()]);
    }

    // ─── Signalements utilisateurs ───────────────────────────────────────

    public function userReports(Request $request): JsonResponse
    {
        $status = $request->query('status', 'pending');
        $query = UserReport::with([
            'reporter:id,full_name,username,trust_score,false_reports_count',
            'reportedUser:id,full_name,username,account_status,role,trust_score',
            'assignee:id,full_name',
        ]);

        if ($status !== 'all') {
            $query->where('status', $status);
        }

        $page = $query->latest()->paginate($this->perPage($request, 20, 50));

        $ids = $page->getCollection()->pluck('reported_user_id')->unique()->all();
        $groups = UserReport::whereIn('reported_user_id', $ids)->where('status', 'pending')
            ->selectRaw('reported_user_id, COUNT(*) AS total')->groupBy('reported_user_id')->pluck('total', 'reported_user_id');

        $page->getCollection()->transform(function ($r) use ($groups) {
            $r->group_total = (int) ($groups[$r->reported_user_id] ?? 0);

            return $r;
        });

        return response()->json($page);
    }

    public function resolveUserReport(Request $request, UserReport $report): JsonResponse
    {
        $validated = $request->validate([
            'status' => ['required', 'in:reviewed,resolved,dismissed'],
            'admin_notes' => ['nullable', 'string', 'max:1000'],
            'action' => ['nullable', 'in:none,warn,suspend,ban'],
            'duration' => ['nullable', 'integer', 'min:1', 'max:365'],
            'reason' => ['nullable', 'string', 'min:3', 'max:500'],
            'false_report' => ['nullable', 'boolean'],
            'notify_reporter' => ['nullable', 'boolean'],
        ]);

        $admin = $request->user();
        $action = $validated['action'] ?? 'none';
        $reason = $validated['reason'] ?? ($validated['admin_notes'] ?? null);
        $target = User::find($report->reported_user_id);

        if ($action !== 'none') {
            if (!$reason) {
                return response()->json(['message' => 'Un motif est obligatoire pour cette action.'], 422);
            }
            if (!$target) {
                return response()->json(['message' => 'Utilisateur introuvable.'], 404);
            }
            if ($deny = $this->denyIfCannotManage($request, $target)) {
                return $deny;
            }
            if ($action === 'ban' && !$admin->hasPermission('users.ban')) {
                return response()->json(['message' => "Seul un administrateur peut bannir."], 403);
            }
            if ($action === 'suspend') {
                $days = (int) ($validated['duration'] ?? 7);
                if (!$admin->hasPermission('users.suspend') && $days > (int) config('permissions.moderator_max_suspension_days', 7)) {
                    return response()->json(['message' => 'Durée de suspension trop longue pour votre rôle.'], 403);
                }
            }
        }

        DB::transaction(function () use ($report, $validated, $admin, $target, $action, $reason) {
            if ($target) {
                match ($action) {
                    'warn' => $this->strikes->add($target, $reason, $admin),
                    'suspend' => $this->sanctions->suspend($target, $reason, (int) ($validated['duration'] ?? 7), $admin),
                    'ban' => $this->sanctions->ban($target, $reason, $admin),
                    default => null,
                };
            }

            $report->update([
                'status' => $validated['status'],
                'admin_notes' => $validated['admin_notes'] ?? $report->admin_notes,
                'reviewed_by' => $admin->id,
                'action_taken' => $action,
                'resolved_at' => now(),
            ]);

            if ($validated['status'] === 'dismissed' && !empty($validated['false_report']) && $report->reporter) {
                $report->reporter->forceFill(['false_reports_count' => $report->reporter->false_reports_count + 1])->save();
            }

            if ($validated['notify_reporter'] ?? true) {
                $this->notifyReporter($report->reporter_id, $validated['status'], 'votre signalement');
            }

            AdminLogger::log($admin, 'user_report_resolved', 'UserReport', $report->id, [
                'status' => $validated['status'], 'action' => $action, 'reported_user_id' => $report->reported_user_id,
            ]);
        });

        return response()->json(['message' => 'Signalement traité.', 'report' => $report->fresh()]);
    }

    // ─── Tickets support ─────────────────────────────────────────────────

    public function supportTickets(Request $request): JsonResponse
    {
        $status = $request->query('status', 'pending');
        $query = SupportTicket::with(['user:id,full_name,username,phone_number', 'assignee:id,full_name']);

        if ($status !== 'all') {
            $query->where('status', $status);
        }

        return response()->json($query->latest()->paginate($this->perPage($request, 20, 50)));
    }

    public function resolveSupportTicket(Request $request, SupportTicket $ticket): JsonResponse
    {
        $validated = $request->validate([
            'status' => ['required', 'in:reviewed,resolved'],
            'admin_notes' => ['nullable', 'string', 'max:1000'],
            'reply' => ['nullable', 'string', 'max:1000'],
        ]);

        $ticket->update([
            'status' => $validated['status'],
            'admin_notes' => $validated['admin_notes'] ?? $ticket->admin_notes,
            'reviewed_by' => $request->user()->id,
            'resolved_at' => $validated['status'] === 'resolved' ? now() : null,
        ]);

        if (!empty($validated['reply'])) {
            $this->notif->notifyAdmin($ticket->user_id, 'Réponse du support QUINCH', $validated['reply'], null, ['kind' => 'ticket_reply']);
        }

        AdminLogger::log($request->user(), 'support_ticket_resolved', 'SupportTicket', $ticket->id, ['status' => $validated['status']]);

        return response()->json(['message' => 'Ticket traité.', 'ticket' => $ticket->fresh()]);
    }

    /** Assigne un signalement / ticket à un membre du staff (par défaut : soi-même). */
    public function assign(Request $request, string $type, string $id): JsonResponse
    {
        $validated = $request->validate(['assigned_to' => ['nullable', 'uuid', 'exists:users,id']]);

        $model = match ($type) {
            'product-report' => ProductReport::class,
            'user-report' => UserReport::class,
            'ticket' => SupportTicket::class,
            default => null,
        };
        abort_if(!$model, 404);

        $item = $model::findOrFail($id);
        $assigneeId = $validated['assigned_to'] ?? $request->user()->id;

        if ($assigneeId !== $request->user()->id) {
            $assignee = User::find($assigneeId);
            abort_if(!$assignee || !$assignee->isStaff(), 422, 'Le destinataire doit faire partie du staff.');
        }

        $item->update(['assigned_to' => $assigneeId]);
        AdminLogger::log($request->user(), 'report_assigned', class_basename($model), $item->id, ['assigned_to' => $assigneeId]);

        return response()->json(['message' => 'Assigné.', 'assigned_to' => $assigneeId]);
    }

    // ─── Boîte unique « À traiter » ──────────────────────────────────────

    public function inbox(Request $request): JsonResponse
    {
        $type = $request->query('type', 'all');
        $mine = $request->boolean('mine');
        $me = $request->user()->id;
        $limit = 40;

        $counts = [
            'product_reports' => ProductReport::where('status', 'pending')->count(),
            'user_reports' => UserReport::where('status', 'pending')->count(),
            'tickets' => SupportTicket::where('status', 'pending')->count(),
            'disputes' => DB::table('transactions')->where('order_status', 'disputed')->count(),
            'fraud' => DB::table('fraud_detections')->where('status', 'pending_review')->count(),
            'appeals' => ModerationAppeal::pending()->count(),
            'videos' => ProductVideo::whereIn('moderation_status', ['flagged'])->count(),
        ];

        $items = collect();

        if (in_array($type, ['all', 'product_reports'], true)) {
            $q = ProductReport::with(['reporter:id,full_name', 'product' => fn ($p) => $p->withTrashed()->select('id', 'title')])
                ->where('status', 'pending');
            if ($mine) $q->where('assigned_to', $me);
            foreach ($q->latest()->limit($limit)->get() as $r) {
                $items->push([
                    'type' => 'product_report', 'id' => $r->id, 'created_at' => $r->created_at,
                    'title' => 'Annonce signalée : ' . ($r->product->title ?? '—'),
                    'subtitle' => $r->reason . ' — par ' . ($r->reporter->full_name ?? '—'),
                    'priority' => $r->reason === 'fraud' ? 3 : 2, 'assigned_to' => $r->assigned_to,
                    'target_id' => $r->product_id,
                ]);
            }
        }

        if (in_array($type, ['all', 'user_reports'], true)) {
            $q = UserReport::with(['reporter:id,full_name', 'reportedUser:id,full_name'])->where('status', 'pending');
            if ($mine) $q->where('assigned_to', $me);
            foreach ($q->latest()->limit($limit)->get() as $r) {
                $isDispute = str_starts_with((string) $r->description, '[Transaction');
                $items->push([
                    'type' => 'user_report', 'id' => $r->id, 'created_at' => $r->created_at,
                    'title' => ($isDispute ? 'Litige : ' : 'Utilisateur signalé : ') . ($r->reportedUser->full_name ?? '—'),
                    'subtitle' => $r->reason . ' — par ' . ($r->reporter->full_name ?? '—'),
                    'priority' => $isDispute ? 3 : 2, 'assigned_to' => $r->assigned_to,
                    'target_id' => $r->reported_user_id,
                ]);
            }
        }

        if (in_array($type, ['all', 'tickets'], true)) {
            $q = SupportTicket::with('user:id,full_name')->where('status', 'pending');
            if ($mine) $q->where('assigned_to', $me);
            foreach ($q->latest()->limit($limit)->get() as $t) {
                $items->push([
                    'type' => 'ticket', 'id' => $t->id, 'created_at' => $t->created_at,
                    'title' => 'Ticket ' . $t->category . ' — ' . ($t->user->full_name ?? '—'),
                    'subtitle' => mb_substr((string) $t->description, 0, 90),
                    'priority' => $t->category === 'security' ? 3 : 1, 'assigned_to' => $t->assigned_to,
                    'target_id' => $t->user_id,
                ]);
            }
        }

        if (in_array($type, ['all', 'disputes'], true)) {
            foreach (DB::table('transactions')->where('order_status', 'disputed')->latest()->limit($limit)->get(['id', 'amount', 'created_at', 'buyer_id']) as $t) {
                $items->push([
                    'type' => 'dispute', 'id' => $t->id, 'created_at' => $t->created_at,
                    'title' => 'Litige de transaction', 'subtitle' => number_format((float) $t->amount, 0, ',', ' ') . ' F',
                    'priority' => 3, 'assigned_to' => null, 'target_id' => $t->id,
                ]);
            }
        }

        if (in_array($type, ['all', 'fraud'], true)) {
            foreach (DB::table('fraud_detections')->where('status', 'pending_review')->orderByDesc('confidence_score')->limit($limit)->get() as $f) {
                $items->push([
                    'type' => 'fraud', 'id' => (string) $f->id, 'created_at' => $f->created_at,
                    'title' => 'Alerte fraude : ' . $f->detection_type,
                    'subtitle' => 'Confiance ' . round($f->confidence_score * 100) . ' %',
                    'priority' => $f->confidence_score >= 0.8 ? 3 : 2, 'assigned_to' => null, 'target_id' => $f->user_id,
                ]);
            }
        }

        if (in_array($type, ['all', 'appeals'], true)) {
            foreach (ModerationAppeal::with('user:id,full_name')->pending()->latest()->limit($limit)->get() as $a) {
                $items->push([
                    'type' => 'appeal', 'id' => $a->id, 'created_at' => $a->created_at,
                    'title' => 'Contestation de ' . ($a->user->full_name ?? '—'),
                    'subtitle' => mb_substr($a->message, 0, 90), 'priority' => 2, 'assigned_to' => null, 'target_id' => $a->target_id,
                ]);
            }
        }

        $items = $items->sortBy([['priority', 'desc'], ['created_at', 'asc']])->values()->take(100);

        return response()->json(['counts' => $counts, 'total' => array_sum($counts), 'items' => $items]);
    }

    // ─── Contestations ───────────────────────────────────────────────────

    public function appeals(Request $request): JsonResponse
    {
        $status = $request->query('status', 'pending');
        $query = ModerationAppeal::with('user:id,full_name,username,trust_score');
        if ($status !== 'all') {
            $query->where('status', $status);
        }

        $page = $query->latest()->paginate($this->perPage($request, 20, 50));

        $page->getCollection()->transform(function ($a) {
            $a->target = match ($a->target_type) {
                'video' => ProductVideo::select('id', 'moderation_status', 'moderation_reason', 'user_id', 'thumbnail_path', 'video_path')->find($a->target_id),
                'product' => Product::withTrashed()->select('id', 'title', 'status', 'moderation_reason', 'deleted_at')->find($a->target_id),
                'strike' => \App\Models\UserStrike::select('id', 'reason', 'revoked_at', 'expires_at')->find($a->target_id),
                'account' => \App\Models\User::select('id', 'full_name', 'account_status', 'suspension_reason', 'suspended_until')->find($a->target_id),
                default => null,
            };
            $a->concerned_admin = $a->concerned_admin_id
                ? \App\Models\User::select('id', 'full_name')->find($a->concerned_admin_id)
                : null;

            return $a;
        });

        return response()->json($page);
    }

    public function handleAppeal(Request $request, ModerationAppeal $appeal): JsonResponse
    {
        $validated = $request->validate([
            'decision' => ['required', 'in:accepted,rejected'],
            'response' => ['required', 'string', 'min:3', 'max:1000'],
        ]);

        if ($appeal->status !== 'pending') {
            return response()->json(['message' => 'Cette contestation a déjà été traitée.'], 409);
        }

        $admin = $request->user();

        DB::transaction(function () use ($appeal, $validated, $admin) {
            if ($validated['decision'] === 'accepted') {
                if ($appeal->target_type === 'video' && ($video = ProductVideo::find($appeal->target_id))) {
                    $this->moderation->approveVideo($video, $admin, 'Contestation acceptée');
                } elseif ($appeal->target_type === 'product' && ($product = Product::withTrashed()->find($appeal->target_id))) {
                    if ($product->trashed()) {
                        $product->restore();
                    }
                    $this->moderation->restoreProduct($product, $admin, 'Contestation acceptée');
                } elseif ($appeal->target_type === 'strike') {
                    \App\Models\UserStrike::where('id', $appeal->target_id)->whereNull('revoked_at')->update(['revoked_at' => now()]);
                } elseif ($appeal->target_type === 'account') {
                    // Suspension contestée à raison : on la lève (un compte banni ne se réactive pas ici).
                    $target = \App\Models\User::find($appeal->target_id);
                    if ($target && $target->account_status === 'suspended') {
                        app(\App\Services\Admin\SanctionService::class)->lift($target, 'Contestation acceptée', $admin);
                    }
                }
            }

            $appeal->update([
                'status' => $validated['decision'],
                'handled_by' => $admin->id,
                'response' => $validated['response'],
                'handled_at' => now(),
            ]);

            $this->notif->notifyAdmin(
                $appeal->user_id,
                $validated['decision'] === 'accepted' ? 'Contestation acceptée' : 'Contestation refusée',
                $validated['response'],
                null,
                ['kind' => 'appeal_result']
            );

            AdminLogger::log($admin, 'appeal_' . $validated['decision'], 'ModerationAppeal', $appeal->id, [
                'target_type' => $appeal->target_type, 'target_id' => $appeal->target_id,
            ]);
        });

        return response()->json(['message' => 'Contestation traitée.', 'appeal' => $appeal->fresh()]);
    }

    private function notifyReporter(?string $reporterId, string $status, string $what): void
    {
        if (!$reporterId) {
            return;
        }

        $this->notif->notifyAdmin(
            $reporterId,
            'Signalement traité',
            $status === 'dismissed'
                ? "Après examen, {$what} n'a pas donné lieu à une sanction. Merci pour votre vigilance."
                : "Merci : {$what} a été examiné et une suite lui a été donnée.",
            null,
            ['kind' => 'report_processed']
        );
    }
}
