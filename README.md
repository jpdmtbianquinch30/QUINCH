# QUINCH — Social commerce vidéo pour le Sénégal

> Plateforme mobile de commerce social inspirée de TikTok et Facebook Marketplace, pensée pour le marché sénégalais et ouest-africain.

---

## Stack technique

| Couche | Technologie |
|--------|-------------|
| Application mobile (public — acheteurs/vendeurs) | Flutter (iOS + Android), go_router |
| Panneau d'administration (interne uniquement) | Angular, guards `guestGuard`/`adminGuard` |
| Backend API | Laravel 12 + Sanctum (`api/v1/*`) |
| Base de données | PostgreSQL 16 |
| Stockage médias | Local (dev, disque `public`) — Cloudflare R2 prévu en prod |

---

## Prérequis

- Flutter 3.x + Dart 3.x
- PHP 8.2+ (image Docker en 8.3) avec Composer
- PostgreSQL 16 (via Docker, voir `docker-compose.yml` — recommandé même en dev)
- Node.js 18+ (panneau admin Angular)

---

## Installation

### 1. Backend (Laravel)

```bash
# Démarrer PostgreSQL (voir section Docker plus bas pour le détail)
docker compose up -d postgres

cd backend
composer install
cp .env.example .env
php artisan key:generate

# Configurer la base de données dans .env (DB_CONNECTION=pgsql par défaut,
# adapter DB_PASSWORD à la valeur définie dans le .env à la racine)

php artisan migrate:fresh --seed
php artisan storage:link
php artisan serve
```

### 2. Application Flutter (public — acheteurs/vendeurs)

```bash
cd flutter_app
flutter pub get

# Configurer l'URL de l'API dans lib/config/api_config.dart

flutter run
```

### 3. Panneau d'administration (Angular — équipe interne uniquement)

```bash
cd frontend
npm install
ng serve
```

Puis ouvrir `http://localhost:4200/auth/login` et se connecter avec un compte
`admin` ou `super_admin`. **Toute autre route de cette app redirige vers cet
écran de connexion** (`app.routes.ts`) : les pages grand public (feed,
marketplace, panier, messages, profil...) existent encore dans
`frontend/src/app/pages/` mais ne sont **plus routées ni maintenues** —
elles dupliquaient l'app Flutter. Le grand public n'utilise que Flutter.

---

## Docker — développement local vs déploiement complet

Ce projet supporte deux façons d'utiliser Docker :

### A. Juste la base de données (dev quotidien)
```bash
cp .env.example .env   # à la racine, une seule fois — renseigner un vrai mot de passe
docker compose up -d postgres
```
Puis lancer Laravel normalement en dehors de Docker (`php artisan serve`), avec
dans `backend/.env` : `DB_HOST=127.0.0.1` (le port Postgres est exposé en local,
uniquement sur `127.0.0.1`).

### B. Stack complète (staging / production)
```bash
cp backend/.env.docker.example backend/.env.docker
# Éditer backend/.env.docker :
#  - DB_PASSWORD = la même valeur que POSTGRES_PASSWORD dans le .env racine
#  - APP_KEY = générer une clé avec `php artisan key:generate --show` (en local,
#    sans rien écrire) puis la coller ici

docker compose up -d --build
```
Démarre Postgres + le backend Laravel (PHP-FPM, build multi-stage sans
dépendances dev, config `backend/.env.docker`) + un worker de queue + Nginx
(exposé sur le port 8080, fichiers cachés `.env`/`.git` bloqués). Ce fichier
utilise déjà `DB_HOST=postgres` (nom du service sur le réseau Docker interne)
et `APP_DEBUG=false` — ne pas les repasser à `127.0.0.1`/`true`.

### Outil d'administration Postgres (optionnel)
```bash
docker compose --profile tools up -d pgadmin
```
Accessible uniquement depuis la machine hôte (`127.0.0.1:5050`), jamais exposé
publiquement.

⚠️ Les identifiants Postgres/pgAdmin viennent exclusivement du `.env` racine
(non commité). Ne jamais les remettre en dur dans `docker-compose.yml`.

---

## Tests automatisés (backend)

