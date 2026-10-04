<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\RateLimiter;
use Symfony\Component\HttpFoundation\Response;

/**
 * Actions sensibles (bannir, supprimer, changer un rôle, bannir une IP,
 * rembourser, diffusion de masse...) : l'admin doit ressaisir SON mot de passe
 * (champ `admin_password` ou en-tête X-Admin-Password). Limité à 5 échecs / 5 min.
 */
class RequirePasswordConfirmation
{
    public function handle(Request $request, Closure $next): Response
    {
        $user = $request->user();
        $key = 'admin-pw-confirm:' . ($user?->id ?? $request->ip());

        if (RateLimiter::tooManyAttempts($key, 5)) {
            return response()->json([
                'message' => 'Trop de tentatives. Réessayez dans quelques minutes.',
                'error' => 'too_many_attempts',
            ], 429);
        }

        $password = $request->input('admin_password') ?? $request->header('X-Admin-Password');

        if (!$user || !is_string($password) || $password === '' || !Hash::check($password, $user->password)) {
            RateLimiter::hit($key, 300);

            return response()->json([
                'message' => 'Mot de passe de confirmation requis ou incorrect.',
                'error' => 'password_confirmation_required',
            ], 403);
        }

        RateLimiter::clear($key);

        return $next($request);
    }
}
