# QUINCH Mobile — Audit du dépôt et matrice de correspondance

Étape 1/7 (audit). Aucun fichier du dépôt n'a été modifié. Sources lues : `backend/routes/api.php`, `AuthController`, `ConversationController`, `ProductVideoController`, `GoogleAuthController`, `PublicConfigController`, `config/quinch.php`, `.env.example`, `frontend/src/app/app.routes.ts`, intercepteurs et services Angular.

Limite de cet audit : je n'ai lu que les contrôleurs et services listés. Les formes exactes des réponses JSON (pagination, champs des produits) et les règles de publication d'annonce restent à lire à l'étape 3, avant de figer les modèles Dart.

## 1. Constats clés

**Authentification**
- Laravel Sanctum, jeton Bearer (`Authorization: Bearer …`), émis par `auth/login`, `auth/register`, `auth/refresh`.
- Connexion : email + mot de passe uniquement. Inscription : `email`, `full_name`, `username`, `password` + `password_confirmation`, `accept_terms`. Pas de téléphone à l'inscription ; `PUT user/phone` existe (facultatif).
- Mot mot de passe : 8 à 72 caractères, 1 majuscule, 1 minuscule, 1 chiffre. Staff : 14 minimum.
- Récupération : `auth/forgot-password` (email) envoie un code à 6 chiffres par email, puis `auth/reset-password` (`email`, `otp`, `password`, `password_confirmation`). Tous les jetons sont révoqués ensuite. Angular n'a que l'écran « mot de passe oublié » ; le flux complet est à construire côté mobile.
- Jeton utilisateur sans expiration propre côté émission (le staff : 8 h). Angular rafraîchit après 7 jours via `auth/refresh`. À reproduire.
- 401 = session invalide → déconnexion. 403 avec `error: account_banned | account_suspended` → déconnexion. 429 sur login (trop de tentatives, message en français).
- Google : `POST auth/google` avec `id_token`. Le backend accepte des client IDs Android et iOS (`config/services.google`). Faisable avec `google_sign_in`, mais demande que les IDs soient configurés côté serveur (je ne peux pas le vérifier ni le modifier).
- `demo_otp` peut être renvoyé en mode démo : le mobile ne doit jamais s'y appuyer.

**Points où la mission et le code réel divergent (à trancher)**
1. **Vidéos 20 Mo** : le backend accepte jusqu'à **500 Mo** pour une vidéo de produit (`ProductVideoController`, `max:512000`). Les 20 Mo concernent les pièces jointes du chat. Je ne peux pas changer le backend. Option : limite de 20 Mo appliquée côté Flutter par choix produit (non sécurisante, juste de l'UX), ou aligner sur 500 Mo comme Angular. Décision à prendre.
2. **Notifications push natives : bloqué.** Aucun endpoint d'enregistrement de jeton d'appareil / FCM. `push_enabled` n'est qu'une préférence. Les notifications sont consultables dans l'app (`notifications`), rien de plus. Pas de push simulé.
3. **Temps réel : pas de websocket.** Angular interroge toutes les 8 s la conversation ouverte (`messages/since`) et toutes les 20 s la liste. Flutter fera pareil, uniquement au premier plan, présenté comme du rafraîchissement et non du temps réel.
4. **Fonctionnalités sous drapeaux serveur** (`feature:*`) : négociation, abonnements (follow), avis, badges, partage, audio du chat, fichiers du chat, collections de favoris. Défaut de `config/quinch.php` = désactivé, mais `.env.example` les met à `true`. Aucun endpoint public n'expose l'état des drapeaux. Le mobile devra traiter un 404 sur ces routes comme « fonction indisponible » et masquer l'écran, sans les considérer comme une erreur.
5. **Achat/panier/transactions : retirés** (Angular redirige, `purchases=false`). Pas d'écran mobile.
6. **Paiement des frais de publication vidéo (150 F) et Premium** : passent par Wave avec redirection vers `FRONTEND_URL`. En bêta (`QUINCH_BETA`), les deux sont gratuits/désactivés et `GET public-config` l'indique. Hors bêta, le retour de paiement vers l'app demande un lien profond que le backend ne fournit pas : **partiel/bloqué**, à confirmer en lisant `ProductController::publish` à l'étape 3.
7. **Une conversation par interlocuteur** : confirmé. `conversations/start` retrouve la conversation existante entre deux personnes dans les deux sens. Messages texte : 2000 caractères max (1000 pour le message initial).
8. **Pas d'appels audio/vidéo** : aucun endpoint. Le chat accepte des pièces jointes (20 Mo max, liste blanche : images, documents, audio, vidéos), ainsi que des messages vocaux (10 Mo), tous sous drapeaux `chat_file` / `chat_audio`.
9. **Classements** : réservés aux comptes Premium.
10. **Admin / modération** : le backend a un panneau complet (≈ 90 routes). Angular a un module `admin` entier. À mon avis hors périmètre de la première version mobile (outil de staff, jetons de 8 h, actions sensibles avec mot de passe admin). Je propose de ne livrer que le côté utilisateur de la modération (signaler un produit/utilisateur, contester une décision, support). **À confirmer.**

