<?php

return [

    /*
    |--------------------------------------------------------------------------
    | Third Party Services
    |--------------------------------------------------------------------------
    |
    | This file is for storing the credentials for third party services such
    | as Mailgun, Postmark, AWS and more. This file provides the de facto
    | location for this type of information, allowing packages to have
    | a conventional file to locate the various service credentials.
    |
    */

    'postmark' => [
        'key' => env('POSTMARK_API_KEY'),
    ],

    'resend' => [
        'key' => env('RESEND_API_KEY'),
    ],

    'ses' => [
        'key' => env('AWS_ACCESS_KEY_ID'),
        'secret' => env('AWS_SECRET_ACCESS_KEY'),
        'region' => env('AWS_DEFAULT_REGION', 'us-east-1'),
    ],

    'slack' => [
        'notifications' => [
            'bot_user_oauth_token' => env('SLACK_BOT_USER_OAUTH_TOKEN'),
            'channel' => env('SLACK_BOT_USER_DEFAULT_CHANNEL'),
        ],
    ],

'orange_money' => [
    // Endpoint/segment pays à confirmer avec la doc que Sonatel vous
    // transmettra à l'activation du compte marchand (KYC RCCM/NINEA/RIB/CNI).
    'base_url' => env('ORANGE_MONEY_BASE_URL', 'https://api.orange.com/orange-money-webpay/sn/v1'),
    'auth_url' => env('ORANGE_MONEY_AUTH_URL', 'https://api.orange.com/oauth/v3/token'),
    'client_id' => env('ORANGE_MONEY_CLIENT_ID'),
    'client_secret' => env('ORANGE_MONEY_CLIENT_SECRET'),
    'merchant_key' => env('ORANGE_MONEY_MERCHANT_KEY'),
    'webhook_secret' => env('ORANGE_MONEY_WEBHOOK_SECRET'),
],

'wave' => [
    'base_url' => env('WAVE_BASE_URL', 'https://api.wave.com/v1'),
    'api_key' => env('WAVE_API_KEY'),
    // AUCUNE valeur par défaut : sans WAVE_WEBHOOK_SECRET, tous les webhooks
    // Wave sont rejetés (voir VerifiesWaveWebhook). Un secret par défaut
    // public permettrait à n'importe qui de forger un paiement « réussi ».
    'webhook_secret' => env('WAVE_WEBHOOK_SECRET'),
],


'google' => [
    'client_id'            => env('GOOGLE_CLIENT_ID'),
    'client_secret'        => env('GOOGLE_CLIENT_SECRET'),
    // Déclarés ici (et non lus via env() dans le contrôleur) : après un
    // `php artisan config:cache`, tout appel à env() hors config renvoie
    // null en production — la vérification d'audience échouerait alors
    // silencieusement pour les clients mobiles.
    'android_client_id'    => env('GOOGLE_ANDROID_CLIENT_ID'),
    'ios_client_id'        => env('GOOGLE_IOS_CLIENT_ID'),
    'redirect'             => 'postmessage',
],

'sms' => [
    // log (développement) | orange | twilio
    'driver' => env('SMS_DRIVER', 'log'),

    // Fournisseur de secours (orange | twilio), facultatif : utilisé si le principal échoue.
    'fallback_driver' => env('SMS_FALLBACK_DRIVER') ?: null,

    // Durée (secondes) pendant laquelle un fournisseur en échec est mis de côté.
    'breaker_seconds' => (int) env('SMS_BREAKER_SECONDS', 120),

    'orange' => [
        'base_url'      => env('ORANGE_SMS_BASE_URL', 'https://api.orange.com/smsmessaging/v1'),
        'auth_url'      => env('ORANGE_SMS_AUTH_URL', 'https://api.orange.com/oauth/v3/token'),
        'client_id'     => env('ORANGE_SMS_CLIENT_ID'),
        'client_secret' => env('ORANGE_SMS_CLIENT_SECRET'),
        // Numéro émetteur au format +221XXXXXXXXX, tel que déclaré chez Orange.
        'sender'        => env('ORANGE_SMS_SENDER'),
        'sender_name'   => env('ORANGE_SMS_SENDER_NAME', 'QUINCH'),
    ],

    'twilio' => [
        'sid'                   => env('TWILIO_SID'),
        'token'                 => env('TWILIO_TOKEN'),
        'from'                  => env('TWILIO_FROM'),
        'messaging_service_sid' => env('TWILIO_MESSAGING_SERVICE_SID'),
    ],
],

];
