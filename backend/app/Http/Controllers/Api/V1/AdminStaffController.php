<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Concerns\AdminHelpers;
use App\Http\Controllers\Controller;
use App\Models\AdminActionLog;
use App\Models\User;
use App\Services\Admin\AdminLogger;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

/**
 * Gestion de l'équipe : liste du staff, changement de rôle (qui n'existait
 * nulle part : le seul moyen était le seeder), charge par modérateur.
 */
class AdminStaffController extends Controller
{
    use AdminHelpers;

    public function index(): JsonResponse
    {
        $staff = User::staff()
            ->orderByRaw("CASE role WHEN 'super_admin' THEN 0 WHEN 'admin' THEN 1 ELSE 2 END")
            ->orderBy('full_name')
            ->get(['id', 'full_name', 'username', 'phone_number', 'email', 'role', 'account_status', 'last_seen_at', 'created_at']);

        // Performance par membre sur 30 jours (actions journalisées).
        $actions = AdminActionLog::where('created_at', '>=', now()->subDays(30))
            ->whereIn('admin_id', $staff->pluck('id'))
            ->selectRaw('admin_id, COUNT(*) AS total')->groupBy('admin_id')->pluck('total', 'admin_id');

        $assigned = DB::query()->fromSub(
            DB::table('product_reports')->where('status', 'pending')->whereNotNull('assigned_to')->select('assigned_to')
                ->unionAll(DB::table('user_reports')->where('status', 'pending')->whereNotNull('assigned_to')->select('assigned_to'))
                ->unionAll(DB::table('support_tickets')->where('status', 'pending')->whereNotNull('assigned_to')->select('assigned_to')),
            'a'
        )->selectRaw('assigned_to, COUNT(*) AS total')->groupBy('assigned_to')->pluck('total', 'assigned_to');

        $staff->transform(function ($u) use ($actions, $assigned) {
            $u->actions_30d = (int) ($actions[$u->id] ?? 0);
            $u->open_assigned = (int) ($assigned[$u->id] ?? 0);

            return $u;
        });

        return response()->json(['staff' => $staff]);
    }

    /**
     * Change le rôle d'un utilisateur : user | moderator | admin.
     * super_admin ne s'attribue QUE par la commande Artisan quinch:set-role
     * (jamais depuis l'API). Les jetons du compte sont révoqués : il doit se
     * reconnecter avec ses nouveaux droits.
     */
    public function setRole(Request $request, User $user): JsonResponse
    {
        $validated = $request->validate([
            'role' => ['required', 'in:user,moderator,admin'],
            'reason' => $this->reasonRules(),
        ]);

        if ($deny = $this->denyIfCannotManage($request, $user)) {
            return $deny;
        }

        if ($user->account_status !== 'active') {
            return response()->json(['message' => 'Seul un compte actif peut recevoir un rôle.'], 422);
        }

        $old = $user->role;
        if ($old === $validated['role']) {
            return response()->json(['message' => 'Ce compte a déjà ce rôle.'], 422);
        }

        $user->forceFill(['role' => $validated['role']])->save();
        $user->tokens()->delete();

        AdminLogger::log($request->user(), 'role_changed', 'User', $user->id, [
            'from' => $old, 'to' => $validated['role'], 'reason' => $validated['reason'],
        ], 'critical');

        return response()->json(['message' => 'Rôle modifié.', 'user' => $user->fresh()]);
    }
}
