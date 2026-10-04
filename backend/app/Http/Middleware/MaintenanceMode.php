<?php

namespace App\Http\Middleware;

use App\Models\SiteSetting;
use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

/**
 * Mode maintenance piloté depuis l'admin (réglage maintenance.enabled).
 * L'API répond 503 sauf : admin, authentification, webhooks de paiement
 * (ne jamais en perdre un) et la configuration publique du feed.
 */
class MaintenanceMode
{
    public function handle(Request $request, Closure $next): Response
    {
        if (SiteSetting::get('maintenance.enabled', false)
            && !$request->is('api/v1/admin/*', 'api/v1/auth/*', 'api/v1/webhooks/*', 'api/v1/feed/config')) {
            return response()->json([
                'message' => (string) SiteSetting::get(
                    'maintenance.message',
                    'QUINCH est en maintenance. Revenez dans quelques instants.'
                ),
                'error' => 'maintenance',
            ], 503);
        }

        return $next($request);
    }
}
