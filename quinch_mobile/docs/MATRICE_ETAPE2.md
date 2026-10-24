# QUINCH Mobile — Étape 2 : matrice complète

Complète `AUDIT_ET_MATRICE.md`. Rien n'est inventé : chaque endpoint listé existe dans `backend/routes/api.php` et/ou est appelé par un service Angular. Les formes de réponse JSON ne sont **pas** encore vérifiées (étape 3).

Légende :
- PRÉSENT : route lue dans le backend.
- DRAPEAU : route sous `feature:*`, peut être absente selon le serveur (voir §2).
- LIMITÉ : fonctionne seulement en partie (voir note).
- EXCLU : hors première version, par décision.
- BLOQUÉ : aucune API.

## 1. Décisions appliquées

| Sujet | Décision | Source dans le code |
|---|---|---|
| Vidéo de produit | Limite dure **500 Mo** (backend). Avertissement clair dès **200 Mo** (limite qu'applique Angular) : envoi long, connexion stable conseillée. Erreurs serveur affichées telles quelles. | `ProductVideoController` `max:512000` ; `sell.component.ts` bloque au-dessus de 200 Mo |
| Pièces jointes du chat | 20 Mo max, comme le backend et Angular | `ConversationController::sendFile` `max:20480` |
| Images de produit | 5 Mo max côté serveur. Angular compresse sous 4,8 Mo avant envoi : Flutter fera pareil | `sell.component.ts` `MAX_IMAGE_BYTES` |
| Admin / modération staff | Exclu de la v1 | — |
| Signalement, support, contestation | Inclus (APIs présentes) | voir §3 |
| Notifications | Consultables dans l'app uniquement. Aucune mention de push natif | pas d'endpoint d'appareil |
| Paiements | Pilotés par `GET public-config`. Aucun paiement simulé | voir §4 |
| Backend | Intact | — |

À noter : sur les vidéos, Angular (200 Mo) et le backend (500 Mo) ne sont pas d'accord. J'ai choisi de suivre le backend comme limite dure et d'ajouter l'avertissement à 200 Mo, pour ne pas inventer de limite. Dites-moi si vous préférez bloquer à 200 Mo comme Angular.

## 2. Disponibilité des fonctionnalités (drapeaux serveur)

**Ce que dit le code**
- Les drapeaux sont lus dans `config('quinch.features.*')` puis **remplacés à chaud** par les réglages enregistrés par l'admin (`AppServiceProvider`). Ils peuvent donc changer sans redéploiement.
- Aucune route publique ou utilisateur n'expose leur état. Seul le panneau admin les lit.
- Valeurs par défaut du code : tout désactivé. `.env.example` : tout activé sauf `purchases`. L'état réel en production n'est pas connu.
- Quand un drapeau est coupé, le middleware fait `abort(404)`, sans message.

**Comment distinguer, autant que possible** (Laravel 12, API en JSON) :

| Réponse | Sens probable |
|---|---|
| 404 avec `message` vide, sur une route sous drapeau | fonctionnalité désactivée |
| 404 avec `message` « The route … could not be found. » | route inexistante : URL erronée ou version de l'API différente |
| 404 « No query results for model… » ou « Ressource introuvable. » | ressource absente (produit, utilisateur supprimé) |
| 403 avec `message` « …sera bientôt disponible » | envoi de fichier/audio non activé (route `conversations/{id}/file`) |
| 503 avec `error: maintenance` | maintenance serveur |

C'est une règle **déduite du code, pas testée** sur un serveur en marche. Elle sera isolée dans une seule classe, couverte par des tests unitaires sur des réponses simulées, et je documenterai le résultat réel dès que vous aurez un serveur de test.

**Comportement prévu dans l'app :** un service de disponibilité garde pour chaque fonction l'état « inconnu / disponible / désactivé ». Sondes sans effet de bord, uniquement sur des routes existantes : `GET negotiations`, `GET badges/definitions`, `GET favorites/collections`, `GET my-followers`. Pour avis, partage et vocal, la détection se fait au premier usage. Une fonction désactivée est masquée, sans message d'erreur ni faux contenu. Une erreur de configuration (route inexistante) est journalisée sans donnée sensible et signalée comme « indisponible » à l'utilisateur.

| Drapeau | Fonction côté utilisateur | Routes concernées |
|---|---|---|
| `negotiation` | proposer / répondre à une offre | `negotiations`, `negotiations/propose`, `negotiations/{id}/respond` |
| `follow` | abonnements | `follow/{id}`, `unfollow/{id}`, `my-followers`, `my-following`, `my-friends`, `users/{id}/followers`, `following`, `follow-counts`, `is-friend`, `products/friends-feed` |
| `reviews` | avis vendeur | `reviews`, `reviews/{id}/respond`, `users/{id}/reviews` |
| `badges` | badges | `my-badges`, `my-customers`, `users/{id}/badges`, `badges/definitions`, `users/{id}/loyalty-badge` |
| `sharing` | partage | `shares/track`, `products/{slug}/share-data` |
| `chat_audio` | message vocal | `conversations/{id}/audio` (404) |
| `chat_file` | documents et vidéos en pièce jointe | `conversations/{id}/file` (403 avec message) ; **les images restent toujours permises** |
| `favorites_collections` | collections de favoris | `favorites/collections` |
| `purchases` | panier, transactions | **EXCLU** (QUINCH ne fait que la mise en relation) |

## 3. Matrice par écran

### Compte et accès

| Angular | Écran Flutter | Endpoints | Statut / notes |
|---|---|---|---|
| `auth/login` | Connexion | `POST auth/login`, `GET auth/me` | PRÉSENT. Gérer 422 (identifiants), 429 (trop de tentatives), 403 `account_banned` / `account_suspended` |
| `auth/register` | Inscription (email, nom, pseudo, mot de passe + confirmation, CGU) | `POST auth/register` | PRÉSENT. Téléphone non demandé |
| `auth/forgot-password` | Mot de passe oublié en 2 temps : email, puis code + nouveau mot de passe | `POST auth/forgot-password`, `POST auth/reset-password` | PRÉSENT. Réponse identique que le compte existe ou non. Ne jamais lire `demo_otp` |
| Google (login) | Bouton Google | `POST auth/google`, `POST auth/google/update-username` | LIMITÉ : demande un client ID Android côté serveur (non vérifiable ici). Livré derrière une configuration ; masqué si absente |
| `onboarding` | Onboarding | `POST user/preferences`, `POST user/policies` | PRÉSENT |
| Vérif. email | Écran de confirmation | `POST auth/verify-email`, `POST auth/resend-verification` | PRÉSENT. 403 `email_not_verified` sur Premium et offre : proposer la confirmation |
| `settings` | Paramètres : mot de passe, déconnexion, supprimer le compte (avec confirmation), préférences de notifications, export | `PUT auth/change-password`, `POST auth/logout`, `POST auth/logout-all`, `POST auth/delete-account`, `GET/PUT notifications/preferences`, `GET users/export-data` | PRÉSENT |
| `legal/*` | Mentions, CGU, confidentialité | `GET legal/info` | PRÉSENT. Contenu des textes à vérifier à l'étape 3 |
| Session | — | `POST auth/refresh` | PRÉSENT. Angular rafraîchit après 7 jours ; staff 8 h (sans objet, admin exclu) |

### Découverte

| Angular | Écran Flutter | Endpoints | Statut / notes |
|---|---|---|---|
| `feed` / `videos` | Feed vidéo vertical : seuls les produits avec vidéo | `GET products/feed` (`page`, `per_page`=10, `tab`), `GET feed/config` (bannières, bandeau, maintenance) | PRÉSENT. Onglet `following` dépend de `follow`. Flux vidéo : `GET videos/{id}/stream` (public) |
| `marketplace` | Explorer : tous les produits et services | `GET products` (`type`, `condition`, `min_price`, `max_price`, `sort_by`=popular/recent, catégorie, ville), `GET categories` | PRÉSENT. Noms exacts des paramètres à confirmer à l'étape 3 |
| `search` | Recherche, suggestions, tendances | `GET search?q=`, `search/suggestions`, `search/trending` | PRÉSENT |
| `product/:slug` | Détail produit | `GET products/{slug}`, `POST products/{id}/view` | PRÉSENT. Vendeur cliquable vers son profil |
| Actions produit | J'aime, enregistrer, partager, signaler | `POST products/{id}/like`, `/save`, `/share`, `/report` ; `GET my-likes` | PRÉSENT. Partage externe : DRAPEAU `sharing` |
| `favorites` | Favoris | `GET favorites`, `POST favorites/toggle`, `GET favorites/count` | PRÉSENT. Collections : DRAPEAU |
| Prix | Affichés en FCFA, **jamais calculés côté client** | — | Règle de sécurité |

### Vendeur et profil

| Angular | Écran Flutter | Endpoints | Statut / notes |
|---|---|---|---|
| `sell` | Assistant de publication : type produit/service, catégorie, prix, photos (1 couverture + 5 gratuit / 10 premium), vidéo | `POST products` (multipart, `image_files[]`), `POST products/upload-video`, `POST products/{id}/publish`, `GET categories`, `GET public-config` | PRÉSENT. Retouches photo/texte d'Angular : repris seulement en recadrage et compression pour la v1 |
| Frais de publication | Message selon `public-config` | `GET public-config` (`beta`, `listing_fee_with_video`) | Bêta : 0 F. Hors bêta : voir §4 |
| `profile` | Mon profil, mes annonces | `GET user/profile`, `GET my-products`, `PUT/DELETE products/{id}` | PRÉSENT |
| `profile/edit` | Édition : infos, avatar, couverture, téléphone facultatif | `PUT user/profile`, `POST user/upload-avatar`, `POST user/upload-cover`, `PUT user/phone` | PRÉSENT |
| `seller/:username` | Profil vendeur | `GET users/{username}/profile`, `GET users/{username}/products` | PRÉSENT. Abonnés, avis, badges : DRAPEAUX |
| Blocage, signalement | Menu du profil | `POST users/{id}/block`, `unblock`, `GET users/blocked`, `POST users/{id}/report` | PRÉSENT |
| `rankings` | Classements | `GET rankings/sellers`, `products`, `profiles`, `followers`, `preferences` | PRÉSENT, réservé aux Premium (réponse d'erreur à lire à l'étape 3) |

### Messagerie et notifications

| Angular | Écran Flutter | Endpoints | Statut / notes |
|---|---|---|---|
| `messages` | Liste des conversations, conversation | `GET conversations`, `POST conversations/start`, `GET conversations/{id}`, `POST {id}/messages`, `GET {id}/messages/since`, `DELETE {id}`, `DELETE {id}/messages/{m}`, `POST conversations/bulk-delete` | PRÉSENT. Une conversation par paire. Texte 2000 caractères max. Rafraîchissement par interrogation (8 s / 20 s) **au premier plan seulement** |
| Joindre | Images, puis documents/vidéos/audio | `POST {id}/file` | Images : toujours. Le reste : DRAPEAU `chat_file`. 20 Mo max |
| Vocal | Enregistrement | `POST {id}/audio` (10 Mo) | DRAPEAU `chat_audio` |
| Produit dans le chat | Étiquette produit, réponse de disponibilité | `POST {id}/tags`, `POST {id}/messages/{m}/availability` | PRÉSENT |
| Appels audio / vidéo | — | aucun | BLOQUÉ par conception : non proposé |
| Négociation | Offres dans le chat / détail | `GET negotiations`, `POST negotiations/propose`, `POST negotiations/{id}/respond` | DRAPEAU |
| `notifications` | Liste, détail, lu/non lu, tout lire, supprimer, compteur | `GET notifications`, `GET notifications/{id}`, `POST {id}/read`, `/unread`, `POST read-all`, `DELETE {id}`, `GET unread-count`, `GET announcements` | PRÉSENT. Un clic sur une notification d'un utilisateur ouvre sa conversation (comme Angular, à confirmer à l'étape 3) |
| Contestation | Formulaire depuis une notification de retrait | `POST notifications/{id}/contest`, `GET moderation/appeals/mine`, `POST moderation/appeals` | PRÉSENT |
| Support | Signaler un problème | `POST support/report` | PRÉSENT |
| Push natif | — | aucun | BLOQUÉ. Non annoncé dans l'app ni la doc utilisateur |

