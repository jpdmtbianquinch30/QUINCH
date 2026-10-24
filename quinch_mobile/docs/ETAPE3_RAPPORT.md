# QUINCH Mobile — Étape 3 : contrats API vérifiés

Méthode : lecture du code du dépôt (`QUINCH-main.zip`). **Aucune réponse n'a été obtenue d'un serveur en marche.** Tout ce qui suit vient du code ; ce qui dépend du comportement réel est listé au §8. Flutter n'est pas exécutable dans mon environnement : les fichiers Dart ci-dessous sont **écrits mais non compilés ni testés**.

## 1. Corrections aux étapes 1 et 2

1. **La vérification d'email est cassée côté backend.** `routes/api.php` déclare `POST auth/verify-email` et `POST auth/resend-verification` vers `AuthController::verifyEmail` et `::resendVerification`. Ces deux méthodes n'existent ni dans `AuthController` ni ailleurs dans `app/` ou `routes/`. Angular ne les appelle pas. J'avais écrit « PRÉSENT » : c'était faux.
   - `email_verified_at` n'est renseigné que par la connexion Google ou par une réinitialisation de mot de passe réussie (`AuthController::resetPassword`).
   - `premium/subscribe` et `premium/offer/apply` exigent un email vérifié (`email.verified`, 403 `email_not_verified`). Un compte créé par email puis jamais réinitialisé ne peut donc ni s'abonner ni postuler à l'offre, y compris en bêta où l'offre est la seule voie vers Premium.
   - Je ne corrige pas le backend. À vous de décider d'ajouter ces méthodes. Côté app : pas d'écran « confirmer mon email », pas de bouton « renvoyer » ; j'affiche le message du serveur.
2. **Filtres de l'Explorer : Angular et backend ne s'accordent pas.** Angular envoie `min_price`, `max_price`, `condition` à `GET products`. Le backend lit `price_min`, `price_max` et ignore `condition`. Les filtres de prix d'Angular sont donc sans effet sur l'Explorer. Flutter enverra `price_min` / `price_max` et ne proposera pas de filtre « état » dans l'Explorer.
3. **Le tri n'a pas le même nom partout.** Explorer : `sort_by` = `recent` | `popular` | `price_asc` | `price_desc`. Feed : `sort` = `recent` | `popular` | `day`. Le feed lit `min_price` / `max_price`.
4. **Messages récents : le paramètre s'appelle `after`**, pas `since` (`GET conversations/{id}/messages/since?after=<created_at>`). Sans `after`, le serveur renvoie les 50 derniers messages.
5. **Une seule session par compte.** `login` supprime tous les jetons existants ; `refresh` remplace le jeton ; changement de mot de passe ou d'email révoque les autres. Se connecter sur le web déconnecte le mobile, et inversement. L'app doit traiter un 401 comme « session expirée » avec un message clair.
6. **Explorer et « aimé / enregistré ».** `GET products` est une route publique et lit l'utilisateur avec `$request->user()` ; le guard par défaut est `web` (session, `config/auth.php`). Avec un simple jeton Bearer, `is_liked` et `is_saved` y sont donc **probablement toujours faux**. Le feed et le détail utilisent `user('sanctum')` et sont corrects. Conséquence : dans l'Explorer, l'app n'affiche pas d'état « aimé / enregistré » fiable ; elle l'obtient du détail ou des listes dédiées. À confirmer sur un serveur.

## 2. Formes JSON vérifiées (lues dans le code)

Statut : **Lu** = structure lue dans le contrôleur ; **Brut** = modèle Eloquent sérialisé tel quel (tous les attributs non cachés, la liste exacte dépend du schéma).

### Authentification et profil

