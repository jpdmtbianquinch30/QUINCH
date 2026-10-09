<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Support\HealthChecker;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

/**
 * Point de santé détaillé pour la supervision (Uptime Kuma, monitoring externe).
 *
 * Protégé par HEALTH_TOKEN (en-tête X-Health-Token). Sans jeton configuré, ou avec un mauvais
 * jeton, il répond 404 comme si la route n'existait pas : rien n'est révélé de l'infrastructure.
 * (Le simple « l'application répond ? » reste GET /up, public et sans détail.)
 */
class HealthController extends Controller
{
    public function show(Request $request, HealthChecker $checker): JsonResponse
    {
        $expected = (string) config('ops.health_token', '');

        if ($expected === '' || !hash_equals($expected, (string) $request->header('X-Health-Token'))) {
            abort(404);
        }

        $report = $checker->run($request->boolean('deep'));

        return response()
            ->json([
                'status' => $report['status'],
                'time'   => now()->toIso8601String(),
                'checks' => $report['checks'],
            ], $report['critical'] ? 503 : 200)
            ->header('Cache-Control', 'no-store');
    }
}
