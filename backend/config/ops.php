<?php

/*
|--------------------------------------------------------------------------
| Exploitation : supervision et données de test de charge
|--------------------------------------------------------------------------
*/
return [

    // Jeton exigé par GET /api/v1/ops/health (en-tête X-Health-Token).
    // Vide = point de santé détaillé désactivé (404).
    'health_token' => env('HEALTH_TOKEN'),

    // Seuils d'alerte du point de santé.
    'queue_alert_size'      => (int) env('HEALTH_QUEUE_ALERT', 1000),
    'disk_min_free_percent' => (int) env('HEALTH_DISK_MIN_FREE', 15),

    // Autorise quinch:seed-load-users (création de faux comptes pour k6).
    // JAMAIS en production réelle : seulement sur la préproduction.
    'allow_load_test_data' => (bool) env('QUINCH_ALLOW_LOADTEST_DATA', false),

];