## 2. Matrice fonctionnalités

Statuts : OK = endpoint présent et lu ; À LIRE = endpoint présent, forme de réponse à vérifier à l'étape 3 ; DRAPEAU = dépend d'un feature flag serveur ; BLOQUÉ = pas d'API.

| Parcours | Écran Angular | Écran(s) Flutter | Endpoints | Statut |
|---|---|---|---|---|
| Inscription | `auth/register` | Inscription | `POST auth/register` | OK |
| Connexion | `auth/login` | Connexion | `POST auth/login`, `GET auth/me` | OK |
| Google | `auth/login` | Bouton Google | `POST auth/google`, `POST auth/google/update-username` | À LIRE (IDs côté serveur) |
| Mot de passe oublié | `auth/forgot-password` | Demande + code + nouveau mot de passe | `POST auth/forgot-password`, `POST auth/reset-password` | OK |
| Vérification email | (dans profil) | Écran de vérification | `POST auth/verify-email`, `POST auth/resend-verification` | À LIRE |
| Onboarding | `onboarding` | Onboarding | `POST user/preferences`, `POST user/policies` | À LIRE |
| Déconnexion / tout | `settings` | Paramètres | `POST auth/logout`, `POST auth/logout-all` | OK |
| Changer mot de passe | `settings` | Paramètres | `PUT auth/change-password` | OK |
| Supprimer le compte | `settings` | Paramètres (confirmation) | `POST/DELETE auth/delete-account` | OK |
| Export de données | `settings` | Paramètres | `GET users/export-data` | À LIRE |
| Pages légales | `legal/*` | Mentions, CGU, confidentialité | `GET legal/info` | À LIRE |
| Fil d'actualité (vidéos) | `videos` | Feed vertical | `GET products/feed` (`page`, `per_page`, `tab`), `GET feed/config` | À LIRE |
| Explorer / marketplace | `marketplace` | Explorer | `GET products`, `GET categories` | À LIRE (filtres, tri) |
| Recherche | `search` | Recherche | `GET search`, `search/suggestions`, `search/trending` | À LIRE |
| Détail produit | `product/:slug` | Détail | `GET products/{slug}`, `POST products/{id}/view` | À LIRE |
| J'aime, enregistrer, partager, signaler | détail / feed | Actions du feed | `POST products/{id}/like`, `/save`, `/share`, `/report` | OK (partage : DRAPEAU) |
| Favoris | `favorites` | Favoris | `GET favorites`, `POST favorites/toggle`, `GET favorites/count` | OK (collections : DRAPEAU) |
| Publier | `sell` | Assistant de publication | `POST products`, `POST products/upload-video`, `POST products/{id}/publish` | À LIRE (frais, photos 5 + 1 / 10 + 1) |
| Mes annonces | `profile` | Mon profil | `GET my-products`, `PUT/DELETE products/{id}` | OK |
| Profil public vendeur | `seller/:username` | Profil vendeur | `GET users/{username}/profile`, `/products` | À LIRE |
| Modifier profil | `profile/edit` | Édition | `PUT user/profile`, `POST user/upload-avatar`, `upload-cover`, `PUT user/phone` | OK |
| Abonnements | seller / profil | Suivre / abonnés | `POST follow/{id}`, `DELETE unfollow/{id}`, `my-followers`, `my-following` | DRAPEAU |
| Messagerie | `messages` | Liste + conversation | `GET conversations`, `POST conversations/start`, `GET {id}`, `POST {id}/messages`, `GET {id}/messages/since`, `DELETE` | OK |
| Pièces jointes / vocal | `messages` | Joindre, vocal | `POST {id}/file`, `POST {id}/audio` | DRAPEAU |
| Étiquette produit / disponibilité | `messages` | Dans la conversation | `POST {id}/tags`, `POST {id}/messages/{m}/availability` | À LIRE |
| Négociation | messages / détail | Proposer / répondre | `GET negotiations`, `POST propose`, `POST {id}/respond` | DRAPEAU |
| Notifications | `notifications` | Liste + détail | `GET notifications`, `unread-count`, `{id}`, `read`, `unread`, `read-all`, `DELETE`, `preferences` | OK |
| Contester une décision | notification détail | Formulaire | `POST notifications/{id}/contest`, `GET/POST moderation/appeals` | À LIRE |
| Annonces globales | bandeau | Bandeau | `GET notifications/announcements` | À LIRE |
| Bloquer / signaler un utilisateur | profil | Menu du profil | `POST users/{id}/block`, `unblock`, `GET users/blocked`, `POST users/{id}/report` | OK |
| Support | settings | Signaler un problème | `POST support/report` | OK |
| Premium | `premium` | Premium | `GET premium/plans`, `status`, `offer`, `POST premium/offer/apply`, `subscribe` | OK (paiement : voir §1.6) |
| Classements | `rankings` | Classements (Premium) | `GET rankings/*` | À LIRE |
| Badges / avis | profil / vendeur | Badges, avis | `GET users/{id}/badges`, `reviews`, `POST reviews` | DRAPEAU |
| Admin / modération staff | `admin/*` | — | `admin/*` | HORS PÉRIMÈTRE proposé |
| Push natif | — | — | aucun | BLOQUÉ |

