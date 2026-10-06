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
     * Création directe d'un compte moderator ou admin par le super admin.
     * Le compte est immédiatement actif et vérifié (aucun SMS) ; le mot de passe
     * est choisi par le super admin et transmis hors application. Le rôle
     * super_admin ne se crée JAMAIS ici (commande Artisan uniquement).
     */
    public function store(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'full_name' => ['required', 'string', 'min:3', 'max:100'],
            'username' => ['required', 'string', 'min:3', 'max:30', 'unique:users,username', 'regex:/^[a-zA-Z0-9_]+$/'],
            'phone_number' => ['required', 'string', 'regex:/^\+221[0-9]{9}$/', 'unique:users,phone_number'],
            'email' => ['nullable', 'email', 'max:150', 'unique:users,email'],
            'role' => ['required', 'in:moderator,admin'],
            'password' => ['required', 'string', 'min:10', 'max:100', 'regex:/^(?=.*[A-Z])(?=.*[a-z])(?=.*[0-9]).+$/'],
        ], [
            'phone_number.regex' => 'Le numéro doit être au format Sénégal (+221XXXXXXXXX).',
            'phone_number.unique' => 'Ce numéro est déjà utilisé.',
            'username.unique' => "Ce nom d'utilisateur est déjà pris.",
            'username.regex' => 'Lettres, chiffres et _ uniquement.',
            'password.regex' => 'Le mot de passe doit contenir une majuscule, une minuscule et un chiffre.',
            'password.min' => 'Le mot de passe staff doit faire au moins 10 caractères.',
        ]);

        $user = new User();
        $user->fill([
            'phone_number' => $validated['phone_number'],
            'full_name' => $validated['full_name'],
            'username' => $validated['username'],
            'email' => $validated['email'] ?? null,
            'password' => $validated['password'],
            'is_seller' => false,
            'is_buyer' => false,
            'phone_verified' => true,
            'onboarding_completed' => true,
        ]);
        // Champs privilégiés hors $fillable : posés explicitement.
        $user->forceFill(['role' => $validated['role'], 'account_status' => 'active'])->save();

        AdminLogger::log($request->user(), 'staff_created', 'User', $user->id, [
            'role' => $validated['role'], 'username' => $validated['username'],
        ], 'critical');

        return response()->json([
            'message' => 'Compte ' . ($validated['role'] === 'admin' ? 'administrateur' : 'modérateur') . ' créé.',
            'user' => $user->only(['id', 'full_name', 'username', 'phone_number', 'email', 'role', 'account_status']),
        ], 201);
    }

    /** Nouveau mot de passe d'un membre du staff (sessions révoquées). */
    public function resetPassword(Request $request, User $user): JsonResponse
    {
        $validated = $request->validate([
            'password' => ['required', 'string', 'min:10', 'max:100', 'regex:/^(?=.*[A-Z])(?=.*[a-z])(?=.*[0-9]).+$/'],
        ], ['password.regex' => 'Le mot de passe doit contenir une majuscule, une minuscule et un chiffre.']);

        if ($deny = $this->denyIfCannotManage($request, $user)) {
            return $deny;
        }
        if (!$user->isStaff()) {
            return response()->json(['message' => "Ce compte ne fait pas partie de l'équipe."], 422);
        }

        $user->forceFill(['password' => $validated['password']])->save();
        $user->tokens()->delete();

        AdminLogger::log($request->user(), 'staff_password_reset', 'User', $user->id, [], 'critical');

        return response()->json(['message' => 'Mot de passe modifié. Le membre doit se reconnecter.']);
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