Les tests tournent sur une **vraie base PostgreSQL de test**, séparée de la
base de développement (SQLite ne supporte pas `fullText()`, utilisé dans les
migrations `products`).

```bash
# 1. Créer la base de test dédiée (une seule fois)
docker compose exec -u postgres postgres psql -c "CREATE DATABASE quinch_testing OWNER quinch_user;"

# 2. Config de test
cd backend
cp .env.testing.example .env.testing
# Éditer .env.testing : renseigner DB_PASSWORD (même valeur que Postgres)

# 3. Lancer les tests
composer test
# ou directement :
php artisan test
```

Chaque test utilise `RefreshDatabase` : la base `quinch_testing` est
réinitialisée automatiquement entre les tests.

### Couverture actuelle (52 tests / 120 assertions au dernier passage)
- Inscription / connexion (téléphone + OTP, y compris comptes suspendus)
- Mot de passe oublié (OTP, révocation des sessions existantes au reset)
- Achat en paiement à la livraison (seul moyen de paiement actif en V1) et
  rejet des autres moyens de paiement (Wave/Orange Money/Free Money)
- Modération : une vidéo `pending` n'apparaît jamais dans le feed public,
  ni un produit inactif
- Signalements produits + tickets support (création, doublons bloqués,
  résolution admin)
- Favoris unifiés (sauvegarde depuis le feed = favoris)
- Permissions admin (accès refusé aux non-admins, endpoints destructeurs
  retirés de l'API HTTP)
- Feature flags V1 (routes désactivées renvoient 404, réactivables via config)

---

## Périmètre V1 (fonctionnalités activées/désactivées)

Pour la première version publique, le périmètre est volontairement réduit.
Le code des fonctionnalités désactivées reste dans le repo (pour la V2/V3),
mais est bloqué côté API via des feature flags (voir `backend/config/quinch.php`,
activables via `backend/.env` — `QUINCH_FEATURE_*` et `QUINCH_PAYMENT_METHODS`) :

| Fonctionnalité | V1 |
|---|---|
| Inscription/connexion téléphone + OTP, login Google | ✅ |
| Mot de passe oublié (OTP) | ✅ |
| Feed vidéo, recherche, catégories, suggestions | ✅ |
| Upload produit/service + vidéo, favoris, likes | ✅ |
| Distinction Produit / Service (avec champs dédiés : type de service, zone, tarif...) | ✅ |
| Paiement à la livraison (`cash_delivery`) | ✅ |
| Paiement Wave / Orange Money / Free Money | ⏸️ V2 — webhooks codés et signature HMAC vérifiée, mais pas encore validés en sandbox réel |
| Chat texte acheteur/vendeur | ✅ (envoi uniquement — pas d'édition ni de suppression d'un message précis, voir Limitations connues) |
| Chat audio / envoi de fichier | ⏸️ V2 (`QUINCH_FEATURE_CHAT_AUDIO` / `QUINCH_FEATURE_CHAT_FILE`) |
| Négociation de prix | ⏸️ V2 (`QUINCH_FEATURE_NEGOTIATION`) |
| Follow / amis / feed "amis" | ⏸️ V2 (`QUINCH_FEATURE_FOLLOW`) |
| Reviews vendeur | ⏸️ V2 (`QUINCH_FEATURE_REVIEWS`) |
| Badges | ⏸️ V2 (`QUINCH_FEATURE_BADGES`) |
| Partage social | ⏸️ V2 (`QUINCH_FEATURE_SHARING`) |
| Collections de favoris | ⏸️ V2 (`QUINCH_FEATURE_FAVORITES_COLLECTIONS`) |
| Panneau admin (users, modération, métriques, signalements) | ✅ (Angular, voir section installation) |
| Panier → passage de commande | ❌ **cassé, voir Limitations connues** |
| Brouillon produit (non publié) | ❌ colonne en base prête, non exposée par l'API |

---

## ⚠️ Limitations et bugs connus (à date de ce README)

Cette section est volontairement honnête : elle liste ce qui **ne marche
pas encore**, pour éviter de perdre du temps à le redécouvrir.

- **Panier → commande cassé.** Le bouton "Passer la commande" de
  `flutter_app/lib/screens/cart/cart_screen.dart` appelle
  `context.push('/messages')` au lieu de déclencher un achat. Comme
  `/messages` est une route imbriquée dans le `ShellRoute` alors que `/cart`
  est poussée sur le navigateur racine, ça provoque un crash Flutter
  (`Failed assertion: '!keyReservation.contains(key)'`). Aujourd'hui, le
  seul chemin d'achat fonctionnel passe par la fiche produit
  (`product_detail_screen.dart`), qui appelle correctement
  `POST /transactions/initiate`. **Aucun écran de checkout n'existe dans le
  panier** — à construire.
- **Brouillons produits non exposés.** La colonne `status` de `products`
  supporte `draft`, mais `ProductController::store()` force
  `status = 'active'` en dur : impossible de publier un produit en brouillon
  via l'API pour l'instant.
- **Édition/suppression de message individuel absentes.**
  `ConversationController` ne permet que d'envoyer un message ou de
  supprimer toute une conversation (`destroy`) — pas d'édition (fenêtre de
  5 min souhaitée) ni de suppression "pour moi / pour tout le monde" d'un
  message précis.
