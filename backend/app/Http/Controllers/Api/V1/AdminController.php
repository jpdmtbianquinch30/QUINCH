<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Concerns\AdminHelpers;
use App\Http\Controllers\Controller;
use App\Models\FraudDetection;
use App\Models\Transaction;
use App\Services\Admin\AdminLogger;
use App\Services\Admin\AdminStatsService;
use App\Services\Admin\FraudScanService;
use App\Services\Admin\SanctionService;
use App\Services\Admin\StrikeService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

class AdminController extends Controller
{
    use AdminHelpers;

    public function __construct(
        private AdminStatsService $stats,
        private SanctionService $sanctions,
        private StrikeService $strikes,
        private FraudScanService $fraudScan
    ) {}

    /** Identité + permissions du staff connecté : le front masque ce qui n'est pas permis. */
    public function me(Request $request): JsonResponse
    {
        $user = $request->user();
        $granted = config('permissions.roles')[$user->role] ?? [];
        $permissions = in_array('*', $granted, true) ? config('permissions.all') : $granted;

        return response()->json([
            'user' => [
                'id' => $user->id,
                'full_name' => $user->full_name,
                'username' => $user->username,
                'avatar_url' => $user->avatar_url,
            ],
            'role' => $user->role,
            'level' => $user->roleLevel(),
            'permissions' => array_values($permissions),
            'moderator_max_suspension_days' => (int) config('permissions.moderator_max_suspension_days', 7),
        ]);
    }

    public function metrics(Request $request): JsonResponse
    {
        $metrics = $this->stats->metrics();

        // Un modérateur ne voit pas les chiffres financiers.
        if (!$request->user()->hasPermission('finance.view')) {
            foreach (['revenue', 'total_fees', 'today_volume', 'week_volume', 'month_volume', 'avg_basket'] as $k) {
                $metrics['transactions'][$k] = 0;
            }
        }

        return response()->json($metrics);
    }

    public function realTime(Request $request): JsonResponse
    {
        $data = $this->stats->realTime();

        if (!$request->user()->hasPermission('finance.view')) {
            $data['revenue_today'] = 0;
        }

        return response()->json($data);
    }

    public function transactionReport(Request $request): JsonResponse
    {
        return response()->json($this->stats->transactionReport(AdminStatsService::clampDays($request->get('days'), 30)));
    }

    public function userReport(Request $request): JsonResponse
    {
        return response()->json($this->stats->userReport(AdminStatsService::clampDays($request->get('days'), 30)));
    }

    public function overviewReport(Request $request): JsonResponse
    {
        return response()->json($this->stats->overview(AdminStatsService::clampDays($request->get('days'), 7)));
    }

    public function financeReport(Request $request): JsonResponse
    {
        return response()->json($this->stats->finance(AdminStatsService::clampDays($request->get('days'), 30)));
    }

    // ─── Alertes fraude ──────────────────────────────────────────────────

    public function fraudReport(Request $request): JsonResponse
    {
        $status = $request->get('status', 'pending_review');

        $query = FraudDetection::with(['user:id,full_name,username,phone_number,trust_score,account_status,role', 'reviewer:id,full_name']);

        if ($status !== 'all') {
            $query->where('status', $status);
        }

        return response()->json(
            $query->orderByDesc('confidence_score')->orderByDesc('created_at')->paginate($this->perPage($request, 20, 50))
        );
    }

    /** Lance l'analyse tout de suite (le scheduler la lance déjà toutes les heures). */
    public function runFraudScan(Request $request): JsonResponse
    {
        $created = $this->fraudScan->run();

        AdminLogger::log($request->user(), 'fraud_scan_run', null, null, $created);

        return response()->json([
            'message' => array_sum($created) . ' nouvelle(s) alerte(s) créée(s).',
            'created' => $created,
        ]);
    }

    /** Résout une alerte ET exécute réellement l'action choisie (avant : seul le statut changeait). */
    public function resolveFraud(Request $request, FraudDetection $fraudDetection): JsonResponse
    {
        $validated = $request->validate([
            'status' => ['required', 'in:confirmed,dismissed'],
            'action_taken' => ['required', 'in:none,warning,suspension,ban,payment_hold'],
            'reason' => ['nullable', 'string', 'max:500'],
        ]);

        if ($fraudDetection->status !== 'pending_review') {
            return response()->json(['message' => 'Cette alerte a déjà été traitée.'], 409);
        }

        $admin = $request->user();
        $action = $validated['status'] === 'dismissed' ? 'none' : $validated['action_taken'];
        $target = $fraudDetection->user;
        $reason = $validated['reason'] ?? 'Activité frauduleuse confirmée (' . $fraudDetection->detection_type . ')';

        if ($target && $action !== 'none') {
            if ($deny = $this->denyIfCannotManage($request, $target)) {
                return $deny;
            }
            if ($action === 'ban' && !$admin->hasPermission('users.ban')) {
                return response()->json(['message' => "Vous n'avez pas la permission de bannir."], 403);
            }
            if ($action === 'suspension' && !$admin->hasPermission('users.suspend')) {
                return response()->json(['message' => "Vous n'avez pas la permission de suspendre."], 403);
            }
        }

        DB::transaction(function () use ($fraudDetection, $validated, $action, $admin, $target, $reason) {
            $fraudDetection->update([
                'status' => $validated['status'],
                'action_taken' => $action,
                'reviewed_by' => $admin->id,
                'reviewed_at' => now(),
            ]);

            if (!$target) {
                return;
            }

            switch ($action) {
                case 'warning':
                    $this->strikes->add($target, $reason, $admin);
                    break;
                case 'suspension':
                    $this->sanctions->suspend($target, $reason, 7, $admin);
                    break;
                case 'ban':
                    $this->sanctions->ban($target, $reason, $admin);
                    break;
                case 'payment_hold':
                    Transaction::where('buyer_id', $target->id)
                        ->whereIn('payment_status', ['pending', 'processing'])
                        ->update(['security_check' => 'manual_review']);
                    break;
            }
        });

        AdminLogger::log($admin, 'fraud_case_reviewed', 'FraudDetection', null, [
            'fraud_detection_id' => $fraudDetection->id,
            'user_id' => $target?->id,
            'status' => $validated['status'],
            'action_taken' => $action,
        ], $validated['status'] === 'confirmed' ? 'critical' : 'info');

        return response()->json(['message' => 'Cas de fraude traité.']);
    }
}
