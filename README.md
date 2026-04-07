# QUINCH - Social Commerce Video Platform

Plateforme de social commerce video pour le marche senegalais. Fusion de TikTok et Facebook Marketplace.

## Architecture

| Couche | Technologie | Repertoire |
|--------|-------------|------------|
| Backend API | Laravel 12 + Sanctum | `backend/` |
| Frontend SPA | Angular 20 | `frontend/` |
| Base de donnees | MySQL 8 (XAMPP) | - |
| Stockage | Local filesystem | `backend/storage/app/public/` |

## Types de comptes

| Role | Description |
|------|-------------|
| **Client** (`user`) | Peut acheter ET vendre des produits/services |
| **Admin** (`admin` / `super_admin`) | Gestion de la plateforme, moderation, metriques |

> Il n'y a pas de compte "vendeur" separe. Tout client peut publier des produits via le bouton **+** de la navigation.

## Prerequis

- **XAMPP** avec Apache + MySQL actifs
- **PHP 8.2+** (inclus avec XAMPP)
- **Composer** (gestionnaire de paquets PHP)
- **Node.js 18+** et **npm**
- **Angular CLI** (`npm install -g @angular/cli`)

## Installation

### 1. Backend (Laravel)

```bash
cd backend

# Installer les dependances
composer install

# Copier le fichier .env (deja configure)
# Verifier que la base de donnees "quinch" existe dans phpMyAdmin

# Lancer les migrations + donnees de demo
php artisan migrate:fresh --seed

# Lien symbolique pour le stockage public
php artisan storage:link
```

### 2. Frontend (Angular)

```bash
cd frontend

# Installer les dependances
npm install

# Lancer le serveur de developpement
ng serve
```

### 3. Acces

| Service | URL |
|---------|-----|
| Frontend Angular | http://localhost:4200 |
| Backend API | http://localhost/QUINCH/backend/public/api/v1 |
| phpMyAdmin | http://localhost/phpmyadmin |

## Comptes de demonstration

| Compte | Telephone | Mot de passe |
|--------|-----------|-------------|
| **Admin** | +221770000001 | password |
| **Client 1** | +221770000010 | password |
| **Client 2** | +221770000011 | password |

## API Endpoints

### Authentification
- `POST /api/v1/auth/register` - Inscription
- `POST /api/v1/auth/login` - Connexion
- `POST /api/v1/auth/logout` - Deconnexion
- `GET /api/v1/auth/me` - Profil connecte

### Produits
- `GET /api/v1/feed` - Fil d'actualite video (style TikTok)
- `GET /api/v1/products` - Liste des produits
- `POST /api/v1/products` - Creer un produit (authentifie)
- `GET /api/v1/products/{slug}` - Detail produit
- `PUT /api/v1/products/{slug}` - Modifier
- `DELETE /api/v1/products/{slug}` - Supprimer

### Videos
- `POST /api/v1/videos/upload` - Upload de video produit

### Interactions
- `POST /api/v1/products/{id}/view` - Enregistrer une vue
- `POST /api/v1/products/{id}/like` - Liker/Unliker
- `POST /api/v1/products/{id}/share` - Partager
- `POST /api/v1/products/{id}/save` - Sauvegarder

### Transactions
- `POST /api/v1/transactions` - Initier un paiement
- `GET /api/v1/transactions` - Historique
- `POST /api/v1/transactions/{id}/confirm` - Confirmer

### Administration
- `GET /api/v1/admin/metrics` - Metriques tableau de bord
- `GET /api/v1/admin/users` - Gestion utilisateurs
- `GET /api/v1/admin/moderation/videos` - Moderation contenu

## Paiements supportes

| Methode | Statut MVP |
|---------|-----------|
| Orange Money | Simule |
| Wave | Simule |
| Free Money | Simule |
| Paiement a la livraison | Simule |

## Fonctionnalites

- Feed video vertical style TikTok
- Achat/vente pour tout client
- Bouton **+** central pour publier
- Systeme de trust score
- Onboarding immersif (categories + localisation)
- Dashboard admin avec metriques
- Design responsive mobile-first
- Couleurs inspirees du Senegal
- Securite : headers HTTP, detection de fraude, RBAC

## Structure du projet

```
QUINCH/
├── backend/                    # Laravel 12 API
│   ├── app/
│   │   ├── Http/Controllers/Api/V1/   # Controllers REST
│   │   ├── Models/                     # Eloquent models
│   │   ├── Policies/                   # Authorization
│   │   └── Services/                   # Business logic
│   ├── database/
│   │   ├── migrations/                 # Schema
│   │   └── seeders/                    # Demo data
│   └── routes/api.php                  # API routes
├── frontend/                   # Angular 20 SPA
│   └── src/
│       ├── app/
│       │   ├── core/                   # Services, guards, interceptors
│       │   └── pages/                  # Components par page
│       ├── environments/               # Config dev/prod
│       └── styles.scss                 # Design system QUINCH
└── README.md
```
