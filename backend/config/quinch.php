<?php

return [

    /*
    |--------------------------------------------------------------------------
    | Moyens de paiement actifs
    |--------------------------------------------------------------------------
    |
    | Pour la V1 publique, seul le paiement à la livraison (cash_delivery)
    | est activé : l'intégration avec les vrais providers (Wave, Orange
    | Money, Free Money) et leurs webhooks n'a pas encore été validée en
    | conditions réelles. On réactivera ces méthodes une par une, provider
    | par provider, une fois les webhooks testés en sandbox.
    |
    | Configurable via QUINCH_PAYMENT_METHODS (liste séparée par des virgules)
    | pour pouvoir activer un provider en staging sans toucher au code.
    |
    */
    'enabled_payment_methods' => array_filter(array_map(
        'trim',
        explode(',', env('QUINCH_PAYMENT_METHODS', 'cash_delivery'))
    )),

    /*
    |--------------------------------------------------------------------------
    | Fonctionnalités activées (V1 réduite)
    |--------------------------------------------------------------------------
    |
    | Permet de couper certaines fonctionnalités non prioritaires pour la V1
    | sans supprimer le code (routes renvoient 404 si désactivées via les
    | vérifications ajoutées dans les contrôleurs / routes/api.php).
    |
    */
    'features' => [
        'negotiation'   => env('QUINCH_FEATURE_NEGOTIATION', false),
        'follow'        => env('QUINCH_FEATURE_FOLLOW', false),
        'reviews'       => env('QUINCH_FEATURE_REVIEWS', false),
        'badges'        => env('QUINCH_FEATURE_BADGES', false),
        'sharing'       => env('QUINCH_FEATURE_SHARING', false),
        'chat_audio'    => env('QUINCH_FEATURE_CHAT_AUDIO', false),
        'chat_file'     => env('QUINCH_FEATURE_CHAT_FILE', false),
        'favorites_collections' => env('QUINCH_FEATURE_FAVORITES_COLLECTIONS', false),
    ],

];
