<?php

namespace App\Http\Middleware;

use App\Models\BannedIp;
use Closure;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Cache;
use Symfony\Component\HttpFoundation\Response;

/**
 * Bloque les IP bannies. Avant : une requête SQL à CHAQUE appel API, aucune
 * expiration, et le staff pouvait se retrouver bloqué.
 * Maintenant : liste des bannissements ACTIFS en cache (60 s), expiration
 * respectée, et le staff authentifié n'est jamais bloqué.
 *
 * IMPORTANT : configurer TRUSTED_PROXIES (voir bootstrap/app.php), sinon
 * derrière nginx / un load balancer $request->ip() renvoie l'IP du proxy et
 * bannir « une IP » reviendrait à bannir tout le monde.
 */
class CheckBannedIp
{
    public const CACHE_KEY = 'banned_ips.active';

    public function handle(Request $request, Closure $next): Response
    {
        $ip = $request->ip();

        if ($ip && in_array($ip, self::activeBans(), true)) {
            $user = $request->user('sanctum');

            if (!$user || !$user->isStaff()) {
                return response()->json([
                    'message' => 'Accès refusé depuis cette adresse IP.',
                ], 403);
            }
        }

        return $next($request);
    }

    /** @return array<int, string> */
    public static function activeBans(): array
    {
        try {
            return Cache::remember(self::CACHE_KEY, 60, function () {
                return BannedIp::query()->active()->pluck('ip_address')->all();
            });
        } catch (\Throwable $e) {
            return [];
        }
    }

    public static function flush(): void
    {
        Cache::forget(self::CACHE_KEY);
    }
}