## 3. Choix techniques proposés (étape 3, à valider)

- Environnements : `--dart-define=API_BASE_URL=…` (dev : émulateur Android `http://10.0.2.2:8000/api/v1` ; prod : `https://api.quinch.sn/api/v1`). Aucun secret serveur dans l'app. Trafic en clair autorisé seulement en debug.
- Jeton : `flutter_secure_storage` (Keystore Android). Rien d'autre de sensible en local.
- Réseau : `dio` avec intercepteurs (Bearer, `Accept: application/json`, délais, 401/403 → déconnexion).
- État : `flutter_riverpod`. Navigation : `go_router` avec gestion du retour Android.
- Vidéo : `video_player` (flux `videos/{id}/stream`) ; images : `cached_network_image` ; sélection : `image_picker` / `file_picker`.
- Les versions exactes seront choisies après `flutter pub get` pour vérifier la compatibilité avec Flutter 3.38.4 / Dart 3.10.3.

## 4. Décisions à prendre avant l'étape 2

1. Limite vidéo : 20 Mo (choix mobile) ou 500 Mo (comme le backend et Angular) ?
2. Admin/modération staff : exclu de la première version mobile ?
3. Les drapeaux serveur (négociation, abonnements, avis, badges, chat fichiers/vocal) sont-ils actifs en production ? Sans réponse, je les code avec masquage automatique sur 404.

## 5. Environnement

Flutter et Dart ne sont pas installés dans l'environnement où j'ai fait cet audit. Je ne peux donc pas exécuter `flutter pub get`, `flutter analyze`, `flutter test` ni `flutter build apk --release` ici. Je peux écrire le code et les tests ; les commandes devront être lancées chez vous, avec les sorties collées pour que je corrige. Aucun résultat de build ne sera annoncé sans exécution réelle.

## 6. Intégrité du backend

Aucun fichier du dossier `backend/`, `docker/` ou des `docker-compose*.yml` n'a été modifié : l'archive a seulement été extraite et lue.
