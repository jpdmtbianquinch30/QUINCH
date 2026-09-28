<?php

use Illuminate\Foundation\Application;
use Illuminate\Foundation\Configuration\Exceptions;
use Illuminate\Foundation\Configuration\Middleware;

return Application::configure(basePath: dirname(__DIR__))
    ->withRouting(
        web: __DIR__ . '/../routes/web.php',
        api: __DIR__ . '/../routes/api.php',
        commands: __DIR__ . '/../routes/console.php',
        health: '/up',
        apiPrefix: 'api/v1',
    )

    ->withMiddleware(function (Middleware $middleware): void {

        /*
        |--------------------------------------------------------------------------
        | Security Headers
        |--------------------------------------------------------------------------
        |
        | Ajoute les en-têtes de sécurité à toutes les réponses HTTP.
        |
        */
        $middleware->append(
            \App\Http\Middleware\SecurityHeaders::class
        );

        /*
        |--------------------------------------------------------------------------
        | IP bannies
        |--------------------------------------------------------------------------
        |
        | Bloque les requêtes provenant d'une IP bannie par un administrateur,
        | avant même l'authentification.
        |
        | Voir SecurityController::banIp().
        |
        */
        $middleware->prependToGroup(
            'api',
            \App\Http\Middleware\CheckBannedIp::class
        );

        /*
        |--------------------------------------------------------------------------
        | Présence utilisateur
        |--------------------------------------------------------------------------
        |
        | Met à jour last_seen_at afin de permettre le calcul de is_online
        | pour les utilisateurs authentifiés.
        |
        */
        $middleware->appendToGroup(
            'api',
            \App\Http\Middleware\TouchLastSeen::class
        );

        /*
        |--------------------------------------------------------------------------
        | Middleware aliases
        |--------------------------------------------------------------------------
        |
        | Ces alias peuvent ensuite être utilisés directement dans les routes.
        |
        */
        $middleware->alias([
            'role' => \App\Http\Middleware\CheckRole::class,

            'fraud.check' => \App\Http\Middleware\FraudDetection::class,

            'feature' => \App\Http\Middleware\EnsureFeatureEnabled::class,

            'phone.verified' => \App\Http\Middleware\EnsurePhoneVerified::class,
        ]);

        /*
        |--------------------------------------------------------------------------
        | API : pas de redirection vers /login
        |--------------------------------------------------------------------------
        |
        | L'API ne possède pas nécessairement de route web "login".
        | Une requête non authentifiée doit donc recevoir une réponse
        | d'authentification appropriée plutôt qu'une redirection HTML.
        |
        */
        $middleware->redirectGuestsTo(
            fn () => null
        );
    })

    ->withExceptions(function (Exceptions $exceptions): void {

        /*
        |--------------------------------------------------------------------------
        | Réponses JSON pour l'API
        |--------------------------------------------------------------------------
        |
        | Les routes API doivent toujours recevoir des erreurs JSON
        | plutôt qu'une page HTML Laravel.
        |
        */
        $exceptions->shouldRenderJsonWhen(
            function ($request, \Throwable $e): bool {
                return $request->is('api/*')
                    || $request->expectsJson();
            }
        );
    })

    ->create();
