
# QUINCH — Social commerce vidéo pour le Sénégal

> Plateforme mobile de commerce social inspirée de TikTok et Facebook Marketplace, pensée pour le marché sénégalais et ouest-africain.

---

## Stack technique

| Couche | Technologie |
|--------|-------------|
| Application mobile (public) | Flutter (iOS + Android) |
| Panneau d'administration (interne) | Angular |
| Backend API | Laravel 12 + Sanctum |
| Base de données | PostgreSQL 16 |
| Stockage médias | Cloudflare R2 (prod) / Local (dev) |

---

## Prérequis

- Flutter 3.x + Dart 3.x
- PHP 8.2+ avec Composer
- PostgreSQL 16 (via Docker, voir `docker-compose.yml` — recommandé même en dev)
- Node.js 18+ (outils dev uniquement)

---

## Installation

### 1. Backend (Laravel)

```bash
# Démarrer PostgreSQL (voir Chantier Docker plus bas pour le detail)
docker compose up -d postgres

cd backend
composer install
cp .env.example .env
php artisan key:generate

# Configurer la base de données dans .env (DB_CONNECTION=pgsql par defaut,
# adapter DB_PASSWORD a la valeur definie dans votre .env a la racine)

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
`admin` ou `super_admin`. Toute autre page de ce frontend redirige vers cet
écran de connexion : **cette app ne sert plus qu'au panneau admin**, le grand
public n'utilise que l'app Flutter (voir section "Périmètre V1" ci-dessous).

---

## Docker — développement local vs déploiement complet

Ce projet supporte deux façons d'utiliser Docker :

### A. Juste la base de données (dev quotidien)
```bash
cp .env.example .env   # à la racine, une seule fois — renseigner un vrai mot de passe
docker compose up -d postgres
```
Puis lancer Laravel normalement en dehors de Docker (`php artisan serve`), avec
dans `backend/.env` : `DB_HOST=127.0.0.1` (le port Postgres est exposé en local).

### B. Stack complète (staging / production)
```bash
cp backend/.env.docker.example backend/.env.docker
# Editer backend/.env.docker :
#  - DB_PASSWORD = la même valeur que POSTGRES_PASSWORD dans le .env racine
#  - APP_KEY = générer une clé avec `php artisan key:generate --show` (en local,
#    sans rien écrire) puis la coller ici (et dans backend/.env si besoin)

docker compose up -d --build
```
Démarre Postgres + le backend Laravel (PHP-FPM, config `backend/.env.docker`)
+ un worker de queue + Nginx (exposé sur le port 8080). Ce fichier utilise
déjà `DB_HOST=postgres` (nom du service sur le réseau Docker interne) et
`APP_DEBUG=false` — ne pas les repasser à `127.0.0.1`/`true`, sous peine de
retomber sur les bugs corrigés lors de la mise en place de cette stack
(connexion DB qui échoue, page d'erreur de debug énorme en production).

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
réinitialisée automatiquement entre les tests, aucune action manuelle requise
après la création initiale.

### Couverture actuelle
- Inscription / connexion (téléphone + OTP, y compris comptes suspendus)
- Achat en paiement à la livraison (seul moyen de paiement actif en V1) et
  rejet des autres moyens de paiement (Wave/Orange Money/Free Money)
- Modération : une vidéo `pending` n'apparaît jamais dans le feed public
- Permissions admin (accès refusé aux non-admins, endpoints destructeurs
  retirés de l'API HTTP)
- Feature flags V1 (routes désactivées renvoient 404, réactivables via config)

---

## Périmètre V1 (fonctionnalités activées/désactivées)

Pour la première version publique, le périmètre est volontairement réduit.
Le code des fonctionnalités désactivées reste dans le repo (pour la V2/V3),
mais est bloqué côté API via des feature flags (voir `backend/config/quinch.php`
et `backend/.env`) :

| Fonctionnalité | V1 |
|---|---|
| Inscription/connexion téléphone + OTP, login Google | ✅ |
| Feed vidéo, recherche, catégories | ✅ |
| Upload produit + vidéo, favoris, likes | ✅ |
| Paiement à la livraison (`cash_delivery`) | ✅ |
| Paiement Wave / Orange Money / Free Money | ⏸️ V2 (webhooks à valider en sandbox avant activation) |
| Chat texte acheteur/vendeur | ✅ |
| Chat audio / envoi de fichier | ⏸️ V2 (`QUINCH_FEATURE_CHAT_AUDIO` / `QUINCH_FEATURE_CHAT_FILE`) |
| Négociation de prix | ⏸️ V2 (`QUINCH_FEATURE_NEGOTIATION`) |
| Follow / amis / feed "amis" | ⏸️ V2 (`QUINCH_FEATURE_FOLLOW`) |
| Reviews vendeur | ⏸️ V2 (`QUINCH_FEATURE_REVIEWS`) |
| Badges | ⏸️ V2 (`QUINCH_FEATURE_BADGES`) |
| Partage social | ⏸️ V2 (`QUINCH_FEATURE_SHARING`) |
| Collections de favoris | ⏸️ V2 (`QUINCH_FEATURE_FAVORITES_COLLECTIONS`) |
| Panneau admin (users, modération, métriques) | ✅ (Angular, voir section installation) |

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

### Auth
- `POST /api/v1/auth/register`
- `POST /api/v1/auth/login`
- `POST /api/v1/auth/logout`
- `GET  /api/v1/auth/me`

### Feed & Produits
- `GET  /api/v1/feed` — fil vidéo style TikTok
- `GET  /api/v1/products`
- `POST /api/v1/products` — créer (auth requis)
- `GET  /api/v1/products/{slug}`
- `PUT  /api/v1/products/{slug}`
- `DELETE /api/v1/products/{slug}`

### Vidéos & Interactions
- `POST /api/v1/videos/upload`
- `POST /api/v1/products/{id}/like`
- `POST /api/v1/products/{id}/save`
- `POST /api/v1/products/{id}/share`

### Transactions
- `POST /api/v1/transactions`
- `GET  /api/v1/transactions`
- `POST /api/v1/transactions/{id}/confirm`

---

## Structure du projet

```
QUINCH/
├── backend/           # Laravel 12 — API REST
│   ├── app/
│   │   ├── Http/Controllers/Api/V1/
│   │   ├── Models/
│   │   ├── Policies/
│   │   └── Services/
│   ├── database/
│   │   ├── migrations/
│   │   └── seeders/
│   └── routes/api.php
├── flutter_app/       # Application mobile Flutter
│   └── lib/
│       ├── core/      # Services, config, intercepteurs
│       ├── features/  # Modules par fonctionnalité
│       └── shared/    # Widgets réutilisables
└── README.md
```

---

## Paiements (MVP simulé)

| Méthode | Statut |
|---------|--------|
| Wave | Simulé |
| Orange Money | Simulé |
| Free Money | Simulé |
| Paiement à la livraison | Simulé |

Intégration réelle prévue via PayTech Sénégal.

---

## Roadmap

- [ ] Messagerie in-app acheteur/vendeur
- [ ] Notifications push (Firebase FCM)
- [ ] Paiement réel (PayTech / Wave API)
- [ ] Compression vidéo côté serveur (FFmpeg)
- [ ] Déploiement backend (Railway / Render)

---

## Sécurité

- Authentification par tokens Sanctum
- RBAC : rôles `user`, `admin`, `super_admin`
- Rate limiting sur tous les endpoints
- Validation stricte des uploads médias
- Headers HTTP sécurisés

---

Projet académique — Master Génie Logiciel