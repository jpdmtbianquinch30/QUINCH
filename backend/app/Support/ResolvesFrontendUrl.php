<?php

namespace App\Support;

use Illuminate\Http\Request;

trait ResolvesFrontendUrl
{
    /**
     * Déduit l'URL du frontend à utiliser pour les redirections post-paiement
     * (success_url/error_url).
     *
     * Pourquoi lire l'en-tête Origin : en dev, le frontend Angular est joignable
     * via localhost:4200 OU 127.0.0.1:4200 (deux origines distinctes pour le
     * navigateur, donc deux localStorage séparés). Rediriger vers la mauvaise
     * origine après un paiement donnerait l'impression d'être déconnecté.
     *
     * Sécurité (OWASP A01/A10 — redirection ouverte) : l'en-tête Origin est
     * contrôlé par l'appelant. Il n'est donc accepté QUE s'il figure dans la
     * liste blanche CORS_ALLOWED_ORIGINS (ou s'il égale FRONTEND_URL). Toute
     * autre valeur est ignorée et on retombe sur FRONTEND_URL : impossible de
     * faire renvoyer un client vers un site tiers après un paiement.
     */
    private function resolveFrontendUrl(Request $request): string
    {
        $fallback = rtrim((string) config('quinch.frontend_url'), '/');

        $origin = $request->header('Origin');

        if (is_string($origin) && $origin !== '') {
            $origin = rtrim($origin, '/');

            $allowed = array_map(
                fn ($allowedOrigin) => rtrim((string) $allowedOrigin, '/'),
                (array) config('cors.allowed_origins', [])
            );
            $allowed[] = $fallback;

            if (in_array($origin, $allowed, true)) {
                return $origin;
            }
        }

        return $fallback;
    }
}
