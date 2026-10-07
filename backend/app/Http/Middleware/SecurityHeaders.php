<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

class SecurityHeaders
{
    public function handle(Request $request, Closure $next): Response
    {
        $response = $next($request);

        $response->headers->set('X-Frame-Options', 'DENY');
        $response->headers->set('X-Content-Type-Options', 'nosniff');
        // « 0 » volontairement : le filtre XSS intégré des anciens navigateurs a
        // lui-même introduit des failles (recommandation OWASP). La protection
        // repose sur la CSP et sur l'échappement des sorties.
        $response->headers->set('X-XSS-Protection', '0');
        $response->headers->set('Strict-Transport-Security', 'max-age=31536000; includeSubDomains');
        $response->headers->set('Referrer-Policy', 'strict-origin-when-cross-origin');
        $response->headers->set('X-Permitted-Cross-Domain-Policies', 'none');
        // `microphone=(self)` et non `()` : la messagerie propose des messages
        // vocaux (feature chat_audio). Avec la valeur précédente, le
        // navigateur refusait getUserMedia et l'enregistrement échouait sans
        // message d'erreur exploitable.
        $response->headers->set(
            'Permissions-Policy',
            'camera=(self), microphone=(self), geolocation=(self)'
        );

        if ($request->is('api/*')) {
            // L'API ne renvoie que du JSON (ou des flux média) : aucune ressource
            // active n'a à s'y charger ni à l'encadrer. La CSP de l'application
            // Angular est définie séparément (frontend/nginx.conf.template).
            $response->headers->set(
                'Content-Security-Policy',
                "default-src 'none'; frame-ancestors 'none'; base-uri 'none'; form-action 'none'"
            );
        }

        if ($request->is('api/v1/auth/*')) {
            // Jetons, codes et profils : jamais conservés par un cache navigateur
            // ou intermédiaire.
            $response->headers->set('Cache-Control', 'no-store, private');
            $response->headers->set('Pragma', 'no-cache');
        }

        return $response;
    }
}
