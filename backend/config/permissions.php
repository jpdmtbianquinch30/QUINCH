<?php

/*
|--------------------------------------------------------------------------
| Rôles et permissions du panneau d'administration QUINCH
|--------------------------------------------------------------------------
|
| Hiérarchie : user (0) < moderator (1) < admin (2) < super_admin (3).
| - Un membre du staff ne peut agir QUE sur un rôle strictement inférieur
|   au sien (voir User::canManage()).
| - super_admin possède toutes les permissions ('*').
| - Chaque permission est enregistrée comme Gate dans AppServiceProvider,
|   et vérifiée sur les routes via le middleware `permission:xxx`.
|
*/

$moderator = [
    'products.view',
    'products.moderate',       // masquer / réactiver / supprimer (suppression douce)
    'products.edit_content',   // corriger titre / description
    'media.remove',            // retirer ou remplacer une vidéo / image
    'videos.moderate',
    'appeals.handle',
    'reports.handle',          // signalements, tickets
    'users.view',
    'users.warn',
    'users.suspend_short',     // suspension <= moderator_max_suspension_days
];

$admin = array_merge($moderator, [
    'users.suspend',
    'users.ban',
    'users.kyc',
    'users.trust',
    'users.badges',
    'badges.manage',           // créer / configurer les badges, règles automatiques
    'users.notify',
    'users.delete',
    'users.export',
    'products.pin',
    'products.force_status',
    'categories.manage',
    'feed.manage',
    'notifications.broadcast',
    'fraud.handle',
    'finance.view',            // lecture seule des transactions / finance
    'premium.manage',
    'reviews.moderate',
    'audit.view',
]);

$superOnly = [
    'staff.manage',            // changer les rôles
    'settings.manage',         // réglages, maintenance, interrupteurs
    'security.ip_ban',
    'disputes.resolve',        // trancher un litige
    'finance.refund',          // rembourser
];

return [
    'levels' => [
        'user'        => 0,
        'moderator'   => 1,
        'admin'       => 2,
        'super_admin' => 3,
    ],

    // Catalogue complet (utilisé pour enregistrer les Gates).
    'all' => array_values(array_unique(array_merge($admin, $superOnly))),

    'roles' => [
        'moderator'   => $moderator,
        'admin'       => $admin,
        'super_admin' => ['*'],
    ],

    // Un modérateur ne peut pas suspendre plus longtemps que ceci.
    'moderator_max_suspension_days' => 7,
];
