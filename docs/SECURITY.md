# Sécurité QUINCH

## Principes

1. Le backend est l'autorité de sécurité.
2. Le frontend ne doit jamais être considéré comme fiable.
3. Aucun secret fournisseur ne doit être envoyé à Angular.
4. Les opérations sensibles doivent être authentifiées, autorisées et journalisées.
5. Les uploads sont considérés comme hostiles.

## Authentification

- E-mail + mot de passe.
- Google OAuth avec validation du token côté backend.
- Récupération par code e-mail temporaire.
- Téléphone facultatif.
- Sanctum avec expiration configurée ; jeton du staff limité à 8 h (connexion classique **et** Google).
- Changer l'e-mail exige le mot de passe actuel ; l'ancienne adresse est prévenue, les autres sessions sont coupées
  et la nouvelle adresse repasse « non confirmée ».
- Changer le mot de passe déconnecte les autres appareils.
- `change-password`, `delete-account` (POST **et** DELETE) et `PUT user/profile` sont limités en fréquence.
- Règle de mot de passe unique (inscription, réinitialisation, changement) : 8 à 72 caractères, une majuscule,
  une minuscule, un chiffre.
- Comptes de l'équipe (modérateur, admin, super admin) : 14 caractères minimum au changement de mot de passe, 12 minimum à la
  création et à la réinitialisation par le super admin.
- Pseudos contenant `quinch` réservés (anti-usurpation) ; un compte officiel reçoit son pseudo par le serveur.
- Pseudos : 3 à 30 caractères, unicité insensible à la casse, noms réservés refusés (`App\Rules\AvailableUsername`).

## Protection des routes

Les routes sensibles utilisent :

- `auth:sanctum` ;
- rôles ;
- permissions ;
- rate limiting ;
- policies ;
- middlewares de sécurité.

## Paiements

Le paiement est confirmé uniquement après vérification serveur :

```text
signature webhook
+ référence interne
+ montant
+ devise
+ état fournisseur
+ idempotence
```

Pour les commandes (`App\Services\Payments\OrderPaymentConfirmer`) : montant ET devise vérifiés (prix × quantité + frais),
un échec Wave n'annule jamais une commande payée, un succès arrivé après expiration de la réservation re-réserve le
stock ou place la commande en revue manuelle (jamais de survente), et un même webhook rejoué ne change rien.

## Uploads

À vérifier systématiquement :

- taille ;
- MIME réel ;
- extension ;
- propriétaire ;
- quota ;
- nom généré ;
- emplacement non exécutable ;
- nettoyage des fichiers abandonnés.

## Headers

Le projet prévoit notamment :

- CSP / CSP Report-Only ;
- HSTS ;
- X-Frame-Options ;
- Referrer-Policy ;
- Permissions-Policy.

La CSP doit être observée avant d'être rendue bloquante sur le domaine public.

## Durcissement (phase 4, octobre 2026)

