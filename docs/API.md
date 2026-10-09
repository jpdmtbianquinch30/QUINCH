# API QUINCH — vue fonctionnelle

API versionnée sous `/api/v1`.

## Authentification

### Public

```text
POST /auth/register          (accept_terms obligatoire : consentement aux conditions)
POST /auth/login
POST /auth/forgot-password
POST /auth/reset-password
POST /auth/google            (nouveau compte : accept_terms obligatoire, sinon 422 `terms_required`)
GET  /legal/info             (éditeur, contact, hébergeur, versions des textes, durées de conservation)
```

### Authentifié

```text
POST /auth/logout
POST /auth/logout-all
POST /auth/refresh
GET  /auth/me
PUT  /auth/change-password
POST /auth/delete-account
DELETE /auth/delete-account
```

## Public marketplace

```text
GET  /categories
GET  /products
GET  /products/feed
GET  /products/active-sellers
GET  /search
GET  /search/suggestions
GET  /search/trending
GET  /products/{slug}
GET  /users/{username}/profile
GET  /users/{username}/products
```

## Vidéo

```text
GET /videos/{videoId}/stream
GET /videos/{videoId}/thumbnail
```

## Utilisateur

```text
GET/PUT /user/profile
POST    /user/preferences
POST    /user/policies
POST    /user/upload-avatar
POST    /user/upload-cover
PUT     /user/phone
GET     /users/blocked
POST    /users/{user}/block
POST    /users/{user}/unblock
GET     /users/export-data     (téléchargement JSON complet, 5 demandes/heure)
```

## Produits

```text
POST   /products
PUT    /products/{product}
DELETE /products/{product}
POST   /products/upload-video
POST   /products/{product}/like
POST   /products/{product}/share
POST   /products/{product}/save
POST   /products/{product}/report
POST   /products/{product}/publish
GET    /my-products
GET    /my-likes
```

## Social

Le backend expose les flux de follows, avis, badges, favoris, partages et classements via leurs contrôleurs dédiés. Les fonctionnalités sont protégées par les feature flags lorsqu'elles sont optionnelles.

## Messagerie

Le domaine conversationnel est géré par `ConversationController`, avec messages et rattachement de produits via le service de tagging.

## Premium / paiements

Les endpoints Premium et transactions doivent être utilisés uniquement pour les fonctionnalités payantes de QUINCH. Les anciennes routes panier/achat entre utilisateurs sont désactivées par défaut et certaines anciennes URLs redirigent vers la marketplace.

## Webhook

```text
POST /webhooks/wave
```

Ce endpoint est externe à l'authentification utilisateur et doit vérifier la signature Wave, l'idempotence et la cohérence de la transaction.

## Administration

Les routes admin sont regroupées derrière :

- authentification ;
- rôle ;
- permissions spécifiques.

Domaines : utilisateurs, staff, produits, catégories, modération, transactions, Premium, badges, avis, notifications, paramètres et sécurité.
