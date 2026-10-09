<?php

return [

    /*
    |--------------------------------------------------------------------------
    | Default Filesystem Disk
    |--------------------------------------------------------------------------
    |
    | Here you may specify the default filesystem disk that should be used
    | by the framework. The "local" disk, as well as a variety of cloud
    | based disks are available to your application for file storage.
    |
    */

    'default' => env('FILESYSTEM_DISK', 'local'),

    /*
    |--------------------------------------------------------------------------
    | Filesystem Disks
    |--------------------------------------------------------------------------
    |
    | Below you may configure as many filesystem disks as necessary, and you
    | may even configure multiple disks for the same driver. Examples for
    | most supported storage drivers are configured here for reference.
    |
    | Supported drivers: "local", "ftp", "sftp", "s3"
    |
    */

    'disks' => [

        'local' => [
            'driver' => 'local',
            'root' => storage_path('app/private'),
            'serve' => true,
            'throw' => false,
            'report' => false,
        ],

        // Disque des médias (photos, vidéos, miniatures, pièces jointes) : TOUT le code
        // l'appelle « public ». MEDIA_DRIVER=s3 le bascule vers un stockage objet
        // compatible S3 (Contabo, R2, Scaleway...) sans modifier aucun appel de fichier.
        // Prérequis : composer require league/flysystem-aws-s3-v3 "^3.0" (voir docs/STORAGE.md).
        'public' => env('MEDIA_DRIVER', 'local') === 's3'
            ? [
                'driver' => 's3',
                'key' => env('MEDIA_S3_KEY'),
                'secret' => env('MEDIA_S3_SECRET'),
                'region' => env('MEDIA_S3_REGION', 'default'),
                'bucket' => env('MEDIA_S3_BUCKET'),
                'endpoint' => env('MEDIA_S3_ENDPOINT'),
                // Contabo et la plupart des stockages S3 « maison » exigent le mode path-style.
                'use_path_style_endpoint' => (bool) env('MEDIA_S3_PATH_STYLE', true),
                // En stockage distant, un échec d'écriture doit lever une erreur
                // (et non renvoyer false en silence, ce qui enregistrerait un chemin cassé).
                'throw' => true,
                'report' => false,
            ]
            : [
                'driver' => 'local',
                'root' => storage_path('app/public'),
                'url' => rtrim(env('APP_URL', 'http://localhost'), '/').'/storage',
                'visibility' => 'public',
                'throw' => false,
                'report' => false,
            ],

        // Dossier local des médias : source de la migration vers le stockage objet
        // (php artisan quinch:media-migrate). Inutilisé en fonctionnement normal.
        'local_public' => [
            'driver' => 'local',
            'root' => storage_path('app/public'),
            'throw' => false,
            'report' => false,
        ],

        's3' => [
            'driver' => 's3',
            'key' => env('AWS_ACCESS_KEY_ID'),
            'secret' => env('AWS_SECRET_ACCESS_KEY'),
            'region' => env('AWS_DEFAULT_REGION'),
            'bucket' => env('AWS_BUCKET'),
            'url' => env('AWS_URL'),
            'endpoint' => env('AWS_ENDPOINT'),
            'use_path_style_endpoint' => env('AWS_USE_PATH_STYLE_ENDPOINT', false),
            'throw' => false,
            'report' => false,
        ],

    ],

    /*
    |--------------------------------------------------------------------------
    | Symbolic Links
    |--------------------------------------------------------------------------
    |
    | Here you may configure the symbolic links that will be created when the
    | `storage:link` Artisan command is executed. The array keys should be
    | the locations of the links and the values should be their targets.
    |
    */

    'links' => [
        public_path('storage') => storage_path('app/public'),
    ],

];
