<?php

/*
|--------------------------------------------------------------------------
| Médias (photos, vidéos, miniatures, pièces jointes)
|--------------------------------------------------------------------------
| Le disque lui-même se règle dans config/filesystems.php (disque « public »,
| basculé vers S3 par MEDIA_DRIVER=s3). Ce fichier ne gère que l'URL publique.
*/
return [

    // 'local' : disque du serveur (développement, petite bêta) ; 's3' : stockage objet.
    'driver' => env('MEDIA_DRIVER', 'local'),

    // URL publique de base des médias quand un CDN ou un domaine dédié les sert
    // (ex. https://media.quinch.sn). Vide : URL de l'API (/storage/...).
    'url' => env('MEDIA_CDN_URL'),

];
