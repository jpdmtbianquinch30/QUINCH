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
PUT  /auth/change-password     (5/min ; déconnecte les autres appareils)
POST /auth/delete-account      (5/min)
DELETE /auth/delete-account    (5/min)
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
GET  /products/{slug}          (404 si l'annonce n'est pas publiée, sauf auteur et staff)
GET  /users/{username}/profile (sans chiffre d'affaires ; 404 si le compte est banni ou supprimé)
GET  /users/{username}/products
```

## Vidéo

```text
GET /videos/{videoId}/stream
GET /videos/{videoId}/thumbnail
```

## Utilisateur

```text
GET/PUT /user/profile       (changer `email` exige `current_password` ; 20 requêtes/min)
POST    /user/preferences
POST    /user/policies
POST    /user/upload-avatar
POST    /user/upload-cover
PUT     /user/phone
GET     /users/blocked
POST    /users/{user}/block      (appliqué dans les deux sens : conversations, messages, suivis, négociations, avis)
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

## Erreurs

Un identifiant mal formé (`/users/abc/badges`) renvoie **404**, une valeur invalide ou trop longue **422** ; l'API ne
renvoie plus de 500 pour une entrée utilisateur. Corps JSON : `{ "message": "…" }`.

## Social

Avis (`POST /reviews`) : réservés aux acheteurs d'une transaction finalisée chez ce vendeur, ou aux utilisateurs lui
ayant déjà écrit (`422 review_requires_interaction` sinon). Une `video_id` jointe à une annonce doit appartenir à son auteur.

Le backend expose les flux de follows, avis, badges, favoris, partages et classements via leurs contrôleurs dédiés. Les fonctionnalités sont protégées par les feature flags lorsqu'elles sont optionnelles.

## Messagerie

Le domaine conversationnel est géré par `ConversationController`, avec messages et rattachement de produits via le service de tagging.

## Premium / paiements

Les endpoints Premium et transactions doivent être utilisés uniquement pour les fonctionnalités payantes de QUINCH. Les anciennes routes panier/achat entre utilisateurs sont désactivées par défaut et certaines anciennes URLs redirigent vers la marketplace.

## Webhook

```text
POST /webhooks/wave           (aiguillage selon client_reference : premium_… / listing_… / UUID de commande)
POST /webhooks/orange-money   (signature HMAC `X-Orange-Signature`)
```

Ce endpoint est externe à l'authentification utilisateur et doit vérifier la signature Wave, l'idempotence et la cohérence de la transaction.

## Administration

Les routes admin sont regroupées derrière :

- authentification ;
- rôle ;
- permissions spécifiques.

Domaines : utilisateurs, staff, produits, catégories, modération, transactions, Premium, badges, avis, notifications, paramètres et sécurité.
