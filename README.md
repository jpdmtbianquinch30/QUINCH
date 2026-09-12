# QUINCH — Commerce social vidéo pour le Sénégal

> Marketplace social sénégalais combinant un feed vidéo courte, une grille produits façon marketplace, et un système de paiement mobile (Wave / Orange Money). Pensé pour Dakar et les principales villes du pays.

---

## Sommaire

- [État du projet](#état-du-projet)
- [Stack technique](#stack-technique)
- [Installation](#installation)
- [Variables d'environnement](#variables-denvironnement)
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

---

## Paiement — mode simulation (développement)

Tant que `WAVE_API_KEY` est absent du `.env` (et que `APP_ENV` n'est pas `production`), toute tentative de paiement (achat produit, abonnement Premium, frais de publication) redirige automatiquement vers une page de simulation locale (`/dev/simulate-payment`) au lieu d'appeler la vraie API Wave. Cette page permet de simuler un paiement réussi ou échoué, en rejouant **en interne** le même webhook signé que Wave enverrait réellement (`app()->handle()`, sans appel réseau) — donc sans jamais désynchroniser la logique testée en dev de celle utilisée en prod.

**Ce mode ne s'active jamais en production**, même si la clé est oubliée par erreur (double vérification dans `WaveGateway::initiatePayment()` et `SimulatePaymentController`).

Pour du vrai Wave en local : renseignez `WAVE_API_KEY` et `WAVE_WEBHOOK_SECRET` dans `.env`.

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

---

## Structure du dépôt

```
backend/    Laravel 12 — API (routes/api.php), migrations, jobs planifiés, tests
frontend/   Angular — application web publique complète
docker-compose.yml   postgres, app (PHP-FPM), queue, scheduler, nginx, pgadmin
```
```

