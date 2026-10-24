# QUINCH Mobile — Étape 5, lot 5b : navigation, feed, Explorer, recherche, détail, favoris

## 0. État réel

- **Rien de ce lot n'a été compilé, analysé ni testé** (Flutter reste inaccessible de mon côté). Le lot 5a, lui, est validé chez vous : analyse sans problème, 121 tests réussis, connexion et inscription essayées sur l'émulateur.
- Tests écrits dans ce lot : **53 nouveaux** (174 au total), **aucun exécuté**.
- Contrôles faits : tous les `import` pointent vers des fichiers existants et aucun import inutile détecté par un script grossier. Ce n'est pas un compilateur.
- Aucune dépendance ajoutée : pas de `flutter pub get` nécessaire.
- Backend, Docker, docker-compose : intacts.

## 1. Contenu

| Zone | Fichiers |
|---|---|
| Navigation | `features/shell/main_shell.dart` (barre du bas : Accueil, Explorer, Favoris, Compte, une pile par onglet), `app/router.dart` (coque à onglets, `/search`, `/product/:slug`, `homePath` = `/feed`) |
| Données | `data/repositories/product_repository.dart`, `favorites_repository.dart` ; modèles typés `SearchProductHit`, `SearchUserHit`, `LikeResult`, `FavoriteEntry` dans `product.dart` |
| État | `features/product/product_providers.dart` (feed, Explorer, favoris, détail, catégories, état partagé « aimé / enregistré »), `shared/paging/paged_notifier.dart` (liste paginée) |
| Écrans | `features/feed/*`, `features/explore/*` (grille, filtres), `features/search/search_page.dart`, `features/product/product_detail_page.dart`, `product_actions.dart`, `features/favorites/favorites_page.dart`, `features/account/account_page.dart` |
| Composants | `shared/widgets/product_widgets.dart` (image, étiquette Produit/Service, erreur + réessai, état vide), `shared/paging/paged_scroll.dart` (liste ou grille paginée) |
| Retiré | `HomePlaceholderPage` (remplacée par la navigation) |

## 2. Décisions

- **Paramètres lus dans le backend** : l'Explorer envoie `price_min`, `price_max`, `sort_by`, `category` (identifiant exact, sous-catégories non incluses), `type`. Angular envoie `min_price`, `max_price` et `condition`, que l'Explorer ignore : ces filtres ne marchent pas sur le site. Un test vérifie que l'application n'envoie jamais ces noms.
- **Feed** : uniquement des annonces avec vidéo, tri stable côté serveur : pagination simple par `page` (le paramètre `seed` cité dans un commentaire du backend n'est pas utilisé). Onglet « Abonnements » masqué si les abonnements sont jugés indisponibles (service de la 5a).
- **« Enregistrer » et « Favoris »** : `products/{id}/save` et `favorites/toggle` écrivent dans la même table côté serveur. L'application utilise `save` partout (Angular mélange les deux). Les collections de favoris ne sont pas faites.
- **Cohérence « aimé / enregistré »** : un état partagé garde le dernier résultat connu après chaque action ; feed, détail et favoris s'y alignent sans recharger. Affichage immédiat, puis valeurs du serveur ; en cas d'échec, retour à l'état précédent avec message.
- **Explorer sans indicateurs « aimé / enregistré »** : cette route lit l'utilisateur avec le guard `web` (rapport étape 3, §1.6), donc ces indicateurs y sont probablement faux. Les vignettes n'en affichent pas ; le détail, lui, est fiable.
- **Produit / Service** : étiquette bleue ou verte ; le vert est celui de l'étiquette « service » du site.
- **Compte** : déconnexion avec demande de confirmation. Écran volontairement minimal, complété au lot 5c.
- **Images** : `Image.network` de Flutter (cache mémoire par défaut). Un cache disque (`cached_network_image`) sera décidé à l'étape 6 avec la vidéo.

## 3. Limites connues

1. **Aucune lecture vidéo** : le feed est une liste de cartes avec image de couverture, badge vidéo et durée. La lecture est prévue à l'étape 6.
2. **Pas de contact vendeur** ni de profil vendeur : le bouton « Contacter » arrive avec la messagerie (étape 6), le profil vendeur au lot 5c. Les vendeurs trouvés par la recherche ne sont donc pas affichés ; seules les annonces le sont.
3. **Pas de suggestions de recherche ni de recherches tendance** : routes présentes (`search/suggestions`, `search/trending`) mais leur forme n'a pas été vérifiée.
4. **Pas de signalement d'annonce** : lot 5c.
5. **Pas de création d'annonce** (lot 5c) : pour voir quelque chose sur l'émulateur, créez quelques annonces, dont certaines avec vidéo, depuis le site web.
6. **Adresses des images** : le backend les construit avec l'adresse de la requête (`url()`), donc `10.0.2.2:8080` sur l'émulateur devrait fonctionner. Si vos images restent grises, dites-le-moi : cela viendrait d'une `APP_URL` forcée à `localhost`.

## 4. À essayer sur l'émulateur

1. Après connexion : barre du bas à 4 onglets ; le retour Android sur un onglet quitte l'application.
2. **Accueil** : cartes avec image, prix en FCFA, « j'aime » (compteur) et favori ; tirer pour actualiser ; défiler jusqu'en bas pour charger la suite.
3. **Explorer** : grille ; puces Tous / Produits / Services ; filtres (catégorie, prix, tri) ; icône de recherche.
4. **Détail** : galerie, informations, vendeur, « j'aime » et favori ; retour.
5. **Favoris** : l'annonce enregistrée apparaît ; la retirer la fait disparaître.
6. **Compte** : « Se déconnecter » demande confirmation.
7. Coupez le backend (`docker compose stop`) puis tirez pour actualiser : message d'erreur et « Réessayer ».

## 5. Commandes

Copiez le contenu de `quinch_mobile_etape5b.zip` par-dessus votre dossier (il ne contient pas `android/`), puis :
```powershell
cd C:\xampp\htdocs\QUINCH\quinch_mobile
dart format .
flutter analyze
flutter test
flutter run -d emulator-5554 --dart-define=API_BASE_URL=http://10.0.2.2:8080/api/v1
```
Renvoyez les sorties de `flutter analyze` et `flutter test`, plus ce que vous avez vu sur l'émulateur.

## 6. Suite

- **Lot 5c** : profil et édition, profil vendeur, publication (sans média), notifications, support, signalement, contestation, Premium selon `public-config`, classements, textes juridiques (bloquant avant l'ouverture de l'inscription).
- **Étape 6** : photos, vidéo (500 Mo, avertissement dès 200 Mo), lecture dans le feed, messagerie et contact vendeur.
