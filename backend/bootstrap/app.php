<?php

use Illuminate\Foundation\Application;
use Illuminate\Foundation\Configuration\Exceptions;
use Illuminate\Foundation\Configuration\Middleware;

return Application::configure(basePath: dirname(__DIR__))
    ->withRouting(
        web: __DIR__.'/../routes/web.php',
        api: __DIR__.'/../routes/api.php',
        commands: __DIR__.'/../routes/console.php',
        health: '/up',
        apiPrefix: 'api/v1',
    )
->withMiddleware(function (Middleware $middleware): void {
    $middleware->append(\App\Http\Middleware\SecurityHeaders::class);

    // Proxys de confiance (nginx, load balancer, Cloudflare...). SANS ceci,
    // $request->ip() renvoie l'IP du proxy : le bannissement d'IP et les
    // limiteurs de débit par IP s'appliqueraient à TOUT le monde d'un coup.
    // .env : TRUSTED_PROXIES=*  (derrière un LB dont l'IP change)
    //     ou TRUSTED_PROXIES=10.0.0.5,10.0.0.6  (IP précises, plus sûr)
    // Non défini = aucun proxy de confiance (comportement précédent).
    $trustedProxies = env('TRUSTED_PROXIES');
    if (is_string($trustedProxies) && trim($trustedProxies) !== '') {
        $middleware->trustProxies(
            at: trim($trustedProxies) === '*' ? '*' : array_map('trim', explode(',', $trustedProxies))
        );
    }


    // Limiteur global de l'API (défini dans AppServiceProvider). En production
    // CACHE_STORE doit être redis, sinon chaque requête écrit en base.
    $middleware->throttleApi('api');

    // Bloque toute requete venant d'une IP bannie par un admin (voir
    // SecurityController::banIp) — avant meme l'authentification.
    $middleware->prependToGroup('api', \App\Http\Middleware\CheckBannedIp::class);

    // Ping de présence : alimente last_seen_at (-> is_online) pour tout
    // appel API authentifié.
    $middleware->appendToGroup('api', \App\Http\Middleware\TouchLastSeen::class);

    // Compte banni / suspendu : accès API coupé même avec un jeton déjà émis
    // (voir EnsureAccountActive : sans lui, un banni qui se reconnecte garde tout).
    $middleware->appendToGroup('api', \App\Http\Middleware\EnsureAccountActive::class);

    // Mode maintenance piloté depuis l'admin (réglage maintenance.enabled).
    $middleware->appendToGroup('api', \App\Http\Middleware\MaintenanceMode::class);

    $middleware->alias([
        'role' => \App\Http\Middleware\CheckRole::class,
        'permission' => \App\Http\Middleware\CheckPermission::class,
        'sensitive' => \App\Http\Middleware\RequirePasswordConfirmation::class,
        'fraud.check' => \App\Http\Middleware\FraudDetection::class,
        'feature' => \App\Http\Middleware\EnsureFeatureEnabled::class,
        'email.verified' => \App\Http\Middleware\EnsureEmailIsVerified::class,
    ]);
        // API pure : il n'existe aucune route web nommée "login". Sans ceci,
        // une requête non authentifiée qui n'envoie pas Accept:application/json
        // (ex. Postman par défaut) fait planter Laravel en 500 (au lieu d'un
        // 401 propre) car il tente de rediriger vers route('login'), qui
        // n'existe pas. On force donc à ne jamais rediriger : toujours
        // renvoyer une exception d'authentification JSON.
        $middleware->redirectGuestsTo(fn () => null);
    })
    ->withExceptions(function (Exceptions $exceptions): void {
        // Garde-fou : une API ne doit jamais renvoyer une page d'erreur HTML
        // à un client mobile/JS. Sans ça, une exception imprévue (bug, 500,
        // 404, etc.) sur une route api/* renverrait la page d'erreur HTML de
        // Laravel, que Flutter/Angular ne sauraient pas parser.
        // Erreurs PostgreSQL provoquées par une entrée utilisateur : jamais de 500.
        //   22P02 = texte invalide pour le type (ex. « abc » à la place d'un UUID) -> 404
        //   22001 = valeur trop longue ; 22003 = nombre hors limites ; 22007/22008 = date invalide -> 422
        $exceptions->render(function (\Illuminate\Database\QueryException $e, $request) {
            if (!$request->is('api/*')) {
                return null;
            }
            $state = $e->errorInfo[0] ?? (string) $e->getCode();
            if ($state === '22P02') {
                return response()->json(['message' => 'Ressource introuvable.'], 404);
            }
            if (in_array($state, ['22001', '22003', '22007', '22008'], true)) {
                return response()->json(['message' => 'Une des valeurs envoyées est invalide ou trop longue.'], 422);
            }

            return null;
        });

        $exceptions->shouldRenderJsonWhen(function ($request, \Throwable $e) {
            return $request->is('api/*') || $request->expectsJson();
        });
    })->create();
