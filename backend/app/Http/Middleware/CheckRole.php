<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

class CheckRole
{
    public function handle(Request $request, Closure $next, string ...$roles): Response
    {
        $user = $request->user();

        if (!$user || !in_array($user->role, $roles)) {
            return response()->json([
                'message' => 'Accès non autorisé.',
                'error' => 'insufficient_permissions',
            ], 403);
        }

        if ($user->isSuspended()) {
            return response()->json([
                'message' => 'Votre compte est suspendu.',
                'error' => 'account_suspended',
            ], 403);
        }

        return $next($request);
    }
}