### Premium

| Angular | Écran Flutter | Endpoints | Statut / notes |
|---|---|---|---|
| `premium` | Offres, statut, offre de lancement | `GET premium/plans`, `GET premium/status`, `GET premium/offer`, `POST premium/offer/apply` | PRÉSENT. Email vérifié requis pour postuler |
| Abonnement payant | Bouton d'abonnement | `POST premium/subscribe` | LIMITÉ : voir §4 |

## 4. Paiements

- Source de vérité : `GET public-config` → `beta`, `listing_fee_with_video`, `premium_payments`, `premium_offer_slots`.
- **Bêta** (`beta: true`) : publication vidéo gratuite, Premium sans paiement. L'app affiche « paiement non actif pour la version bêta » (message déjà décidé côté produit) et ne démarre aucun paiement.
- **Hors bêta** : `premium/subscribe` et les frais de publication passent par Wave et reviennent vers `FRONTEND_URL` (success/error). Le backend ne fournit aucun lien de retour vers une app mobile. Ce que je ferai : ouvrir la page de paiement fournie par le serveur dans le navigateur, puis, au retour dans l'app, relire `premium/status` ou l'état du produit auprès du serveur avant d'afficher quoi que ce soit. Ce que je ne ferai pas : afficher « paiement réussi » sur la foi d'un retour de navigateur. Le parcours complet hors bêta reste **à valider** après lecture de `PremiumController` et `ProductController::publish` à l'étape 3.
- Orange Money, panier, transactions, webhooks : EXCLUS.

## 5. Exclus de la v1 (présents dans Angular ou l'API)

Tout `admin/*` (utilisateurs, produits, modération vidéo, signalements, fraude, finances, badges, équipe, bannières, réglages, notifications de masse, sécurité), `cart/*`, `transactions/*`, `webhooks/*`, `negotiations` côté staff.

## 6. Incertitudes restantes

1. État réel des drapeaux en production : inconnu, détecté à l'exécution.
2. Règle de distinction des 404 : déduite du code, jamais testée sur un serveur.
3. Connexion Google : dépend d'un client ID Android configuré côté serveur.
4. Formes JSON, noms exacts des filtres, règles d'erreur des classements, parcours de paiement hors bêta : étape 3.
5. Aucune commande Flutter n'a été exécutée (Flutter absent de mon environnement).

## 7. Intégrité du backend

Aucun fichier de `backend/`, `docker/` ni `docker-compose*.yml` modifié. Fichiers créés à cette étape : `quinch_mobile/docs/MATRICE_ETAPE2.md` (et `AUDIT_ET_MATRICE.md` à l'étape 1).
