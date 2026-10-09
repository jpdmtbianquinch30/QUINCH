# Stockage des médias : disque local, stockage objet et CDN

## Pourquoi

Les vidéos et photos sont la partie la plus lourde de QUINCH. Sur le disque du VPS, elles le remplissent,
ne survivent pas à la perte du serveur, et ralentissent l'API (PHP et nginx servent chaque fichier).
Un **stockage objet S3** garde les fichiers hors du serveur, et un **CDN** les livre vite aux visiteurs.

## Fonctionnement

Tout le code enregistre les fichiers sur le disque Laravel nommé `public`. La variable `MEDIA_DRIVER` décide
de ce qu'il désigne :

| `MEDIA_DRIVER` | Les fichiers sont | URL des médias |
|---|---|---|
| `local` (défaut) | sur le disque du serveur (`storage/app/public`) | `https://api.quinch.sn/storage/...` |
| `s3` | dans le bucket S3 | `MEDIA_CDN_URL` + chemin (ex. `https://media.quinch.sn/products/x.jpg`) |

Aucun autre code à changer. Les URL passent toutes par `App\Support\MediaUrl`. En mode `s3` :
- la lecture d'une vidéo (`/api/v1/videos/{id}/stream`) **redirige vers le CDN** (PHP ne lit plus le fichier) ;
- les miniatures FFmpeg lisent la vidéo par une URL S3 temporaire (seuls les octets utiles sont téléchargés) ;
- l'effacement des comptes supprimés (`PurgeAnonymizedAccountData`) supprime aussi les fichiers du bucket.

## Mise en place (une fois)

1. **Créer le bucket** chez le fournisseur (Contabo Object Storage : compatible S3). Relever : endpoint, région,
   clé d'accès, clé secrète. Contabo exige le mode **path-style** (`MEDIA_S3_PATH_STYLE=true`). Les valeurs exactes
   (endpoint, région) se lisent dans votre panneau Contabo.
2. **Rendre le bucket lisible publiquement** (lecture seule) ou faire lire le CDN avec des identifiants,
   selon ce que propose le fournisseur. L'écriture reste réservée à QUINCH.
3. **CDN** : créer un domaine `media.quinch.sn` qui pointe vers le bucket à travers votre CDN (par exemple Cloudflare
   en proxy, ou un CDN dédié). Activer le cache et le HTTPS. Autoriser les requêtes `Range` (lecture vidéo).
4. **Paquet S3** (une seule fois, sur votre poste) :
   ```
   cd backend
   composer require league/flysystem-aws-s3-v3 "^3.0"
   ```
   puis valider `composer.json` et `composer.lock` et reconstruire l'image. Le contrôle de démarrage refuse
   `MEDIA_DRIVER=s3` sans ce paquet.
5. **Variables** dans `backend/.env.docker` : `MEDIA_DRIVER=s3`, `MEDIA_S3_ENDPOINT`, `MEDIA_S3_REGION`,
   `MEDIA_S3_BUCKET`, `MEDIA_S3_KEY`, `MEDIA_S3_SECRET`, `MEDIA_S3_PATH_STYLE`, `MEDIA_CDN_URL` (en https).
6. **Copier les médias existants** (si le serveur en contient) :
   ```
   docker compose exec app php artisan quinch:media-migrate --dry-run     # compter
   docker compose exec app php artisan quinch:media-migrate               # copier (relançable)
   docker compose exec app php artisan quinch:media-migrate --delete-source   # après vérification, libère le disque
   ```
7. **Vérifier** : `docker compose exec app php artisan quinch:health --deep` (écriture, lecture, suppression d'un
   fichier de test dans le bucket), puis publier une annonce avec une vidéo et vérifier la lecture.

Retour en arrière : remettre `MEDIA_DRIVER=local` (les fichiers copiés restent dans le bucket ; ceux envoyés
pendant ce temps ne seraient pas sur le disque local : ne revenir en arrière qu'au tout début).

## Limites connues

- **Vidéo masquée par la modération** : l'API refuse de la servir (404), mais un fichier déjà connu par son URL
  directe du CDN reste lisible tant qu'il est dans le bucket. Les noms de fichiers sont aléatoires (non devinables).
  Pour une suppression garantie, effacer le fichier du bucket au rejet (amélioration possible).
- **Limites du fournisseur** : la documentation d'un tiers signale que Contabo limite le débit des fichiers publics
  et n'offre pas dans son interface les règles d'expiration automatique. Le CDN devant le bucket est donc nécessaire.
  Vérifier ces points dans la documentation actuelle de Contabo avant le lancement.
- **Envoi des vidéos** : PHP reçoit le fichier puis le transmet au bucket (jusqu'à 520 Mo). Prévoir du temps de requête ;
  un envoi direct navigateur → bucket (URL pré-signée) serait une évolution possible.
- **Sauvegarde du bucket** : le stockage objet n'est pas une sauvegarde. Voir `docs/BACKUPS.md`.
- **Messages déjà envoyés** : leur URL de pièce jointe est enregistrée en entier. Changer le domaine du CDN plus tard
  casserait les anciennes pièces jointes : choisir `MEDIA_CDN_URL` une fois pour toutes.
