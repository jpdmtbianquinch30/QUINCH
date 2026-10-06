# QUINCH — Commerce social vidéo pour le Sénégal

> Marketplace social sénégalais combinant un feed vidéo courte, une grille produits façon marketplace, et un système de paiement mobile (Wave / Orange Money). Pensé pour Dakar et les principales villes du pays.

---

## Sommaire

- [État du projet](#état-du-projet)
- [Stack technique](#stack-technique)
- [Installation](#installation)
- [Variables d'environnement](#variables-denvironnement)
- [Connexion Google](#connexion-google)
- [Sécurité — correctifs de septembre 2026](#sécurité--correctifs-de-septembre-2026)
- [Paiement — Wave et Orange Money](#paiement--wave-et-orange-money)
- [Déploiement Docker](#déploiement-docker)
- [Feature flags](#feature-flags)
- [Rôles, modérateurs et admins](#rôles-modérateurs-et-admins)
- [Badges — la logique complète](#badges--la-logique-complète)
- [Messages de l'équipe et contestations](#messages-de-léquipe-et-contestations)
- [Fonctionnalités par domaine](#fonctionnalités-par-domaine)
- [Décisions d'architecture à connaître](#décisions-darchitecture-à-connaître)
- [Tâches planifiées (jobs)](#tâches-planifiées-jobs)
- [Tests](#tests)
- [Chantiers ouverts](#chantiers-ouverts-connus-non-résolus)
- [Déploiement production — checklist](#déploiement-production--checklist)
- [Structure du dépôt](#structure-du-dépôt)

---

## État du projet

Application web complète en développement actif, pré-production. Le backend est solide et largement testé (paiements, abonnements Premium, modération, feature flags — plus de 90 tests automatisés). Le frontend Angular a été entièrement reconstruit comme application publique complète (et non plus un simple panneau d'administration — voir historique Git, ce point a changé plusieurs fois).

---

## Stack technique

| Couche | Technologie |
|---|---|
| Frontend web (public) | Angular (standalone components, signals, sans NgModules) |
| Backend API | Laravel 12 + Sanctum (`api/v1/*`) |
| Base de données | PostgreSQL 16 (clés primaires UUID partout) |
| Paiement | Wave (intégration réelle, aucune simulation) ; Orange Money (code prêt, en attente des identifiants marchand Sonatel) |
| Stockage médias | Disque local (`storage/app/public`) en dev ; à migrer vers un stockage objet en prod |
| Infra | Docker Compose (app, queue, scheduler, nginx, postgres, pgadmin) |
| Tests | PHPUnit (backend), Karma/Jasmine (frontend, ciblé) |

---

## Installation

### 1. Base de données (Docker)

```bash
docker compose up -d postgres
```

### 2. Backend (Laravel)

```bash
cd backend
composer install
cp .env.example .env
php artisan key:generate

# Adapter DB_* dans .env selon vos identifiants Postgres locaux

php artisan migrate:fresh --seed
php artisan storage:link
php artisan serve
```

**Deux processus supplémentaires sont indispensables en local**, sans quoi les tâches planifiées ne tournent jamais :

```bash
php artisan schedule:work    # terminal dédié n°1
php artisan queue:work --tries=3   # terminal dédié n°2
```

En Docker/production, les services `scheduler` et `queue` de `docker-compose.yml` couvrent déjà ça.

### 3. Frontend (Angular)

```bash
cd frontend
npm install
ng serve
```

Ouvrir `http://localhost:4200`.

---

## Variables d'environnement

Les plus importantes (voir `backend/.env.example` pour la liste complète) :

| Variable | Rôle |
|---|---|
| `FRONTEND_URL` | Doit pointer vers `http://localhost:4200` en dev, jamais vers le domaine de prod tant qu'on teste en local — sinon les redirections de paiement échouent (`ERR_NAME_NOT_RESOLVED`). |
| `WAVE_API_KEY`, `WAVE_WEBHOOK_SECRET` | Obligatoires dès que `wave` est activé. Absents : les paiements échouent proprement et tous les webhooks sont rejetés. Aucun mode simulation n'existe. |
| `QUINCH_PAYMENT_METHODS` | Liste des passerelles activées, séparées par virgules (`wave` seul actuellement — Orange Money pas encore prêt). |
| `QUINCH_FEATURE_*` | Un booléen par fonctionnalité optionnelle (voir section Feature flags). |
| `QUINCH_PREMIUM_PRICE_MONTHLY` / `_ANNUAL` | Prix Premium en XOF (2000 / 20000 par défaut). |
| `QUINCH_LISTING_FEE_WITH_VIDEO` / `_WITHOUT_VIDEO` | Frais de publication pour un compte non-Premium (500 / 300 XOF). |
| `CORS_ALLOWED_ORIGINS` | **Obligatoire en production.** Domaines autorisés à appeler l'API depuis un navigateur, séparés par des virgules. Sans cette variable, le frontend de production est bloqué par le navigateur (erreur CORS). Ne jamais mettre `*` : `supports_credentials` est activé. |
| `GOOGLE_CLIENT_ID` / `GOOGLE_CLIENT_SECRET` | Connexion Google (voir section dédiée). Vides → le bouton est masqué, le reste de l'app fonctionne. |

---

## Paiement — Wave et Orange Money

Il n'existe **plus aucun mode simulation** (le simulateur `/dev/simulate-payment` et le secret
`dev-simulation-secret` ont été supprimés avant la mise en production).

- Sans `WAVE_API_KEY`, `WaveGateway::initiatePayment()` renvoie un échec propre, dans tous les environnements.
- Sans `WAVE_WEBHOOK_SECRET`, tous les webhooks Wave sont rejetés (aucune valeur par défaut).
- Les tests utilisent `Http::fake()` et définissent eux-mêmes la clé et le secret.
- Pour essayer Wave en local, renseignez de vraies valeurs dans `backend/.env` (webhooks : tunnel HTTPS type ngrok).
- Orange Money : à activer (`QUINCH_PAYMENT_METHODS=wave,orange_money`) uniquement une fois le compte marchand Sonatel obtenu.

> Le driver SMS `log` (codes OTP dans les logs et `demo_otp`) reste réservé au développement local et aux
> tests. En production il est **refusé au démarrage** par `quinch:preflight`.

---

## Déploiement Docker

```bash
cp .env.example .env                              # variables de docker-compose (mots de passe Postgres/Redis)
cp backend/.env.docker.example backend/.env.docker # configuration Laravel de production
# remplir TOUTES les valeurs CHANGE_ME / vides, puis :
docker compose build
docker compose up -d
```

Au démarrage de chaque conteneur, `backend/docker/entrypoint.sh` :

1. lance `php artisan quinch:preflight` — **le conteneur refuse de démarrer** si la configuration est dangereuse
   (`SMS_DRIVER=log`, CORS localhost, `APP_DEBUG=true`, secret Wave vide, `QUEUE_CONNECTION=sync`, Redis sans mot de passe…) ;
2. met en cache config, routes, événements et vues ;
3. applique les migrations (uniquement le service `app`, `RUN_MIGRATIONS=true`) ;
4. n'ouvre `nginx` et les workers qu'une fois `app` prêt (healthcheck).

Créer le premier super admin (jamais de seeder en production) :

```bash
docker compose exec app php artisan quinch:set-role +221XXXXXXXXX super_admin
```

Vérifier la configuration à la main : `docker compose exec app php artisan quinch:preflight`.

---

### OTP par SMS (inscription, mot de passe oublié, changement de numéro)

Tout compte doit vérifier son numéro par un code reçu par SMS avant d'utiliser l'application.

- `SMS_DRIVER=orange|twilio` : fournisseur principal ; `SMS_FALLBACK_DRIVER=twilio|orange` : secours automatique.
- Si le principal échoue, le message part par le secours ; un disjoncteur évite d'attendre le timeout du fournisseur
  en panne à chaque SMS (`SMS_BREAKER_SECONDS`). Si tous échouent, le job réessaie (5 s puis 30 s).
- Chaque tentative est enregistrée dans `sms_logs` (fournisseur, succès/échec, durée, numéro masqué), **jamais le
  code ni le texte du SMS**. Purge automatique après 90 jours.

```bash
docker compose exec app php artisan quinch:sms-test +221XXXXXXXXX --provider=orange   # test d'UN fournisseur
docker compose exec app php artisan quinch:sms-test +221XXXXXXXXX                      # chaîne complète
docker compose exec app php artisan quinch:sms-stats --hours=24                        # santé des envois
```

---

## Connexion Google

### Mise en service

1. Console Google Cloud → **API et services → Identifiants** → créer un *ID client OAuth* de type **Application Web**.
2. Déclarer les **origines JavaScript autorisées** : `http://localhost:4200` en dev, l'URL du site en production.
3. Reporter l'identifiant obtenu **à deux endroits** :
   - `GOOGLE_CLIENT_ID` dans `backend/.env` ;
   - `googleClientId` dans `frontend/src/environments/environment.ts` **et** `environment.prod.ts`.

Tant que ces valeurs sont vides, le bouton « Continuer avec Google » est masqué proprement et le reste de
l'application fonctionne normalement.

### Parcours

| Étape | Route | Remarque |
|---|---|---|
| Connexion / inscription | `POST auth/google` | **Publique.** Le frontend envoie l'`id_token` renvoyé par le SDK Google Identity Services. |
| Ajout du numéro | `POST auth/google/add-phone` | Authentifiée. Un compte Google n'a pas de numéro sénégalais : demandé juste après la première connexion, génère l'OTP dans la foulée. |
| Choix du pseudo | `POST auth/google/update-username` | Authentifiée. |

Le backend ne fait jamais confiance au profil renvoyé par le SDK : `GoogleAuthController::verifyGoogleToken()`
revérifie l'audience (`aud`), l'émetteur (`iss`), l'expiration (`exp`) et la présence de `sub` auprès de Google.

> **Le rattachement à un compte existant par adresse e-mail n'a lieu que si Google confirme
> `email_verified`.** Sans ce contrôle, créer un compte Google portant l'e-mail d'une victime suffirait à
> récupérer son compte QUINCH. Ne pas assouplir ce point.

---

## Sécurité — correctifs de septembre 2026

Six constats issus d'un audit, dont deux critiques. Détail complet dans
**`QUINCH-audit-et-changements.pdf`** (à la racine du dépôt).

| Réf. | Constat | Gravité | État |
|---|---|---|---|
| SEC-01 | Réinitialisation de mot de passe sans preuve de possession | Critique | Corrigé |
| SEC-02 | Connexion Google inopérante + vérification de jeton incomplète | Critique | Corrigé |
| SEC-03 | CORS figé sur localhost — API inaccessible en production | Bloquant | Corrigé |
| SEC-04 | Micro interdit par en-tête alors que la messagerie vocale existe | Moyen | Corrigé |
| SEC-05 | Jetons Sanctum sans expiration | Moyen | Corrigé |
| SEC-06 | Middleware `phone_verified` annoncé mais inexistant | Moyen | Corrigé |

### Points à ne pas défaire

- **`POST auth/google` doit rester hors de tout groupe `auth:sanctum`.** Elle y était déclarée par erreur :
  il fallait être connecté pour pouvoir se connecter, la route répondait 401 en permanence.
- **`reset-password-email` exige un OTP.** Le couple téléphone + e-mail ne prouve rien : le numéro est
  transmis à l'acheteur dans chaque transaction, l'e-mail se devine. L'e-mail reste vérifié comme *second*
  facteur, jamais comme unique rempart.
- **Les identifiants clients Google se lisent via `config('services.google.*')`, jamais via `env()`.**
  Après `php artisan config:cache` — obligatoire en production — `env()` renvoie `null` hors des fichiers
  de configuration.
- **`Permissions-Policy` doit garder `microphone=(self)`.** Avec `microphone=()`, le navigateur refuse
  `getUserMedia()` et les messages vocaux échouent sans erreur exploitable.
- **`auth/google/add-phone` et `auth/google/update-username` doivent rester hors du middleware
  `phone.verified`.** Ce sont les routes qui *servent* à sortir de l'état non vérifié — les y soumettre
  rendrait la vérification impossible à terminer pour un compte Google.
- **`config('sanctum.expiration')` ne doit pas repasser à `null`.** `SANCTUM_TOKEN_EXPIRATION_MINUTES`
  pilote cette valeur (14 jours par défaut) ; `AuthService` (Angular) prolonge une session active bien
  avant l'échéance via `auth/refresh`, donc un utilisateur qui revient régulièrement ne la voit jamais.

### Middleware `phone.verified`

`app/Http/Middleware/EnsurePhoneVerified.php`, alias `phone.verified` (voir `bootstrap/app.php`). Appliqué
sur le grand groupe de routes métier de `routes/api.php` (produits, panier, messagerie, favoris,
notifications, transactions, premium, follow, badges, reviews) — exactement les routes que `authGuard`
protège déjà côté Angular. Renvoie `403 {"error": "phone_not_verified"}`, relayé côté frontend par
`error.interceptor.ts` vers `/auth/verify-otp`.

**Volontairement absent** de `auth/*` (logout, me, refresh...), de `auth/google/add-phone` /
`update-username`, et du groupe `admin/*` — voir le commentaire en tête du fichier pour le détail.

### Tests de non-régression

`backend/tests/Feature/Auth/SecurityHardeningTest.php` — 13 tests, couvrant les six constats. S'ils
repassent au rouge, une faille a été réintroduite. `Http::fake()` y est utilisé pour Google : aucun appel
réseau réel.

> Ces tests ont été **écrits sans être exécutés** (environnement d'audit sans PHP ni réseau).
> `php artisan test` est le premier geste à faire à la réception de ce dépôt.

---

## Feature flags

```
QUINCH_PAYMENT_METHODS=wave          # orange_money à ajouter une fois les identifiants Sonatel obtenus
QUINCH_FEATURE_NEGOTIATION=true      # négociation de prix acheteur/vendeur
QUINCH_FEATURE_FOLLOW=true           # abonnements/abonnés entre utilisateurs
QUINCH_FEATURE_REVIEWS=true          # avis vendeur
QUINCH_FEATURE_BADGES=true           # badges de profil
QUINCH_FEATURE_SHARING=true          # partage de produit (tracking + données de partage)
QUINCH_FEATURE_CHAT_AUDIO=true       # messages vocaux
QUINCH_FEATURE_CHAT_FILE=true        # pièces jointes dans la messagerie
QUINCH_FEATURE_FAVORITES_COLLECTIONS=true   # collections de favoris personnalisées
```

Une route désactivée répond `404` (`EnsureFeatureEnabled` middleware) plutôt que de planter — comportement volontaire et testé (`DisabledFeatureTest`).

---

## Fonctionnalités par domaine

**Authentification**
- Inscription avec OTP obligatoire avant tout accès à l'app (vérifié à la fois côté route Angular et côté middleware Laravel — `phone_verified`)
- Connexion simple : téléphone + mot de passe, aucun OTP requis
- Récupération de mot de passe par deux chemins au choix : OTP par SMS, ou téléphone + email combinés (double facteur, sans envoi d'email réel — l'email doit être configuré au préalable dans `edit-profile`)

**Achat / vente**
- Achat produit : paiement Wave réel, réservation de stock avec libération automatique après 20 min si le paiement n'aboutit pas
- Panier repensé en liste d'envies : pas de checkout multi-vendeurs, chaque achat se fait individuellement (achat direct ou depuis le panier, dans une modale sans quitter la page)
- Publication d'annonce en 3 étapes (médias → détails → paiement/récapitulatif), avec deux issues possibles : **Brouillon** (sauvegarde privée, aucun paiement tenté, permanent) ou **Payer et publier** (frais selon présence de vidéo, gratuit pour Premium)
- Limite de photos : 3 pour un compte gratuit, 10 pour un compte Premium
- Nettoyage automatique des brouillons abandonnés après 24h (fichiers + enregistrement supprimés)

**Abonnement Premium**
- Mensuel (2000 XOF) ou annuel (20000 XOF), paiement Wave
- Avantages réels : publication gratuite, 10 photos au lieu de 3, mise en avant dans le feed et le marketplace (pondération de classement), badge visible sur le profil (propre profil et profil public)

**Découverte**
- Feed marketplace en grille (2 colonnes mobile, 4-5 desktop avec filtres fixes)
- Feed vidéo dédié (accessible via bannière depuis le feed principal)
- Recherche (produits + vendeurs), marketplace avec tri (récent/populaire/prix — le tri prix ignore toujours le boost Premium, volontairement)

**Social**
- Suivi (follow/followers), avec détection d'amitié mutuelle et création automatique de conversation
- Avis vendeur, négociation de prix, badges, collections de favoris

**Messagerie**
- Conversations texte, audio, fichiers (selon feature flags) — pas de temps réel (pas de websocket/polling actuellement)

**Administration**
- Gestion utilisateurs, modération de contenu, rapports, tableaux de bord

---

## Rôles, modérateurs et admins

Quatre niveaux (config : `backend/config/permissions.php`) : `user` (0) < `moderator` (1) < `admin` (2) < `super_admin` (3). **On ne peut agir que sur un rôle strictement inférieur au sien**, jamais sur soi-même.

| Rôle | Ce qu'il fait | Ce qu'il ne peut pas faire |
|---|---|---|
| **Modérateur** | Traite la boîte « À traiter » : signalements, tickets, contestations ; modère vidéos et annonces (masquer, rétablir, supprimer en « suppression douce », corriger un titre, retirer un visuel) ; avertit un utilisateur ; suspend **7 jours maximum** | Bannir, supprimer un compte, changer un rôle, toucher aux finances, créer des badges, diffuser des annonces de masse |
| **Admin** | Tout ce que fait un modérateur + suspensions longues, bannissement, KYC, score de confiance, badges (attribution **et création**), notifications individuelles et de masse, catégories, bannières du feed, Premium offert/retiré, modération des avis, journaux d'audit, lecture finances | Changer les rôles, créer des comptes staff, réglages système, bannir une IP, trancher un litige |
| **Super admin** | Tout (`*`) + **créer les comptes modérateur / admin**, changer les rôles, réinitialiser le mot de passe d'un membre du staff, réglages système (maintenance, interrupteurs), bannir des IP, trancher les litiges | — |

**Créer un compte staff** : Admin → *Communauté → Équipe & Premium* → onglet **Équipe** → « Créer un modérateur » / « Créer un administrateur » (API : `POST /api/v1/admin/staff`, réservé au super admin, mot de passe du super admin exigé). Le compte est actif immédiatement (pas de SMS), il se connecte avec son **numéro +221…** et le mot de passe choisi (10 caractères min., majuscule + minuscule + chiffre). Transmettez-le par un canal sûr. Le rôle `super_admin` ne se crée **jamais** par l'API : uniquement `php artisan quinch:set-role`.

**Passer du site à l'admin** : barre latérale du site → « Administration » (visible pour tout le staff) ; dans l'admin → carte « Voir le site » (ou bouton « Site » en haut) pour ouvrir le site comme un utilisateur sans se déconnecter. Le bouton « Se déconnecter » demande une confirmation.

Sécurité : jeton staff court (8 h), mot de passe de confirmation sur les actions sensibles, journal d'audit de chaque action (`admin_action_logs`).

---

## Badges — la logique complète

**Source unique : les badges créés dans l'admin** (*Communauté → Badges*, table `badge_definitions`). Aucun badge n'est ajouté « en dur » dans le code front : l'ancien badge Premium doré automatique a été supprimé ; Premium est maintenant un badge admin **branché** sur la règle « abonnement Premium actif ».

Un badge, c'est :
- une **définition** (admin) : nom, identifiant technique, icône (Material Icons), couleur, description, « comment l'obtenir » (affiché dans le guide), ordre, actif / désactivé ;
- des **zones d'affichage** (cochées par l'admin) : `feed` (accueil), `explorer`, `video_feed`, `product_detail`, `seller_profile`, `messages`, `search`, `notifications`, `rankings`, `profile` ;
- une **attribution** = une ligne de `user_badges` (utilisateur + badge). Sa colonne `source` vaut `manual` (donné par un humain) ou `auto` (posé par le système).

**Deux façons d'obtenir un badge**
1. **Manuel** : fiche utilisateur (admin) → *Badge*. Le badge « Client Fidèle » peut en plus être donné par un **vendeur** à un client qui a vraiment acheté chez lui, si l'admin coche « Les vendeurs peuvent l'attribuer ».
2. **Automatique** (« brancher » le badge) — règles disponibles :

| Règle | Condition pour avoir le badge |
|---|---|
| `premium` | Abonnement Premium actif (`is_premium` et date d'expiration future) |
| `kyc_verified` | Identité vérifiée (KYC) |
| `sales_completed` + seuil | Au moins N ventes finalisées (paiement `completed`) |
| `account_age_days` + seuil | Compte créé depuis au moins N jours |
| `trust_score` + seuil (en %) | Score de confiance ≥ N % |

Le système (`App\Services\BadgeService`) ajoute le badge à ceux qui le méritent et le **retire** à ceux qui ne le méritent plus (uniquement les badges `auto` ; les badges `manual` ne sont jamais retirés). Premium et KYC sont recalculés **immédiatement** quand le compte change ; le reste chaque heure (`quinch:sync-badges`) ou à la demande (bouton « Recalculer »). Changer la règle d'un badge efface ses anciennes attributions automatiques puis recalcule.

**Badges d'origine** (recréés par la migration, désactivables mais non supprimables) : Vérifié (KYC), Premium (Premium actif), Top Vendeur, Livraison Express, Client Fidèle (vendeurs), Reviewer Actif, Première Vente (1 vente), 100 Ventes, Ambassadeur (manuels), 1 an sur QUINCH (365 jours).

**Affichage côté front** : un seul composant `<app-user-badges [badges]="x.badges" zone="messages" />` ; il ne montre que les badges dont les zones contiennent la zone courante. L'API renvoie pour chaque badge `{type, name, icon, color, description, zones}`. Le guide public (`/guide/index.html#badges`) liste les badges **en direct** depuis `GET /api/v1/badges/definitions` (nom, comment l'obtenir, où il s'affiche).

---

## Messages de l'équipe et contestations

Toute décision de l'équipe (avertissement, suspension, vidéo retirée, annonce masquée/supprimée, résultat de contestation, réponse de ticket, litige, avis retiré, Premium retiré/offert, KYC…) crée une notification `type = admin` dont `data` contient :
`kind` (nature du problème), `detail` (`message` ou `guide`), `guide_anchor` (section du guide), `contest` (cible contestable) et `concerned_admin_id` (membre du staff qui a décidé). Le catalogue est `NotificationService::KINDS`.

Bouton « Voir le détail » :
- `detail = guide` (information simple : compte réactivé, annonce rétablie…) → ouvre **exactement la zone du guide** (`/guide/index.html#<ancre>`) ;
- `detail = message` → page **`/notifications/:id`** : message complet de l'« Équipe QUINCH », bouton **Lu / Pas lu**, lien vers la zone du guide qui explique la situation, et formulaire **« Contester cette décision »**.

**Contestation** (`POST /api/v1/notifications/{id}/contest`, 10 à 2000 caractères) : valable pour un avertissement, une suspension, une vidéo retirée, une annonce masquée/supprimée, ou pour répondre à un message libre (case « Autoriser l'utilisateur à répondre » à l'envoi). Elle arrive dans **Admin → À traiter → Contestations** et **prévient directement l'admin concerné** (à défaut, les super admins). L'accepter annule la décision (avertissement retiré, vidéo/annonce rétablie, suspension levée) ; la réponse revient à l'utilisateur dans sa notification. Une seule contestation à la fois par décision ; refusée = réponse finale.

Suppression de compte : mot de passe exigé ; le compte est **anonymisé** (transactions et signalements conservés pour les litiges). Les comptes staff ne peuvent pas se supprimer eux-mêmes.

---

## Décisions d'architecture à connaître

- **`payment_status` ≠ `order_status`** sur une transaction : le premier ne représente que l'état du paiement côté gateway (`pending/completed/failed/refunded`), le second l'avancement de la commande (`pending_payment/processing/shipped/delivered/completed/cancelled/disputed`). Ne jamais les confondre dans un nouvel écran.
- **UUID comme clé primaire partout**, ce qui rend `latestOfMany()`/`ofMany()` de Laravel **incompatibles** sous PostgreSQL (`MAX(uuid)` n'existe pas — erreur `SQLSTATE[42883]`). Utiliser une sous-requête corrélée manuelle à la place (voir `Conversation::lastMessage()` comme référence).
- **Statut `draft` à double usage** sur `Product` : un brouillon volontaire (`listing_fee_status = none`, permanent) et un brouillon en attente de paiement (`listing_fee_status = pending/failed`, supprimé après 24h) — distingués uniquement par `listing_fee_status`, jamais par un champ dédié.
- **Trait `VerifiesWaveWebhook`** partagé entre `TransactionController`, `PremiumController` et `ProductController` — toute nouvelle intégration Wave doit le réutiliser plutôt que dupliquer la vérification de signature.
- **`auth.user()` (signal frontend) ne se rafraîchit jamais tout seul** après une action qui change le profil côté serveur (abonnement Premium, changement de ville, edit-profile) — il faut explicitement appeler `auth.updateUser(res.user)` ou `auth.getMe()` après ces actions, sinon le reste de l'app affiche des données périmées jusqu'à la reconnexion.
- **OPcache PHP (XAMPP/Apache)** : un fichier backend modifié n'est pas toujours pris en compte immédiatement en local — `php artisan optimize:clear` ne vide que le cache Laravel, jamais l'OPcache. Redémarrer Apache si un correctif semble "ne pas s'appliquer".

---

## Tâches planifiées (jobs)

| Job | Fréquence | Rôle |
|---|---|---|
| `ReleaseExpiredReservations` | Chaque minute | Libère le stock réservé si le paiement n'a pas abouti sous 20 min |
| `ExpirePremiumSubscriptions` | Quotidien | Désactive les abonnements Premium expirés |
| `CleanupAbandonedDraftListings` | Toutes les heures | Supprime les brouillons en attente de paiement abandonnés depuis 24h (+ fichiers) |
| `quinch:sync-badges` | Toutes les heures | Pose / retire les badges **automatiques** (Premium, KYC, ventes, ancienneté, confiance) |

Nécessitent `php artisan schedule:work` **et** `php artisan queue:work` actifs en permanence (ou les services Docker `scheduler`/`queue` en prod).

---

## Tests

```bash
cd backend
php artisan test
```

```bash
cd frontend
ng test --watch=false --browsers=ChromeHeadless
```

---

## Chantiers ouverts (connus, non résolus)

### Bloquants avant toute mise en production

- **SMS OTP réels.** Les passerelles Orange SMS et Twilio sont codées (`SMS_DRIVER=orange|twilio`) ; il reste à
  renseigner les identifiants de production et à valider l'envoi réel de bout en bout (phase suivante).
- **Identifiants marchand Wave.** Sans `WAVE_API_KEY` et `WAVE_WEBHOOK_SECRET`, tous les paiements échouent
  proprement et le démarrage de production est refusé (`quinch:preflight`).
- **Stockage des médias sur disque local.** `storage/app/public` ne survit pas à un redéploiement
  conteneurisé. Migration vers un stockage objet nécessaire.
(SEC-05 et SEC-06, listés dans la section Sécurité ci-dessus, sont désormais corrigés.)

### Autres

- **Orange Money** : code présent (`OrangeMoneyGateway`) mais jamais branché en réel — en attente de la documentation et des identifiants Sonatel.
- **Messagerie sans temps réel** : fonctionnelle mais sans websocket ni polling.
- **Design du feed vidéo** : jugé trop proche visuellement de TikTok, refonte demandée mais pas encore livrée.
- **`products/active-sellers`** : route backend fonctionnelle et testée, mais aucun composant frontend ne l'utilise actuellement.

---

## Déploiement production — checklist

- [ ] `APP_ENV=production` et `APP_DEBUG=false`
- [ ] `FRONTEND_URL` pointant vers le vrai domaine (jamais `localhost`)
- [ ] `WAVE_API_KEY` et `WAVE_WEBHOOK_SECRET` réels renseignés (sinon `quinch:preflight` refuse le démarrage)
- [ ] Services `scheduler` et `queue` de `docker-compose.yml` bien démarrés
- [ ] Sauvegardes PostgreSQL configurées
- [ ] `php artisan config:cache` + `route:cache` après tout déploiement
- [ ] `CORS_ALLOWED_ORIGINS` renseigné avec le vrai domaine (sinon le frontend est bloqué par le navigateur)
- [ ] `SMS_DRIVER=orange` (ou `twilio`) avec identifiants réels — `log` est refusé au démarrage
- [ ] `QUEUE_CONNECTION=redis` et `REDIS_PASSWORD` identique dans `.env` et `backend/.env.docker`
- [ ] `GOOGLE_CLIENT_ID` renseigné côté backend **et** frontend, origines déclarées dans la console Google
- [ ] Médias migrés vers un stockage objet (le disque local ne survit pas au redéploiement)
- [ ] `composer audit` et `npm audit` passés
- [ ] `php artisan test` au vert, y compris `SecurityHardeningTest`

---

## Structure du dépôt

```
backend/    Laravel 12 — API (routes/api.php), migrations, jobs planifiés, tests
frontend/   Angular — application web publique complète
docker-compose.yml   postgres, app (PHP-FPM), queue, scheduler, nginx, pgadmin
QUINCH-audit-et-changements.pdf   Audit de sécurité + journal des changements
```
```