| Endpoint | Entrée | Sortie | Statut |
|---|---|---|---|
| `POST auth/register` | `email`, `full_name`, `username`, `password`, `password_confirmation`, `accept_terms` (true) | 201 `{message, user, token}` | Lu |
| `POST auth/login` | `email`, `password` | `{message, user, token}` ; 422 `errors.email` si identifiants faux ; **429** avec `errors.email` si trop de tentatives | Lu |
| `POST auth/forgot-password` | `email` | `{message}` toujours (+ `demo_otp` en mode démo, ignoré) ; 429 `{error: otp_rate_limited, retry_after}` | Lu |
| `POST auth/reset-password` | `email`, `otp` (6 caractères), `password`, `password_confirmation` | `{message}` ; 422 `{error: invalid_otp}` | Lu |
| `GET auth/me` | — | `{user}` | Lu |
| `POST auth/refresh` | — | `{token, user}` | Lu |
| `PUT auth/change-password` | `current_password`, `new_password`, `new_password_confirmation` | `{message}` ; 422 si mot de passe actuel faux | Lu |
| `POST auth/delete-account` | `password` | `{message}` (anonymisation) | Lu |
| `GET user/profile` | — | `{user (brut), stats:{products_count, sales_count, purchases_count, total_earned}}` | Lu / Brut |
| `PUT user/profile` | `username`, `full_name`, `email`, `bio` (≤500), `website`, `city`, `region`, `current_password` (requis si l'email change) | `{message, user (brut)}` ; changer d'email dé-vérifie et coupe les autres sessions | Lu / Brut |
| `PUT user/phone` | `phone_number` = `+221` + 9 chiffres, ou null | `{message, user (brut)}` ; 422 `{error: phone_taken}` | Lu |
| `POST user/upload-avatar` | `avatar` jpeg/png/webp ≤ 5 Mo | `{message, avatar_url, user}` | Lu |
| `POST user/upload-cover` | `cover` jpeg/png/webp ≤ 10 Mo | `{message, …}` | Lu |
| `GET users/{username}/profile` | — | `{user, stats, badges, is_following}` | Lu |

**Deux formes d'utilisateur** : `formatUser` (login/register/refresh/me : `email_verified` bool, `is_premium` calculé) et modèle brut (`user/profile` et mises à jour : `email_verified_at`, `is_premium` = colonne). `AppUser.fromJson` gère les deux.

### Produits

| Endpoint | Paramètres / entrée | Sortie | Statut |
|---|---|---|---|
| `GET products/feed` (public) | `tab` (foryou/following), `page`, `per_page` (défaut 10, borné à 30), `q`, `type`, `category` (uuid), `city`, `min_price`, `max_price`, `sort`, `exclude_ids` (uuid, 200 max) | Paginateur Laravel ; chaque élément : `id, type, title, slug, description (120 car.), price, formatted_price, currency, condition, is_negotiable, stock_quantity, view_count, like_count, share_count, is_liked, is_saved, save_count, review_count, poster, payment_methods, delivery_option, delivery_fee, video:{id,url,thumbnail,duration,format}, images[], metadata, category:{id,name,icon}, seller:{…}, created_at` | Lu |
| `GET products` (Explorer, public) | `q`, `category`, `type`, `seller_id`, `price_min`, `price_max`, `sort_by`, `page`, `per_page` (défaut 20, max 50) | `{data[], current_page, last_page, total, per_page}` ; éléments : comme le feed mais `category` = **texte**, plus `category_id`, `thumbnail` | Lu |
| `GET products/{slug}` (public) | — | `{product (brut), seller:{…}, is_liked, is_saved}` ; 404 `{message: "Annonce introuvable."}` | Lu / Brut |
| `GET my-products` | `page` (20/page) | Paginateur d'annonces **brutes** (avec `category`, `video`) | Lu / Brut |
| `POST products` | multipart. Requis : `title` (≤200), `category_id`, `price` (≥0), et au moins un de `poster_file`, `image_files[]`, `video_id`. Optionnels : `description` (≤5000), `type`, `condition` (new/like_new/good/fair), `is_negotiable`, `stock_quantity`, `currency` (XOF/EUR/USD), `intent` (draft/publish), `payment_methods` (JSON texte), `delivery_option` (fixed/contact), `delivery_fee`, champs de service | 201 `{message, product}` ; si frais dus : `{message, product, payment_url, fee}` | Lu |
| `POST products/upload-video` | `video` (mp4, quicktime, avi, webm ; **max 512 000 Ko**), `source` (upload/camera), `width`, `height` | `{message, video}` ; la vidéo est modérée après coup | Lu |
| `POST products/{id}/publish` | — (brouillon seulement) | 200 `{message, product}` ou `{message, product, payment_url, fee}` | Lu |
| `POST products/{id}/like` | — | `{liked, like_count}` | Lu |
| `POST products/{id}/save` | — | `{saved}` | Lu |
| `POST products/{id}/report` | `reason` ∈ fraud, inappropriate, counterfeit, spam, other ; `description` | `{message}` ; 409 si déjà signalé | Lu |
| `GET search?q=` (public) | — | `{products[], users[]}` (10 max chacun, sans pagination) | Lu |
| `GET search/suggestions` | — | `{suggestions[], sellers[]}` | Lu |
| `GET favorites` | `page` (20) | Paginateur de `FavoriteItem` avec `product`, `collection` | Lu / Brut |
| `POST favorites/toggle` | `product_id`, `collection_id?` | `{favorited, message, favorites_count}` | Lu |
| `GET categories` (public) | — | `{categories:[{id,name,icon,…,children[]}]}` | Lu |

Limites de photos : 1 couverture + 5 supplémentaires (gratuit) ou 10 (Premium) ; 5 Mo par image.

### Messagerie

| Endpoint | Entrée | Sortie | Statut |
|---|---|---|---|
| `GET conversations` | `page` (20) | Paginateur ; chaque élément : conversation + `other_user` (avec `is_friend`, `is_premium`, `badges`), `unread_count`, `last_message`, `product:{id,title,slug,price}` | Lu |
| `POST conversations/start` | `seller_id`, `product_id?`, `message?` (≤1000) | `{conversation, message}` ; **retrouve la conversation existante** entre les deux personnes, quel que soit le sens ; 403 si l'autre n'est pas joignable ; 422 si soi-même | Lu |
| `GET conversations/{id}` | — | `{conversation}` avec `messages` = **50 derniers seulement**, `other_user`, `product_tags` ; marque comme lus | Lu |
| `GET conversations/{id}/messages/since` | `after` (created_at) | `{messages[], other_user}` ; marque comme lus | Lu |
| `POST conversations/{id}/messages` | `body` (≤2000), `type?` (text/image/offer/audio) | `{message}` ; `metadata` toujours ignoré côté serveur | Lu |
| `POST conversations/{id}/file` | `file` ≤ 20 Mo, extensions : jpg, jpeg, png, webp, pdf, doc(x), xls(x), ppt(x), txt, csv, mp3, wav, ogg, m4a, aac, mp4, webm, mov, mkv | `{message}` ; **images toujours acceptées** ; autres fichiers : 403 « …bientôt disponible » si `chat_file` coupé ; audio : 403 si `chat_audio` coupé | Lu |
| `POST conversations/{id}/audio` | `audio` (webm, ogg, mp3, wav, m4a, mp4 ; 10 Mo), `duration?` | `{message}` ; route sous `feature:chat_audio` | Lu |

Il n'y a **aucune** pagination vers les anciens messages : on ne voit que les 50 derniers. Aucune route d'appel audio/vidéo.

### Notifications

| Endpoint | Sortie | Statut |
|---|---|---|
| `GET notifications?tab=all\|interactions\|messages\|system` (30/page) | `{data[], meta:{current_page,last_page,total}, counts:{all,interactions,messages,system}}` ; élément : `id, type, title, body, icon, action_url, data, is_read, read_at, created_at, priority, image_url, sender` | Lu |
| `GET notifications/unread-count` | `{count, tabs:{interactions,messages,system}}` | Lu |
| `GET notifications/{id}` | `{notification, guide_anchor, contest:{type, can_contest, appeal}\|null}` | Lu |
| `POST notifications/{id}/contest` | `message` (10 à 2000 car.) → 201 `{message, appeal}` ; 422 non contestable ; 409 déjà en cours | Lu |
| `GET/PUT notifications/preferences` | `{preferences:[{type,label,push_enabled,in_app_enabled,email_enabled}]}` | Lu |
| `GET notifications/announcements` | `{data[]}` | Lu (éléments non détaillés) |

`action_url` est une **page du site web**, pas un écran de l'app.

### Premium, classements, paiements

| Endpoint | Sortie | Statut |
|---|---|---|
| `GET public-config` (public) | `{beta, listing_fee_with_video, premium_offer_slots, premium_payments}` | Lu |
| `GET premium/plans` | `{plans:[{id: monthly\|annual, label, price, currency}]}` | Lu |
| `GET premium/status` | `{is_premium, plan, expires_at, days_remaining, pending_subscription}` | Lu |
| `GET premium/offer` | `{slots_total, slots_left, days, my_status}` | Lu |
| `POST premium/offer/apply` | 201 `{message, my_status: pending}` ; 422 si déjà Premium ou places épuisées ; 403 `email_not_verified` | Lu |
| `POST premium/subscribe` | `plan`, `payment_method` (wave) → 201 `{message, subscription, payment_url}` ; 403 `{error: premium_coming_soon}` si paiements coupés ; 403 `email_not_verified` ; 422/502 si la passerelle échoue | Lu |
| `GET rankings/sellers\|products\|profiles\|followers` | `{ranking:[{rank, anonymous, username, full_name, avatar_url, badges, …mesures}]}` ; **403 `{message}` si non Premium** (ex. « Les classements sont reserves aux comptes Premium. ») | Lu |
| `GET rankings/preferences` | `{is_premium, ranking_opt_in, ranking_anonymous}` — utilisable pour afficher l'écran sans passer par un 403 | Lu |

## 3. Paiements : ce que fait le code et ce que fera l'app

**Lu dans `PremiumController`, `ProductController` et `WavePaymentConfirmer` :**
- Les deux paiements (abonnement Premium, frais de 150 F pour une annonce avec vidéo d'un compte gratuit) créent une session Wave et renvoient `payment_url`.
- Les adresses de retour sont construites avec l'en-tête `Origin` s'il est autorisé par CORS, sinon `FRONTEND_URL`. Une app mobile n'envoie pas d'`Origin` : le retour de Wave aboutit à **la page web** (`/premium/success`, `/premium/error`, `/feed`, `/sell`). Aucun lien profond vers l'app n'existe.
- **Seul le webhook Wave** (`checkout.session.completed` + `payment_status: succeeded`, signature vérifiée) active l'annonce (`status: active`, `listing_fee_status: paid`) ou l'abonnement. Le retour dans le navigateur ne prouve rien.
- Le serveur compare le montant payé au montant attendu ; un paiement insuffisant est refusé.
- En bêta : frais de publication = 0 (l'annonce passe directement `active`) ; `premium/subscribe` répond 403 `premium_coming_soon`.

**Ce que fera l'app :**
1. Lire `public-config` avant tout écran de paiement. Bêta ou `premium_payments: false` : aucun bouton de paiement, message « paiement non actif pour la version bêta ».
2. Hors bêta : ouvrir `payment_url` dans le navigateur (https seulement, `PaymentStart.tryFromJson`). Message neutre : « Paiement en cours de traitement ». Jamais « payé » à ce stade.
3. Au retour dans l'app : bouton « Vérifier le paiement » qui interroge `premium/status` (abonnement) ou `my-products` (annonce). Succès affiché **uniquement** si le serveur le dit (`is_premium: true` ou annonce `active`). Pas de rafraîchissement automatique en boucle.
4. Une annonce dont le paiement n'aboutit reste en brouillon ; `POST products/{id}/publish` relance un paiement. Aucune route d'annulation n'existe : l'app ne propose pas d'annuler.

**Non vérifié :** que le brouillon et son `listing_fee_status` apparaissent bien dans `my-products` (modèle brut, vraisemblable mais non confirmé), et le comportement réel de Wave (aucun test possible sans compte et serveur).

## 4. Erreurs et statuts HTTP

| Statut | Cas lus dans le code | Traitement app |
|---|---|---|
| 401 | jeton absent, invalide ou supprimé | déconnexion locale, message « session expirée » |
| 403 `account_banned` / `account_suspended` | connexion ou tout appel authentifié (`EnsureAccountActive`) | déconnexion + message du serveur |
| 403 `email_not_verified` | `premium/subscribe`, `premium/offer/apply` | message du serveur, pas d'action proposée (voir §1.1) |
| 403 sans code | classements non Premium, fichiers chat non activés, accès refusé | message du serveur |
| 404 | route absente / ressource absente / drapeau coupé (voir §5) | selon le contexte |
| 409 | signalement ou contestation déjà enregistrés | message du serveur |
| 422 | validation : `{message, errors:{champ:[…]}}` ; ou `{message, error}` (ex. `invalid_otp`, `phone_taken`) | erreurs affichées sous les champs |
| 429 | login (`errors.email`), codes de mot de passe (`retry_after`), limitations de débit | message + attente |
| 503 `{error: maintenance}` | mode maintenance (hors `auth/*`, `admin/*`, `webhooks/*`, `feed/config`) | écran de maintenance |
| 5xx | erreur serveur ; le backend garantit du JSON, jamais du HTML, sur `api/*` | message générique |

Limitations de débit lues : register 3/min, login 5/min, forgot/reset 5/min, subscribe 3/min, apply 5/min.

## 5. Drapeaux serveur : pas de conclusion automatique sur un 404

Un 404 peut venir de quatre causes : drapeau coupé (`abort(404)`, message vide), route inexistante (message « The route … could not be found. »), ressource absente (« No query results… », « Annonce introuvable. », « Ressource introuvable. »), ou autre. `ApiError` ne fait que **classer** (`notFoundEmptyMessage`, `notFoundRouteMissing`, `notFoundResource`, `notFoundOther`) ; il ne conclut jamais « désactivé ».

Règle prévue pour l'étape 4 (service de disponibilité) :
- Une fonction n'est jugée « indisponible » que si un appel **sans modèle lié** (liste, `GET negotiations`, `GET badges/definitions`, `GET favorites/collections`, `GET my-followers`) renvoie un 404 sans message. Sur une route avec identifiant (`follow/{user}`, `users/{id}/reviews`), un 404 ne dit rien du drapeau.
- Même dans ce cas, l'app dit « indisponible pour le moment », jamais « désactivée », et masque la fonction sans contenu fictif.
- Une `notFoundRouteMissing` est traitée comme une erreur de configuration (journal sans donnée sensible), pas comme un drapeau.
- Le résultat n'est pas mis en cache durablement (les drapeaux changent à chaud) : nouvelle vérification au prochain lancement.

**Non vérifié :** le texte exact des messages 404 de Laravel 12 selon `APP_DEBUG`, et si le serveur de production les masque. C'est pourquoi la règle est prudente et sera testée dès qu'un serveur de test existe.

## 6. Fichiers Dart ajoutés (non compilés)

`quinch_mobile/lib/` :
- `core/json/json_utils.dart` — lecture tolérante (aucun champ inventé).
- `core/network/api_error.dart` — classement des erreurs (§4, §5).
- `core/config/media_url.dart` — les vidéos et miniatures sont **relatives** au serveur ; images, posters, avatars sont déjà absolus.
- `core/format/fcfa.dart` — prix en FCFA.
- `data/models/` : `paginated.dart`, `user.dart` (AppUser, AuthSession, PublicProfile), `product.dart` (ProductCard, ProductDetail, ProductVideo, SellerBrief, Category, ProductSaveResult, SearchResults), `messaging.dart` (Message, Conversation, ChatUser, NewMessages), `notifications.dart`, `premium.dart` (PublicConfig, PremiumStatus, PremiumOffer, PaymentStart, RankingEntry).
- `data/api/endpoints.dart` — chemins, tous lus dans `routes/api.php`.

Champs volontairement gardés **bruts** car leur forme n'a pas été confirmée : badges, `product_tags`, `pending_subscription`, annonces et conversations des listes brutes.

## 7. Contrats des services (étape 4+)

| Contrat | Méthodes | Endpoints |
|---|---|---|
| `AuthRepository` | `login`, `register`, `requestPasswordReset`, `resetPassword`, `me`, `refresh`, `logout`, `logoutAll`, `changePassword`, `deleteAccount` | `auth/*` |
| `ProfileRepository` | `getMine`, `update`, `updatePhone`, `uploadAvatar`, `uploadCover`, `getPublic`, `sellerProducts`, `block`, `unblock`, `report`, `exportData` | `user/*`, `users/*` |
| `ProductRepository` | `feed`, `explore`, `search`, `detail`, `create`, `uploadVideo`, `publish`, `update`, `delete`, `myProducts`, `like`, `save`, `report`, `categories` | `products*`, `search*`, `categories` |
| `FavoritesRepository` | `list`, `toggle`, `count` | `favorites*` |
| `ChatRepository` | `conversations`, `start`, `open`, `since(after)`, `send`, `sendFile`, `sendAudio`, `delete` | `conversations*` |
| `NotificationRepository` | `list(tab)`, `unreadCount`, `detail`, `markRead`, `markUnread`, `markAllRead`, `delete`, `contest`, `preferences` | `notifications*` |
| `PremiumRepository` | `config`, `plans`, `status`, `offer`, `applyOffer`, `subscribe` | `public-config`, `premium/*` |
| `RankingRepository` | `list(type)`, `preferences` | `rankings/*` |
| `SupportRepository` | `report` | `support/report` |

Les widgets n'appellent jamais HTTP : ils passent par ces dépôts via Riverpod.

## 8. Ce qui ne peut pas être confirmé sans serveur

1. Textes et statuts réels des 404 (§5) ; état des drapeaux en production.
2. Liste exacte des attributs des modèles bruts (annonces, utilisateur, vidéo, favoris, étiquettes produit).
3. Forme des `badges`, des éléments d'`announcements`, des classements `products` et `profiles`, des résultats de `users/{username}/products`.
4. `is_liked` / `is_saved` dans l'Explorer (§1.6).
5. Mise à disposition de `listing_fee_status` dans `my-products` (§3).
6. Rendu du flux vidéo sur Android avec `video_player` (le serveur gère `Range` ; `Accept-Ranges` est dans le code).
7. Connexion Google : client ID Android à configurer côté serveur.
8. Précision de `after` dans `messages/since` (microsecondes, fuseau) : Angular fait pareil, mais cela n'a pas été exécuté.
9. Aucun test Flutter n'a été lancé ; aucune compilation n'a été faite.

## 9. Plan d'implémentation

**Étape 4 — Fondations.** `flutter create` (organisation `sn.quinch`, nom de projet `quinch_mobile`, à confirmer avant publication) ; `pubspec.yaml` avec `dio`, `flutter_riverpod`, `go_router`, `flutter_secure_storage`, `cached_network_image`, `video_player`, `image_picker`, `file_picker`, `url_launcher`, `intl`, et en test `mocktail` (versions fixées après `flutter pub get`) ; configuration `--dart-define=API_BASE_URL` (HTTPS imposé hors debug) ; thème QUINCH ; client HTTP (jeton, délais, intercepteur 401/403, classement `ApiError`) ; stockage sécurisé du jeton ; session (login, restauration, expiration) ; routeur avec gestion du retour Android ; service de disponibilité (§5). Tests : modèles et erreurs sur réponses **simulées à la main** (je les écris d'après le code, cela ne remplace pas un serveur).

**Étape 5 — Modules.** Auth complète (inscription, connexion, mot de passe oublié en deux temps), onboarding, profil et édition, feed, Explorer, recherche, détail, favoris, publication (sans média d'abord), notifications consultables, support, signalement, contestation, Premium selon `public-config`, classements.

**Étape 6 — Médias et messagerie.** Photos (compression sous 4,8 Mo), vidéo (500 Mo max, avertissement dès 200 Mo, erreurs serveur affichées), lecteur vidéo, messagerie par interrogation périodique au premier plan (8 s conversation ouverte, 20 s liste, comme Angular), pièces jointes selon disponibilité (images toujours), correspondance `action_url` → écrans.

**Étape 7 — Tests et build.** Commandes à lancer chez vous, avec les sorties à me renvoyer :
```
flutter pub get
dart format .
flutter analyze
flutter test
flutter build apk --release
```
Je corrigerai à partir des résultats réels. Un serveur de test faciliterait la validation des points du §8.

## 10. Intégrité du backend

Aucun fichier de `backend/`, `docker/` ni des `docker-compose*.yml` n'a été modifié. Contrôle fait : une seconde extraction propre de l'archive comparée à la copie lue (`diff -rq`) ne montre aucune différence. Ce contrôle porte sur l'archive que vous m'avez fournie, pas sur votre dépôt local.
