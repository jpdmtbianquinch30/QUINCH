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
    'webhook_secret' => env('WAVE_WEBHOOK_SECRET'),
],


'google' => [
    'client_id'     => env('GOOGLE_CLIENT_ID'),
    'client_secret' => env('GOOGLE_CLIENT_SECRET'),
    'redirect'      => 'postmessage',
],

];
