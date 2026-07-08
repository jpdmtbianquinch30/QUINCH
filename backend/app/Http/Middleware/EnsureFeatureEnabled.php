<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

/**
 * Bloque l'accès à une route si la fonctionnalité correspondante est
 * désactivée dans config('quinch.features'). Utilisé pour couper les
 * fonctionnalités reportées post-V1 (négociation, follow, reviews, badges,
 * partage, chat audio/fichier, collections de favoris) sans supprimer le
 * code : il suffit de changer le .env pour les réactiver plus tard.
 *
 * Usage: Route::middleware('feature:negotiation')->group(...)
 */
class EnsureFeatureEnabled
{
    public function handle(Request $request, Closure $next, string $feature): Response
    {
        if (!config("quinch.features.{$feature}", false)) {
            abort(404);
        }

        return $next($request);
    }
}