- **Paiements mobiles non activés.** Wave / Orange Money / Free Money sont
  codés côté webhook (signature HMAC vérifiée) mais désactivés par défaut
  (`QUINCH_PAYMENT_METHODS=cash_delivery`) tant qu'ils n'ont pas été testés
  en sandbox réel avec chaque provider.

---

## Comptes de démonstration

| Rôle | Téléphone |
|------|-----------|
| Admin | +221 77 000 00 01 |
| Client 1 | +221 77 000 00 10 |
| Client 2 | +221 77 000 00 11 |

> Mot de passe de démo pour tous les comptes ci-dessus (seeder) : `password`
> — **à changer ou supprimer avant toute mise en ligne publique.**

---

## Endpoints API principaux

Toutes les routes sont préfixées par `api/v1` (voir `backend/bootstrap/app.php`).

### Auth (`/auth/*`)
- `POST /auth/register` · `POST /auth/login` · `POST /auth/verify-otp`
- `POST /auth/forgot-password` · `POST /auth/reset-password`
- `POST /auth/logout` · `POST /auth/logout-all` · `POST /auth/refresh` · `GET /auth/me`
- `POST /auth/google` — login Google

### Produits & Feed
- `GET /products` — liste / recherche marketplace
- `GET /products/feed` — fil vidéo style TikTok
- `GET /search`, `GET /search/suggestions`, `GET /search/trending`
- `GET /products/{slug}` — détail (par slug)
- `POST /products` — créer (auth requis)
- `PUT /products/{product}` / `DELETE /products/{product}` — par id, propriétaire uniquement
- `GET /my-products`

### Vidéos & Interactions
- `POST /products/upload-video`
- `GET /videos/{id}/stream`, `GET /videos/{id}/thumbnail`
- `POST /products/{id}/like` · `/save` · `/share` · `/view` · `/report`

### Panier
- `GET /cart` · `POST /cart/add` · `PUT /cart/{item}` · `DELETE /cart/{item}` · `DELETE /cart`

### Transactions
- `POST /transactions/initiate`
- `POST /transactions/{id}/confirm`
- `PUT /transactions/{id}/status` — accepter/expédier/livrer/annuler (vendeur), confirmer réception/annuler (acheteur)
- `GET /transactions/history` · `GET /transactions/{id}`
- `POST /transactions/{id}/dispute`
- Webhooks (publics, signature HMAC obligatoire) : `POST /webhooks/orange-money`, `/wave`, `/free-money`

### Messagerie
- `GET /conversations` · `POST /conversations/start` · `GET /conversations/{id}`
- `POST /conversations/{id}/messages` · `DELETE /conversations/{id}`

### Admin (rôle `admin`/`super_admin` requis)
- `GET /admin/dashboard/metrics`, `/dashboard/real-time`
- `GET /admin/users`, gestion : `/suspend`, `/activate`, `/verify-kyc`, `/adjust-trust`, `/ban`, `/send-notification`, `DELETE`
- `GET /admin/moderation/pending`, `POST /admin/moderation/bulk-action`
- `GET /admin/reports/{products|reported-users|support-tickets|transactions|fraud|users|overview}`
- `GET /admin/security/alerts`, `/security/logs`, `POST /admin/security/ip-ban`
- Reset/suppression de masse : volontairement **non exposés en HTTP**, uniquement en commande Artisan (`quinch:reset-data`, `quinch:delete-all-videos`)

