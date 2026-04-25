
# QUINCH — Social commerce vidéo pour le Sénégal

> Plateforme mobile de commerce social inspirée de TikTok et Facebook Marketplace, pensée pour le marché sénégalais et ouest-africain.

---

## Stack technique

| Couche | Technologie |
|--------|-------------|
| Application mobile | Flutter (iOS + Android) |
| Backend API | Laravel 12 + Sanctum |
| Base de données | MySQL 8 |
| Stockage médias | Cloudflare R2 (prod) / Local (dev) |

---

## Prérequis

- Flutter 3.x + Dart 3.x
- PHP 8.2+ avec Composer
- MySQL 8 (XAMPP en développement)
- Node.js 18+ (outils dev uniquement)

---

## Installation

### 1. Backend (Laravel)

```bash
cd backend
composer install
cp .env.example .env
php artisan key:generate

# Configurer la base de données dans .env
# DB_DATABASE=quinch

php artisan migrate:fresh --seed
php artisan storage:link
php artisan serve
```

### 2. Application Flutter

```bash
cd flutter_app
flutter pub get

# Configurer l'URL de l'API dans lib/core/config/app_config.dart
# baseUrl: 'http://10.0.2.2:8000/api/v1' (émulateur Android)
# baseUrl: 'http://localhost:8000/api/v1' (iOS simulateur)

flutter run
```

---

## Comptes de démonstration

| Rôle | Téléphone |
|------|-----------|
| Admin | +221 77 000 00 01 |
| Client 1 | +221 77 000 00 10 |
| Client 2 | +221 77 000 00 11 |

> Les mots de passe de démo sont dans le fichier `.env.example`.

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