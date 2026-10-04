<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

/**
 * Coupe l'accès API d'un compte BANNI ou SUSPENDU, quelle que soit la façon dont son
 * jeton a été obtenu. Sans ce garde-fou, seuls les jetons existants étaient supprimés
 * au moment de la sanction : un compte banni qui se reconnectait (Google, ancien jeton
 * non supprimé, session ouverte sur un autre appareil) gardait un accès complet.
 *
 * Une suspension arrivée à échéance n'est plus bloquante (User::isSuspended()).
 * Routes toujours permises : déconnexion, profil courant et — pour un compte suspendu
 * seulement — les contestations (il doit pouvoir contester sa sanction).
 */
class EnsureAccountActive
{
    private const ALWAYS_ALLOWED = ['api/v1/auth/logout', 'api/v1/auth/logout-all', 'api/v1/auth/me'];
    private const SUSPENDED_ALLOWED = ['api/v1/moderation/appeals', 'api/v1/moderation/appeals/*'];

    public function handle(Request $request, Closure $next): Response
    {
        $user = $request->user('sanctum');

        if (!$user || $request->is(self::ALWAYS_ALLOWED)) {
            return $next($request);
        }

        if ($user->isBanned()) {
            return response()->json([
                'message' => 'Votre compte a été banni.' . ($user->ban_reason ? ' Raison : ' . $user->ban_reason : ''),
                'error' => 'account_banned',
            ], 403);
        }

        if ($user->isSuspended() && !$request->is(self::SUSPENDED_ALLOWED)) {
            return response()->json([
                'message' => 'Votre compte est suspendu' . ($user->suspended_until ? " jusqu'au " . $user->suspended_until->format('d/m/Y H:i') : '') . '.',
                'error' => 'account_suspended',
            ], 403);
        }

        return $next($request);
    }
}
