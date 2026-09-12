<?php

return [

    /*
    |--------------------------------------------------------------------------
    | Moyens de paiement actifs
    |--------------------------------------------------------------------------
    |
    | Wave est la seule passerelle réellement intégrée et activée par défaut
    | (voir app/Services/PaymentGateway/WaveGateway.php) — nécessite
    | WAVE_API_KEY pour fonctionner. Orange Money est implémenté mais les
    | noms de champs webhook restent à confirmer avec la doc Sonatel avant
    | activation en production.
    |
    | Configurable via QUINCH_PAYMENT_METHODS (liste séparée par des virgules)
    | pour pouvoir activer un provider en staging sans toucher au code.
    |
    */
        'enabled_payment_methods' => array_filter(array_map(
        'trim',
        explode(',', env('QUINCH_PAYMENT_METHODS', 'wave'))
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

        /*
    |--------------------------------------------------------------------------
    | URL du frontend
    |--------------------------------------------------------------------------
    | Utilisé pour construire les success_url/error_url envoyées aux
    | passerelles de paiement (Wave, Orange Money) — l'utilisateur y est
    | redirigé après le paiement.
    */
    'frontend_url' => env('FRONTEND_URL', 'http://localhost:4200'),

    /*
    |--------------------------------------------------------------------------
    | Premium — abonnement vendeur
    |--------------------------------------------------------------------------
    |
    | Tarifs en XOF. Le mensuel/annuel sont proposés via Wave (même
    | passerelle que les transactions). Modifiable ici sans toucher au code.
    |
    */
    'premium' => [
        'prices' => [
            'monthly' => (int) env('QUINCH_PREMIUM_PRICE_MONTHLY', 2000),
            'annual'  => (int) env('QUINCH_PREMIUM_PRICE_ANNUAL', 20000),
        ],

        // Photo de couverture (poster) toujours à part, jamais comptée dans
        // ces limites : gratuit = 1 couverture + 5 supplémentaires (6 au
        // total), premium = 1 couverture + 10 supplémentaires (11 au
        // total). Avant ce fix, le backend comptait encore le poster DANS
        // le total (3 pour gratuit, 10 pour premium) alors que le
        // frontend (sell.component.ts, maxAdditionalImages) traite déjà
        // ces deux nombres comme des limites "supplémentaires" séparées de
        // la couverture — un compte gratuit se faisait donc rejeter dès sa
        // 3e photo alors que l'interface en autorisait jusqu'à 6.
        'free_additional_photos_max'    => 5,
        'premium_additional_photos_max' => 10,

        // Frais de publication d'annonce pour un compte NON premium.
        // Gratuit pour les comptes premium (is_premium=true et non expiré).
        'listing_fee_with_video'    => (int) env('QUINCH_LISTING_FEE_WITH_VIDEO', 500),
        'listing_fee_without_video' => (int) env('QUINCH_LISTING_FEE_WITHOUT_VIDEO', 300),
                // Poids additionnel dans le classement du feed/marketplace pour un
        // vendeur premium actif. À l'échelle du feed_score existant
        // (engagement pondéré, fraîcheur jusqu'à 200, bonus vidéo jusqu'à 35,
        // aléatoire 0-40) — un boost visible sans écraser un produit très
        // engagé d'un compte gratuit.
        'feed_boost' => (int) env('QUINCH_PREMIUM_FEED_BOOST', 30),
    ],
];
