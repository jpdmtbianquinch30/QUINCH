<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Gate;
use Symfony\Component\HttpFoundation\Response;

/**
 * Vérifie une (ou plusieurs, au choix) permission(s) fine(s) du staff :
 *   ->middleware('permission:users.ban')
 *   ->middleware('permission:products.moderate,videos.moderate')  // l'une OU l'autre
 * Les permissions sont définies dans config/permissions.php et enregistrées
 * comme Gates dans AppServiceProvider.
 */
class CheckPermission
{
    public function handle(Request $request, Closure $next, string ...$permissions): Response
    {
        $user = $request->user();

        if ($user) {
            foreach ($permissions as $permission) {
                if (Gate::forUser($user)->allows($permission)) {
                    return $next($request);
                }
            }
        }

        return response()->json([
            'message' => "Vous n'avez pas la permission d'effectuer cette action.",
            'error' => 'insufficient_permissions',
        ], 403);
    }
}
