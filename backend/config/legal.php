<?php

/*
|--------------------------------------------------------------------------
| Informations légales de QUINCH
|--------------------------------------------------------------------------
| Alimentent les pages « Mentions légales », « Conditions d'utilisation » et
| « Politique de confidentialité » (GET /api/v1/legal/info). Elles se règlent
| dans le .env : aucun texte à modifier dans le code quand la société est créée.
|
| En production, quinch:preflight refuse de démarrer tant que l'éditeur, son
| adresse et l'e-mail de contact légal ne sont pas renseignés.
*/
return [

    'publisher' => [
        // Nom de la société, ou nom et prénom tant que l'activité est exercée à titre individuel.
        'name'         => env('LEGAL_PUBLISHER_NAME', ''),
        // Ex. « Société à responsabilité limitée au capital de ... » ou « Entrepreneur individuel ».
        'status'       => env('LEGAL_PUBLISHER_STATUS', ''),
        'address'      => env('LEGAL_PUBLISHER_ADDRESS', ''),
        // NINEA / RCCM, quand ils existent.
        'registration' => env('LEGAL_REGISTRATION_NUMBER', ''),
        // Directeur de la publication.
        'director'     => env('LEGAL_DIRECTOR', ''),
    ],

    // Numéro du récépissé de déclaration délivré par la CDP (Commission de Protection des
    // Données Personnelles) ; affiché dans la politique de confidentialité quand il existe.
    'cdp_receipt' => env('LEGAL_CDP_RECEIPT', ''),

    // Contact général et contact pour exercer les droits sur les données personnelles.
    'contact_email' => env('LEGAL_CONTACT_EMAIL', ''),
    'privacy_email' => env('LEGAL_PRIVACY_EMAIL', env('LEGAL_CONTACT_EMAIL', '')),

    // Hébergeur (obligatoire dans les mentions légales) et pays des serveurs.
    'hosting' => [
        'provider' => env('LEGAL_HOST_NAME', ''),
        'location' => env('LEGAL_HOST_LOCATION', ''),
    ],

    // Version des textes acceptés par chaque utilisateur à l'inscription.
    // À changer quand les conditions ou la politique de confidentialité évoluent.
    'versions' => [
        'terms'   => env('LEGAL_TERMS_VERSION', '2026-10'),
        'privacy' => env('LEGAL_PRIVACY_VERSION', '2026-10'),
    ],

    // Durées de conservation (en jours), appliquées par les tâches planifiées.
    'retention' => [
        // Après suppression d'un compte : délai avant effacement définitif des médias,
        // textes d'annonces et messages (laisse le temps de traiter un litige en cours).
        'anonymized_content_days' => (int) env('LEGAL_ANONYMIZED_CONTENT_DAYS', 30),
        // Journaux techniques (adresses IP, appareils).
        'audit_logs_days'         => (int) env('LEGAL_AUDIT_LOGS_DAYS', 180),
    ],

];
