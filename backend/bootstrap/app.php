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

        $middleware->alias([
            'role' => \App\Http\Middleware\CheckRole::class,
            'fraud.check' => \App\Http\Middleware\FraudDetection::class,
            'feature' => \App\Http\Middleware\EnsureFeatureEnabled::class,
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
        $exceptions->shouldRenderJsonWhen(function ($request, \Throwable $e) {
            return $request->is('api/*') || $request->expectsJson();
        });
    })->create();
