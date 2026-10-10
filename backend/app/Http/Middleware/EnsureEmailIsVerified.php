<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

/**
 * Exige une adresse e-mail confirmée pour les actions sensibles
 * (acheter, s'abonner au Premium, postuler à l'offre Premium).
 *
 * Alias : 'email.verified' (voir bootstrap/app.php).
 * Réponse JSON 403 avec error = email_not_verified, que le front peut
 * reconnaître pour proposer de confirmer l'adresse.
 */
class EnsureEmailIsVerified
{
    public function handle(Request $request, Closure $next): Response
    {
        $user = $request->user();

        if (!$user || $user->email_verified_at === null) {
            return response()->json([
                'message' => 'Veuillez confirmer votre adresse e-mail pour effectuer cette action.',
                'error'   => 'email_not_verified',
            ], 403);
        }

        return $next($request);
    }
}
