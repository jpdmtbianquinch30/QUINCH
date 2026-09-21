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
- [Paiement — mode simulation](#paiement--mode-simulation-développement)
- [Feature flags](#feature-flags)
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
| Paiement | Wave (intégration réelle + mode simulation dev) ; Orange Money (code prêt, en attente des identifiants marchand Sonatel) |
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
| `WAVE_API_KEY`, `WAVE_WEBHOOK_SECRET` | Absents → mode simulation automatique (voir plus bas). |
| `QUINCH_PAYMENT_METHODS` | Liste des passerelles activées, séparées par virgules (`wave` seul actuellement — Orange Money pas encore prêt). |
| `QUINCH_FEATURE_*` | Un booléen par fonctionnalité optionnelle (voir section Feature flags). |
| `QUINCH_PREMIUM_PRICE_MONTHLY` / `_ANNUAL` | Prix Premium en XOF (2000 / 20000 par défaut). |
| `QUINCH_LISTING_FEE_WITH_VIDEO` / `_WITHOUT_VIDEO` | Frais de publication pour un compte non-Premium (500 / 300 XOF). |
| `CORS_ALLOWED_ORIGINS` | **Obligatoire en production.** Domaines autorisés à appeler l'API depuis un navigateur, séparés par des virgules. Sans cette variable, le frontend de production est bloqué par le navigateur (erreur CORS). Ne jamais mettre `*` : `supports_credentials` est activé. |
| `GOOGLE_CLIENT_ID` / `GOOGLE_CLIENT_SECRET` | Connexion Google (voir section dédiée). Vides → le bouton est masqué, le reste de l'app fonctionne. |

---

## Paiement — mode simulation (développement)

Tant que `WAVE_API_KEY` est absent du `.env` (et que `APP_ENV` n'est pas `production`), toute tentative de paiement (achat produit, abonnement Premium, frais de publication) redirige automatiquement vers une page de simulation locale (`/dev/simulate-payment`) au lieu d'appeler la vraie API Wave. Cette page permet de simuler un paiement réussi ou échoué, en rejouant **en interne** le même webhook signé que Wave enverrait réellement (`app()->handle()`, sans appel réseau) — donc sans jamais désynchroniser la logique testée en dev de celle utilisée en prod.

**Ce mode ne s'active jamais en production**, même si la clé est oubliée par erreur (double vérification dans `WaveGateway::initiatePayment()` et `SimulatePaymentController`).

Pour du vrai Wave en local : renseignez `WAVE_API_KEY` et `WAVE_WEBHOOK_SECRET` dans `.env`.

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
- Achat produit : paiement Wave réel ou simulé, réservation de stock avec libération automatique après 20 min si le paiement n'aboutit pas
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

Nécessitent `php artisan schedule:work` **et** `php artisan queue:work` actifs en permanence (ou les services Docker `scheduler`/`queue` en prod).

---

## Tests

```bash
cd backend
php artisan test          # ~92 tests
```

```bash
cd frontend
ng test --watch=false --browsers=ChromeHeadless
```

---

## Chantiers ouverts (connus, non résolus)

### Bloquants avant toute mise en production

- **Aucun envoi de SMS réel.** `AuthController::forgotPassword()` contient un `// TODO`. L'OTP est généré et
  stocké haché, mais transmis nulle part : il n'apparaît dans la réponse HTTP qu'en `local`/`testing`
  (`demo_otp`). **En production, personne ne peut récupérer son mot de passe.** Prévoir Orange SMS API
  (Sonatel) ou Twilio.
- **Identifiants marchand Wave.** Sans `WAVE_API_KEY` valide, le mode simulation ne s'active pas en
  production (garde-fou volontaire) : tous les paiements échouent, proprement mais intégralement.
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
- [ ] `WAVE_API_KEY` et `WAVE_WEBHOOK_SECRET` réels renseignés (sinon le mode simulation... ne s'activera pas non plus en prod, et les paiements échoueront proprement avec un message d'erreur, par sécurité)
- [ ] Services `scheduler` et `queue` de `docker-compose.yml` bien démarrés
- [ ] Sauvegardes PostgreSQL configurées
- [ ] `php artisan config:cache` + `route:cache` après tout déploiement
- [ ] `CORS_ALLOWED_ORIGINS` renseigné avec le vrai domaine (sinon le frontend est bloqué par le navigateur)
- [ ] Passerelle SMS branchée dans `forgotPassword()` — sans quoi la récupération de mot de passe est impossible
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