---

## Structure réelle du projet

```
QUINCH/
├── backend/                  # Laravel 12 — API REST (api/v1)
│   ├── app/
│   │   ├── Http/Controllers/Api/V1/   # 25 contrôleurs (Auth, Product, Transaction, Admin...)
│   │   ├── Models/                    # User, Product, Transaction, Conversation, Message...
│   │   ├── Policies/                  # ProductPolicy, VideoPolicy
│   │   ├── Services/                  # PaymentGateway/, TrustScoring/
│   │   ├── Jobs/                      # ProcessVideoJob (compression asynchrone)
│   │   └── Console/Commands/          # quinch:reset-data, quinch:delete-all-videos
│   ├── database/{migrations,seeders}/
│   ├── config/quinch.php              # feature flags + moyens de paiement actifs
│   └── routes/api.php
├── flutter_app/               # Application mobile (public)
│   └── lib/
│       ├── config/            # routes (go_router), api_config
│       ├── models/, providers/, services/
│       ├── screens/           # auth, feed, marketplace, cart, product, sell,
│       │                      # messages, favorites, notifications, transactions,
│       │                      # profile, settings
│       └── widgets/
├── frontend/                  # Angular — panneau admin uniquement (voir plus haut)
│   └── src/app/
│       ├── core/{guards,interceptors,models,services}/
│       ├── pages/admin/       # seule section réellement routée
│       └── pages/*            # autres pages présentes mais non routées (legacy)
├── docker/{nginx,php}/
├── docker-compose.yml
└── README.md
```

---

## Paiements

| Méthode | Statut |
|---------|--------|
| Paiement à la livraison (`cash_delivery`) | ✅ Actif, seul moyen en V1 |
| Wave | Webhook + vérification de signature codés, désactivé (V2) |
| Orange Money | Webhook + vérification de signature codés, désactivé (V2) |
| Free Money | Webhook + vérification de signature codés, désactivé (V2) |

Aucune intégration de paiement en ligne réelle (PayTech ou autre) n'est
branchée à ce jour : les webhooks attendent d'être testés avec chaque
provider en sandbox avant activation via `QUINCH_PAYMENT_METHODS`.

---

## Sécurité

- Authentification par tokens Sanctum, tokens JWT invalides/expirés ignorés proprement (pas de 500)
- RBAC : rôles `user`, `admin`, `super_admin` — routes `/admin/*` protégées par middleware `role:`
- Rate limiting (`throttle`) sur les routes sensibles : login, register, OTP, signalement, upload vidéo, transaction
- Path traversal corrigé sur le streaming vidéo par chemin (`videos/stream-path`) : double vérification (chemin en base + `realpath()` dans la racine du disque)
- Signature HMAC obligatoire sur les 3 webhooks de paiement (`hash_equals`, un secret absent bloque la requête au lieu de désactiver la vérification)
- Actions admin destructrices (reset, suppression de masse) retirées de l'API HTTP, disponibles uniquement en commande Artisan
- `.env` jamais commité (uniquement des `.env.*.example`), aucun secret réel dans le repo
- Docker : port Postgres exposé uniquement sur `127.0.0.1`, build sans dépendances dev, fichiers cachés bloqués par Nginx

---

## Roadmap

- [ ] Réparer le tunnel d'achat depuis le panier (bloquant)
- [ ] Édition (fenêtre 5 min) et suppression (pour moi / pour tous) d'un message
- [ ] Exposer le statut brouillon pour les produits (création + publication différée)
- [ ] Validation des webhooks Wave/Orange Money/Free Money en sandbox puis activation
- [ ] Notifications push (Firebase FCM)
- [ ] Compression vidéo côté serveur (FFmpeg, `ProcessVideoJob` déjà en place)
- [ ] Déploiement backend (Railway / Render)

---

Projet QUINCH
