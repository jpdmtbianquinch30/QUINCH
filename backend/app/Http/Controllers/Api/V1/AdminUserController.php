<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\AdminActionLog;
use App\Models\AuditLog;
use App\Models\User;
use App\Services\NotificationService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class AdminUserController extends Controller
{
    public function __construct(private NotificationService $notif) {}
    public function index(Request $request): JsonResponse
    {
        $query = User::query();

        if ($request->has('search') && $request->search) {
            $search = $request->search;
            $query->where(function ($q) use ($search) {
                $q->where('full_name', 'LIKE', "%{$search}%")
                  ->orWhere('phone_number', 'LIKE', "%{$search}%")
                  ->orWhere('username', 'LIKE', "%{$search}%")
                  ->orWhere('email', 'LIKE', "%{$search}%");
            });
        }

        if ($request->has('status') && $request->status) {
            $query->where('account_status', $request->status);
        }

        if ($request->has('role') && $request->role) {
            $query->where('role', $request->role);
        }

        if ($request->has('kyc') && $request->kyc) {
            $query->where('kyc_status', $request->kyc);
        }

        if ($request->has('trust_min')) {
            $query->where('trust_score', '>=', $request->trust_min);
        }

        if ($request->has('trust_max')) {
            $query->where('trust_score', '<=', $request->trust_max);
        }

        $sort = $request->get('sort', 'created_at');
        $dir = $request->get('dir', 'desc');
        $allowedSorts = ['created_at', 'trust_score', 'full_name'];
        if (in_array($sort, $allowedSorts)) {
            $query->orderBy($sort, $dir === 'asc' ? 'asc' : 'desc');
        }

        $users = $query->withCount(['products', 'purchasedTransactions', 'soldTransactions'])
            ->with('badges:id,user_id,badge_type')
            ->paginate($request->get('per_page', 20));

        return response()->json($users);
    }

    public function show(User $user): JsonResponse
    {
        $user->loadCount(['products', 'purchasedTransactions', 'soldTransactions']);
        $user->load('badges');

        $recentActivity = AuditLog::forUser($user->id)->recent(30)->latest('created_at')->limit(20)->get();
        $adminActions = AdminActionLog::where('target_id', $user->id)
            ->where('target_type', 'User')
            ->with('admin:id,full_name')
            ->latest()
            ->limit(10)
            ->get();

        return response()->json([
            'user' => $user,
            'recent_activity' => $recentActivity,
            'admin_actions' => $adminActions,
        ]);
    }

    public function suspend(Request $request, User $user): JsonResponse
    {
        $request->validate([
            'reason' => ['required', 'string', 'max:500'],
            'duration' => ['nullable', 'integer', 'min:1', 'max:365'],
        ]);

        $user->update(['account_status' => 'suspended']);
        $user->tokens()->delete();

        AdminActionLog::create([
            'admin_id' => $request->user()->id,
            'action' => 'user_suspended',
            'target_type' => 'User',
            'target_id' => $user->id,
            'metadata' => ['reason' => $request->reason, 'duration' => $request->duration],
            'ip_address' => $request->ip(),
            'severity' => 'warning',
        ]);

        $this->notif->notifyAdmin($user->id, 'Compte suspendu', 'Votre compte a été suspendu. Raison: ' . $request->reason);

        return response()->json(['message' => 'Utilisateur suspendu.']);
    }

    public function activate(Request $request, User $user): JsonResponse
    {
        $user->update(['account_status' => 'active']);

        AdminActionLog::create([
            'admin_id' => $request->user()->id,
            'action' => 'user_activated',
            'target_type' => 'User',
            'target_id' => $user->id,
            'ip_address' => $request->ip(),
            'severity' => 'info',
        ]);

        $this->notif->notifyAdmin($user->id, 'Compte réactivé', 'Votre compte a été réactivé.');

        return response()->json(['message' => 'Utilisateur réactivé.']);
    }

    public function verifyKyc(Request $request, User $user): JsonResponse
    {
        $request->validate([
            'status' => ['required', 'in:verified,rejected'],
            'reason' => ['nullable', 'string', 'max:500'],
        ]);

        $user->update(['kyc_status' => $request->status]);

        if ($request->status === 'verified') {
            $user->incrementTrustScore(0.2);
        }

        AdminActionLog::create([
            'admin_id' => $request->user()->id,
            'action' => 'kyc_' . $request->status,
            'target_type' => 'User',
            'target_id' => $user->id,
            'metadata' => ['reason' => $request->reason],
            'ip_address' => $request->ip(),
            'severity' => 'info',
        ]);

        $this->notif->notifyAdmin(
            $user->id,
            $request->status === 'verified' ? 'KYC Vérifié' : 'KYC Rejeté',
            $request->status === 'verified'
                ? 'Votre identité a été vérifiée avec succès.'
                : 'Votre vérification KYC a été rejetée. ' . ($request->reason ?? ''),
            '/profile'
        );

        return response()->json(['message' => 'Statut KYC mis à jour.', 'user' => $user->fresh()]);
    }

    public function adjustTrust(Request $request, User $user): JsonResponse
    {
        $request->validate([
            'score' => ['required', 'numeric', 'min:0', 'max:1'],
            'reason' => ['required', 'string', 'max:500'],
        ]);

        $oldScore = $user->trust_score;
        $user->update(['trust_score' => $request->score]);

        AdminActionLog::create([
            'admin_id' => $request->user()->id,
            'action' => 'trust_score_adjusted',
            'target_type' => 'User',
            'target_id' => $user->id,
            'metadata' => ['old_score' => $oldScore, 'new_score' => $request->score, 'reason' => $request->reason],
            'ip_address' => $request->ip(),
            'severity' => 'warning',
        ]);

        return response()->json(['message' => 'Score de confiance ajusté.', 'user' => $user->fresh()]);
    }

    public function sendNotification(Request $request, User $user): JsonResponse
    {
        $request->validate([
            'title' => ['required', 'string', 'max:200'],
            'body' => ['required', 'string', 'max:1000'],
        ]);

        $this->notif->notifyAdmin($user->id, $request->title, $request->body);

        AdminActionLog::create([
            'admin_id' => $request->user()->id,
            'action' => 'notification_sent',
            'target_type' => 'User',
            'target_id' => $user->id,
            'metadata' => ['title' => $request->title],
            'ip_address' => $request->ip(),
            'severity' => 'info',
        ]);

        return response()->json(['message' => 'Notification envoyée.']);
    }

    public function destroy(Request $request, User $user): JsonResponse
    {
        if ($user->role === 'super_admin') {
            return response()->json(['message' => 'Impossible de supprimer un super administrateur.'], 403);
        }

        // Revoke tokens
        $user->tokens()->delete();

        AdminActionLog::create([
            'admin_id' => $request->user()->id,
            'action' => 'user_deleted',
            'target_type' => 'User',
            'target_id' => $user->id,
            'metadata' => ['full_name' => $user->full_name, 'email' => $user->email],
            'ip_address' => $request->ip(),
            'severity' => 'critical',
        ]);

        $user->delete();

        return response()->json(['message' => 'Utilisateur supprimé.']);
    }

    public function ban(Request $request, User $user): JsonResponse
    {
        $request->validate([
            'reason' => ['required', 'string', 'max:500'],
        ]);

        if ($user->role === 'super_admin') {
            return response()->json(['message' => 'Impossible de bannir un super administrateur.'], 403);
        }

        // Revoke tokens and ban
        $user->tokens()->delete();
        $user->update([
            'status' => 'banned',
            'ban_reason' => $request->reason,
            'banned_at' => now(),
        ]);

        AdminActionLog::create([
            'admin_id' => $request->user()->id,
            'action' => 'user_banned',
            'target_type' => 'User',
            'target_id' => $user->id,
            'metadata' => ['reason' => $request->reason],
            'ip_address' => $request->ip(),
            'severity' => 'critical',
        ]);

        return response()->json(['message' => 'Utilisateur banni définitivement.']);
    }
}
