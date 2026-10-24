# QUINCH Mobile — Étape 5, lot 5a : disponibilité des fonctions et écrans d'authentification

## 0. État réel

- **Rien de ce lot n'a été compilé, analysé ni testé.** Flutter reste inaccessible depuis mon environnement. Les résultats de l'étape 4 (93 tests réussis) concernent l'étape 4 seulement.
- Tests écrits dans ce lot : **28 nouveaux** (121 au total), **aucun exécuté**.
- Contrôle fait : tous les `import` pointent vers des fichiers existants (script). C'est tout.
- Backend, Docker, docker-compose : intacts (nouvelle comparaison avec l'archive).

## 1. Livré dans ce lot

| Fichier | Rôle |
|---|---|
| `lib/core/features/feature_availability.dart` | Service de disponibilité des fonctions sous drapeau |
| `lib/core/validation/validators.dart` | Contrôles de saisie (confort, le serveur reste l'autorité) |
| `lib/shared/widgets/app_widgets.dart` | Champs, bouton avec chargement, message d'erreur, mise en page d'authentification |
| `lib/features/auth/login_page.dart`, `register_page.dart`, `forgot_password_page.dart` | Écrans |
| `lib/app/router.dart`, `app.dart` | Routes `/register` et `/forgot-password` (publiques), instanciation du service |
| `lib/features/shell/placeholder_pages.dart` | L'ancien écran de connexion provisoire est retiré |
| `lib/data/api/endpoints.dart` | 4 chemins de sondage ajoutés |
| `test/support/fakes.dart` | Faux dépôt enrichi (captures des appels) |
| `test/core/validators_test.dart`, `feature_availability_test.dart`, `test/features/auth_pages_test.dart`, `test/app/router_redirect_test.dart` | Tests |

## 2. Décisions

- **Disponibilité des fonctions** (règle de l'étape 3, §5) :
  - un appel réussi → disponible ;
  - 404 **sans message** sur une route de sondage connue → indisponible ;
  - toute autre erreur (réseau, 5xx, 401, « route introuvable », « ressource absente ») → l'état ne change pas.
  - Sondes : `GET negotiations`, `my-followers`, `badges/definitions`, `favorites/collections` (aucune n'a d'identifiant de ressource). Elles partent à chaque connexion et sont oubliées à la déconnexion ; rien n'est conservé entre deux lancements.
  - Avis, partage, vocal et fichiers du chat n'ont pas de route de sondage : ils restent « inconnus » jusqu'au premier usage (`report`).
  - Une fonction « inconnue » est proposée ; une fonction « indisponible » est masquée, sans contenu fictif. Les écrans parleront d'« indisponible pour le moment », jamais de « désactivée ».
- **Connexion** : un seul bandeau d'erreur (le serveur place « identifiants incorrects » sous le champ email, on l'affiche en haut). Le motif de fin de session (expirée, banni, suspendu, déconnecté) s'affiche au-dessus du formulaire.
- **Inscription** : erreurs du serveur affichées sous le champ concerné (email, nom, utilisateur, mot de passe). Aucun champ téléphone, conformément au backend.
- **Mot de passe oublié** : deux temps (email, puis code à 6 caractères + nouveau mot de passe), avec « Renvoyer un code » et « Changer d'adresse email ». La réponse est la même que le compte existe ou non.
- **Navigation** : les liens ouvrent les écrans par `push` pour que le bouton retour d'Android revienne à la connexion. Après connexion ou inscription réussie, la redirection du routeur quitte l'écran.
- Aucun mot de passe n'est gardé ; les champs masquent la saisie, désactivent les suggestions et le correcteur ; les champs participent à l'auto-remplissage d'Android.
- Pas de thème global des champs : j'ai évité les API de thème qui ont changé récemment dans Flutter. Les champs portent leur style eux-mêmes.

## 3. Points à connaître (ne pas ignorer)

1. **Conditions d'utilisation et confidentialité : bloquant avant publication.** `GET legal/info` ne renvoie **pas** les textes, seulement les coordonnées de l'éditeur. Les textes sont écrits en dur dans Angular (`legal-content.ts`, 18 Ko, construits avec les informations de l'éditeur) et leur propre en-tête dit qu'ils doivent être relus par un juriste avant l'ouverture au public. L'écran d'inscription demande bien l'acceptation (le serveur l'exige), mais **l'utilisateur ne peut pas encore lire les textes dans l'application**. Je ne les ai pas portés ici : c'est du contenu juridique à reproduire fidèlement, et leur version dépend du serveur (`LEGAL_TERMS_VERSION`). Prévu dans le lot suivant ; ne pas ouvrir l'inscription au public avant.
2. **Email non vérifiable** (déjà signalé) : un compte créé par l'application ne pourra pas postuler à l'offre Premium tant que la vérification d'email du backend n'est pas réparée.
3. **Connexion Google** : non faite (client ID Android à configurer côté serveur, non vérifiable).
4. **Une seule session par compte** : se connecter sur le web déconnecte l'application ; le message « Votre session a expiré » s'affichera sur l'écran de connexion.

## 4. Commandes à lancer

Copiez le contenu de `quinch_mobile_etape5a.zip` par-dessus votre dossier `quinch_mobile` (le zip ne contient pas `android/`, qui reste intact), puis :
```powershell
cd C:\xampp\htdocs\QUINCH\quinch_mobile
dart format .
flutter analyze
flutter test
```
Renvoyez-moi les sorties de `flutter analyze` et `flutter test`. Si vous avez déjà généré `android/`, vous pouvez aussi essayer `flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8080/api/v1` : l'application affichera maintenant un vrai écran de connexion, avec le backend lancé (`docker compose up`).

## 5. Reste à faire dans l'étape 5

- **Lot 5b** : navigation principale (barre du bas), dépôts produits / favoris / profil, feed vidéo (sans lecture vidéo avancée, qui est de l'étape 6), Explorer, recherche, détail d'une annonce, favoris.
- **Lot 5c** : mon profil et édition, profil vendeur, publication (sans média), notifications, support, signalement, contestation, Premium selon `public-config`, classements, pages légales.