| Sujet | Règle |
|---|---|
| IP réelle | Le nginx de production (`backend/docker/nginx/production.conf`) fournit l'IP du visiteur à PHP et écrase tout `X-Forwarded-For` client. **Laisser `TRUSTED_PROXIES` vide** : avec `*`, un visiteur pourrait usurper une IP et contourner bannissements et limiteurs |
| En-têtes API | `X-XSS-Protection: 0`, CSP `default-src 'none'` sur `/api/*`, `Cache-Control: no-store` sur `/auth/*` |
| CSP du frontend | Définie dans `frontend/nginx.conf.template` ; mode observation avec `CSP_HEADER_NAME=Content-Security-Policy-Report-Only` avant de la rendre bloquante |
| TLS | Caddy (certificats Let's Encrypt automatiques) via `docker-compose.prod.yml` ; nginx n'est joignable que dans le réseau Docker |
| nginx | 64 Mo par requête (520 Mo seulement pour l'envoi de vidéo), seul `index.php` exécuté, limitation de débit large (IP partagées des réseaux mobiles), origines des médias restreintes |
| Redirection après paiement | L'en-tête `Origin` n'est accepté que s'il figure dans `CORS_ALLOWED_ORIGINS` (sinon `FRONTEND_URL`) |
| Exports CSV | Cellules neutralisées contre l'injection de formules Excel (`CsvSafe`) |
| Cookies / secrets | `quinch:preflight` refuse la production sans `SESSION_SECURE_COOKIE=true`, `SESSION_SAME_SITE` lax/strict, ni avec un mot de passe DB/Redis faible ou resté en modèle |
| Informations légales | `quinch:preflight` refuse la production sans `LEGAL_*` (éditeur, adresse, contact, hébergeur) |
| Dépendances et secrets | Dependabot, `composer audit`, `npm audit`, Gitleaks en CI |

Exploitation (phase 6) :

| Sujet | Règle |
|---|---|
| Point de santé | `/api/v1/ops/health` répond 404 sans le bon `HEALTH_TOKEN` : rien n'est révélé de l'infrastructure |
| Stockage objet | Clés d'accès dédiées au bucket (droit d'écriture limité à ce bucket), jamais les clés du compte fournisseur ; bucket de préproduction distinct |
| Sauvegardes | Dumps chiffrés (age) avant copie hors serveur ; la clé privée n'est jamais sur le serveur |
| Comptes de test | `quinch:seed-load-users` refuse de s'exécuter sans `QUINCH_ALLOW_LOADTEST_DATA=true` (préproduction uniquement) |
| Préproduction | Secrets, base, bucket et clés de paiement séparés de la production |

Risque assumé : le jeton de connexion est stocké dans `localStorage` (lisible par un script injecté). La CSP stricte
est la parade ; passer à un cookie HttpOnly changerait toute l'authentification (CSRF, application mobile).

## Audit de sécurité (octobre 2026)

Un audit statique du code a produit une liste de failles ; chacune a été confirmée dans le code puis corrigée avec des tests.

| Lot | Sujet | Correctif |
|---|---|---|
| A | Webhooks de paiement | Webhook Orange `FAILED` qui marquait la commande payée ; échecs Wave tardifs qui annulaient une commande payée ; montant non vérifié. Tout passe par `OrderPaymentConfirmer` (verrou, idempotence, montant, devise) |
| B | Prise de compte | Mot de passe exigé pour changer d'e-mail, alerte à l'ancienne adresse, révocation des autres jetons, limites de fréquence, jeton staff Google de 8 h |
| C | Erreurs 500 | Identifiants non-UUID en 404 (`Route::pattern`), règle `uuid` partout, filtres numériques tolérants, `mb_substr` (accents), longueurs bornées, gestionnaire global des erreurs PostgreSQL 22P02/22001/22003 |
| D | Confidentialité | Annonces non publiées (brouillon, expirée, en pause, désactivée) visibles seulement par leur auteur et le staff ; `total_revenue` retiré du profil public ; profils bannis/anonymisés en 404 ; `fileReplacements` du build de production |
| E | Abus | Avis réservés aux vrais interlocuteurs, vidéo d'un autre vendeur refusée, blocage appliqué (la table `blocked_users` manquait : création par migration), métadonnées de message non modifiables par le client, pseudos |
| F | Durcissement | Machine d'état des commandes atomique (livraison non répétable, annulations qui restituent le stock), compteurs de vues dédupliqués, collection de favoris vérifiée, `-protocol_whitelist` ffmpeg, `install-php-extensions` épinglé avec empreinte SHA-256, règle de mot de passe unique |

Restent volontairement ouverts : jeton de connexion en `localStorage`, double authentification du staff, anti-rejeu
horodaté du webhook Orange (format Sonatel à confirmer), épinglage des images `pgadmin4` et `pgbouncer`, vidéos
« pending » publiques tant que la modération n'a pas statué (choix produit).

## Comptes de l'équipe

- Le rôle `super_admin` ne s'attribue que par la commande `php artisan quinch:set-role` sur le serveur (jamais par HTTP) ;
  l'action est journalisée en « critical » et révoque les sessions du compte.
- Un super admin ne peut ni bannir ni supprimer un autre super admin ; personne n'agit sur son propre compte, sauf le super
  admin pour ses badges et sa confiance.
- `DatabaseSeeder` (compte `admin@quinch.sn`, mot de passe trivial) ne s'exécute qu'en `local` et `testing` : ne jamais le
  lancer sur un serveur ; supprimer ce compte de toute base conservée.
- La boîte e-mail d'un super admin reçoit les codes de réinitialisation : validation en deux étapes obligatoire sur cette boîte.
- La double authentification applicative (2FA) n'existe pas encore : à ajouter avant une ouverture large.

## Secrets

Ne jamais committer :

- `.env` réel ;
- API keys ;
- webhook secrets ;
- mots de passe DB ;
- credentials OAuth ;
- credentials SMTP.

La CI utilise Gitleaks en complément des bonnes pratiques Git.

## Avant ouverture publique

- [ ] test OWASP manuel ;
- [ ] test des permissions/IDOR ;
- [ ] test upload ;
- [ ] test rate limiting ;
- [ ] test récupération compte ;
- [ ] test webhooks ;
- [ ] test logs ;
- [ ] test CSP ;
- [ ] test TLS ;
- [ ] `APP_DEBUG=false` ;
- [ ] secrets uniquement côté serveur.
- [ ] aucun compte de démonstration (`admin@quinch.sn`) sur le serveur ;
- [ ] validation en deux étapes sur la boîte e-mail du super admin ;
- [ ] liste des rôles `moderator`/`admin`/`super_admin` relue (voir `docs/BETA.md`).
