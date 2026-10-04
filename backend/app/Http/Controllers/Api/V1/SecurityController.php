<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Concerns\AdminHelpers;
use App\Http\Controllers\Controller;
use App\Http\Middleware\CheckBannedIp;
use App\Models\AdminActionLog;
use App\Models\AuditLog;
use App\Models\BannedIp;
use App\Models\FraudDetection;
use App\Services\Admin\AdminLogger;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\StreamedResponse;

class SecurityController extends Controller
{
    use AdminHelpers;

    public function alerts(Request $request): JsonResponse
    {
        return response()->json(
            FraudDetection::with(['user:id,full_name,username,phone_number,trust_score,account_status'])
                ->pendingReview()
                ->orderByDesc('confidence_score')
                ->paginate($this->perPage($request, 20, 50))
        );
    }

    /** Journal technique (AuditLog : changements de données). */
    public function logs(Request $request): JsonResponse
    {
        $query = AuditLog::with('user:id,full_name');

        if ($request->filled('severity')) {
            $query->where('severity', $request->query('severity'));
        }
        if ($request->filled('action_type')) {
            $query->where('action_type', $request->query('action_type'));
        }
        if ($request->filled('entity_type')) {
            $query->where('entity_type', $request->query('entity_type'));
        }
        if ($request->filled('user_id')) {
            $query->where('user_id', $request->query('user_id'));
        }

        return response()->json($query->latest('created_at')->paginate($this->perPage($request, 50, 100)));
    }

    /**
     * Journal des ACTIONS D'ADMINISTRATION (AdminActionLog) : recherche par
     * admin, action, cible et période. Accessible aux admins ; jamais modifiable
     * ni supprimable via l'API.
     */
    public function adminLogs(Request $request): JsonResponse
    {
        return response()->json($this->adminLogQuery($request)->paginate($this->perPage($request, 50, 100)));
    }

    public function exportAdminLogs(Request $request): StreamedResponse
    {
        AdminLogger::log($request->user(), 'audit_exported', null, null, $request->query());
        $query = $this->adminLogQuery($request)->limit(50000);

        return response()->streamDownload(function () use ($query) {
            $out = fopen('php://output', 'w');
            fwrite($out, "\xEF\xBB\xBF");
            fputcsv($out, ['date', 'admin', 'action', 'cible', 'cible_id', 'gravite', 'ip', 'details'], ';');
            $query->chunkById(500, function ($rows) use ($out) {
                foreach ($rows as $l) {
                    fputcsv($out, [
                        $l->created_at, $l->admin->full_name ?? 'Système', $l->action, $l->target_type,
                        $l->target_id, $l->severity, $l->ip_address, json_encode($l->metadata, JSON_UNESCAPED_UNICODE),
                    ], ';');
                }
            }, 'id');
            fclose($out);
        }, 'quinch-audit-' . now()->format('Ymd-His') . '.csv', ['Content-Type' => 'text/csv; charset=UTF-8']);
    }

    public function banIp(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'ip_address' => ['required', 'ip'],
            'reason' => $this->reasonRules(),
            'duration_hours' => ['nullable', 'integer', 'min:1', 'max:8760'],
        ]);

        $ip = $validated['ip_address'];

        // Garde-fous : jamais sa propre IP, jamais une IP privée/réservée (ce serait
        // l'IP du proxy ou du réseau interne : on bannirait tout le monde).
        if ($ip === $request->ip()) {
            return response()->json(['message' => 'Vous ne pouvez pas bannir votre propre adresse IP.'], 422);
        }
        if (!filter_var($ip, FILTER_VALIDATE_IP, FILTER_FLAG_NO_PRIV_RANGE | FILTER_FLAG_NO_RES_RANGE)) {
            return response()->json(['message' => 'Adresse IP privée ou réservée : bannissement refusé.'], 422);
        }

        $expires = !empty($validated['duration_hours']) ? now()->addHours((int) $validated['duration_hours']) : null;

        $ban = BannedIp::updateOrCreate(
            ['ip_address' => $ip],
            ['reason' => $validated['reason'], 'banned_by' => $request->user()->id, 'expires_at' => $expires]
        );
        CheckBannedIp::flush();

        AdminLogger::log($request->user(), 'ip_banned', 'Security', $ban->id, [
            'ip' => $ip, 'reason' => $validated['reason'], 'expires_at' => $expires?->toIso8601String(),
        ], 'critical');

        return response()->json([
            'message' => "IP {$ip} bannie" . ($expires ? " jusqu'au " . $expires->format('d/m/Y H:i') : ' sans limite') . '.',
            'warning' => "Attention : les opérateurs mobiles partagent leurs IP entre des milliers d'abonnés. Préférez une durée courte.",
        ]);
    }

    public function bannedIps(): JsonResponse
    {
        return response()->json(BannedIp::with('bannedBy:id,full_name')->latest()->limit(500)->get());
    }

    public function unbanIp(BannedIp $bannedIp, Request $request): JsonResponse
    {
        AdminLogger::log($request->user(), 'ip_unbanned', 'Security', $bannedIp->id, ['ip' => $bannedIp->ip_address], 'warning');

        $ip = $bannedIp->ip_address;
        $bannedIp->delete();
        CheckBannedIp::flush();

        return response()->json(['message' => "IP {$ip} débannie."]);
    }

    private function adminLogQuery(Request $request)
    {
        $query = AdminActionLog::with('admin:id,full_name,role');

        if ($request->filled('admin_id')) $query->where('admin_id', $request->query('admin_id'));
        if ($request->filled('action')) $query->where('action', 'ILIKE', $this->likeTerm((string) $request->query('action')));
        if ($request->filled('target_type')) $query->where('target_type', $request->query('target_type'));
        if ($request->filled('target_id')) $query->where('target_id', $request->query('target_id'));
        if ($request->filled('severity')) $query->where('severity', $request->query('severity'));
        if ($request->filled('from')) $query->where('created_at', '>=', $request->query('from'));
        if ($request->filled('to')) $query->where('created_at', '<=', $request->query('to') . ' 23:59:59');

        return $query->orderByDesc('created_at');
    }
}
