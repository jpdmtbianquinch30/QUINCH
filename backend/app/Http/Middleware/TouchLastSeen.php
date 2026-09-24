<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

/**
 * Met à jour users.last_seen_at à chaque requête API authentifiée, ce qui
 * alimente User::isOnlineAttribute() (statut en ligne/hors ligne dans les
 * conversations et le répertoire vendeur).
 *
 * Throttlé à 1 écriture / 60s / utilisateur pour ne pas spammer la table
 * users sur un utilisateur actif qui fait plusieurs appels API par minute.
 */
class TouchLastSeen
{
    private const THROTTLE_SECONDS = 60;

    public function handle(Request $request, Closure $next): Response
    {
        $user = $request->user();

        if ($user) {
            $shouldTouch = $user->last_seen_at === null
                || $user->last_seen_at->diffInSeconds(now()) >= self::THROTTLE_SECONDS;

            if ($shouldTouch) {
                $user->newQuery()->whereKey($user->id)->update(['last_seen_at' => now()]);
            }
        }

        return $next($request);
    }
}
