<?php

return [

    /*
    |--------------------------------------------------------------------------
    | Cross-Origin Resource Sharing (CORS) Configuration
    |--------------------------------------------------------------------------
    |
    | Here you may configure your settings for cross-origin resource sharing
    | or "CORS". This determines what cross-origin operations may execute
    | in web browsers. You are free to adjust these settings as needed.
    |
    | To learn more: https://developer.mozilla.org/en-US/docs/Web/HTTP/CORS
    |
    */

    'paths' => ['api/*', 'sanctum/csrf-cookie', 'storage/*'],

    'allowed_methods' => ['*'],

    // Origines pilotées par l'environnement.
    //
    // Avant ce correctif, seules les URL localhost étaient autorisées : en
    // production, le navigateur bloquait TOUS les appels API du frontend
    // (échec CORS silencieux, application inutilisable). Renseigner
    // CORS_ALLOWED_ORIGINS dans le .env de production, par ex. :
    //   CORS_ALLOWED_ORIGINS=https://quinch.sn,https://www.quinch.sn
    //
    // Ne JAMAIS mettre '*' ici : `supports_credentials` étant à true, un
    // joker exposerait la session de tout utilisateur à n'importe quel site.
    'allowed_origins' => array_values(array_filter(array_map(
        'trim',
        explode(',', (string) env(
            'CORS_ALLOWED_ORIGINS',
            'http://localhost:4200,http://127.0.0.1:4200'
        ))
    ))),

    'allowed_origins_patterns' => [],

    'allowed_headers' => ['*'],

    'exposed_headers' => ['Content-Length', 'Content-Range', 'Accept-Ranges'],

    'max_age' => 86400,

    'supports_credentials' => true,

];
