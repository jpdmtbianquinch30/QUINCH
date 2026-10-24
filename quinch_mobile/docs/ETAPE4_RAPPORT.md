# QUINCH Mobile — Étape 4 : fondations techniques

## 0. État réel (à lire en premier)

- **Flutter et Dart ne sont pas installés** dans l'environnement où j'ai écrit le code, et `pub.dev` comme le dépôt des SDK y sont inaccessibles.
- **Rien n'a été compilé, analysé ni testé.** Aucune des commandes `flutter pub get`, `dart format`, `flutter analyze`, `flutter test`, `flutter build apk` n'a été exécutée.
- Seul contrôle fait : un script qui vérifie que chaque `import` pointe vers un fichier existant et que les parenthèses, crochets et accolades sont équilibrés dans les 34 fichiers Dart. C'est un contrôle grossier, pas un compilateur : il ne détecte ni erreur de type ni API mal utilisée.
- Les **versions des dépendances n'ont pas été vérifiées** contre pub.dev (voir §3). Le projet n'est donc pas « prêt à compiler » tant que vous n'avez pas lancé les commandes du §6 et renvoyé les sorties.
- Backend, Docker et `docker-compose*.yml` : **intacts** (nouvelle comparaison avec l'archive : aucune différence).

## 1. Fichiers

**Créés (à l'étape 4)**

| Fichier | Rôle |
|---|---|
| `pubspec.yaml`, `analysis_options.yaml`, `.gitignore` | Projet, analyse stricte (`strict-casts`, `strict-raw-types`, `flutter_lints`), exclusion des clés de signature |
| `lib/main.dart` | Lecture de la configuration, `ProviderScope` ; écran d'erreur si l'URL de l'API est invalide |
| `lib/app/app.dart`, `router.dart`, `theme.dart` | Application, routes GoRouter, thème QUINCH |
| `lib/core/config/app_config.dart` | `API_BASE_URL`, HTTPS imposé hors debug |
| `lib/core/storage/token_storage.dart` | Jeton dans le Keystore (flutter_secure_storage) |
| `lib/core/network/auth_token_holder.dart`, `interceptors.dart`, `dio_factory.dart`, `api_client.dart` | Client HTTP, jeton, reprises, conversion des erreurs |
| `lib/core/session/session_state.dart`, `session_controller.dart` | Gestion de session |
| `lib/core/providers.dart` | Injection Riverpod |
| `lib/data/repositories/auth_repository.dart` | Appels `auth/*` vérifiés |
| `lib/features/shell/placeholder_pages.dart` | 3 écrans provisoires (chargement, connexion à venir, accueil provisoire) |
| `android_setup/debug/AndroidManifest.xml` | HTTP autorisé en debug uniquement |
| `test/support/fakes.dart`, `test/core/*`, `test/app/*`, `test/data/*`, `test/security/*` | Tests (§5) |

**Modifié** : `lib/core/network/api_error.dart` — ajout du genre `tls`, de `ApiError.tls()` et `ApiError.cancelled()` (un échec de certificat n'est plus confondu avec une panne réseau). Les modèles, `endpoints.dart` et les utilitaires de l'étape 3 sont réutilisés sans changement.

Aucun fichier supprimé.

## 2. Décisions techniques

- **Riverpod 2.6, pas 3.x** : API que je maîtrise sans doute possible ; migration possible plus tard. **go_router 14.8**, **dio 5.8**, **flutter_secure_storage 9.2**.
- **Pas de génération de code** (freezed, json_serializable) : les modèles de l'étape 3 sont écrits à la main et tolérants aux formes multiples du backend. Moins de dépendances, moins de pièces à casser.
- **Dio caché derrière `ApiClient`** : les écrans et dépôts ne voient que `Object?` ou `ApiError`. Aucun appel HTTP dans un widget.
- **URL de base** : toujours terminée par `/`, chemins sans `/` initial (sinon Dio colle `…/v1auth/login`). Par défaut en debug : `http://10.0.2.2:8080/api/v1` (nginx expose le port 8080 dans `docker-compose.yml`). Production : `https://api.quinch.sn/api/v1` (celle d'Angular).
- **Sécurité réseau** : aucun `badCertificateCallback`, aucun `HttpOverrides`, aucun `LogInterceptor` ; le jeton n'est envoyé qu'à l'hôte de l'API ; hors debug, `http://` est refusé au démarrage. Un test lit le code et échoue si un de ces motifs apparaît.
- **Données locales** : uniquement le jeton et sa date d'émission, dans le Keystore. Pas de mot de passe, pas de profil mis en cache.
- **Reprises** : GET seulement, 2 fois maximum, sur coupure réseau, délai de lecture dépassé, 502 ou 504. Jamais pour POST/PUT/DELETE, 503 (maintenance), ni échec TLS.
- **Session** (reprend la logique d'Angular) :

| Situation | Résultat |
|---|---|
| Pas de jeton | non connecté |
| `auth/me` OK | connecté ; si le jeton a plus de 7 jours (seuil 10 080 min, comme Angular), `auth/refresh` en meilleur effort |
| 401, compte banni ou suspendu | jeton effacé, motif affiché sur l'écran de connexion |
| Réseau, délai, 5xx, maintenance | **pas de déconnexion** : état « indisponible » avec bouton Réessayer |
| Connexion refusée | l'erreur est relancée à l'écran, rien n'est stocké |
| Déconnexion | session locale fermée même si le serveur ne répond pas |

- **Gestion des erreurs HTTP** (`ApiError`) : 401, 403 (`account_banned`, `account_suspended`, `email_not_verified`, autre), 404 (trois indices distincts), 409 (message du serveur), 422 (erreurs par champ), 429 (avec `retry_after`), 503 (maintenance seulement avec le code dédié), 5xx (message générique, sans détail interne).
- **404** : classé en trois indices (`notFoundEmptyMessage`, `notFoundRouteMissing`, `notFoundResource`, plus `notFoundOther`). Rien ne conclut « fonctionnalité désactivée » ; une session n'est jamais invalidée par un 404.
- **Thème** : couleurs d'Angular (`styles.scss`) : accent #4f6ef7, secondaire #10b981, fonds #0a0e1a / #1a1f35 (sombre) et #f5f7fa / #ffffff (clair), thème suivant le système. Police système (Inter non embarquée). Zones tactiles de 48 dp. Les thèmes de composants (boutons, champs) sont repoussés à l'étape 5 : je ne veux pas écrire à l'aveugle des API de thème qui ont changé récemment dans Flutter.
- **Navigation** : redirections par une fonction pure (`resolveRedirect`) testée ; le retour Android est géré par GoRouter ; interface en français (`fr`).
- **Correction** : j'avais annoncé l'identifiant Android `sn.quinch.app`. Avec la commande du §6 (`--org sn.quinch --project-name quinch_mobile`), il sera `sn.quinch.quinch_mobile`. **Il ne pourra plus être changé après une publication sur le Play Store** : choisissez le définitif avant.

## 3. Dépendances : ce qui n'est pas vérifié

| Paquet | Contrainte | Statut |
|---|---|---|
| dio | ^5.8.0 | non vérifiée contre pub.dev |
| flutter_riverpod | ^2.6.1 | non vérifiée |
| go_router | ^14.8.1 | non vérifiée ; versions plus récentes existent probablement |
| flutter_secure_storage | ^9.2.4 | non vérifiée ; l'option `encryptedSharedPreferences` est celle de la branche 9.x |
| flutter_localizations / intl | SDK / `any` | recommandation de la documentation Flutter |
| flutter_lints | ^5.0.0 | non vérifiée |

Les contraintes sont des intervalles « caret », pas des versions figées. `flutter pub get` choisira les versions compatibles avec Flutter 3.38.4 / Dart 3.10.3. S'il échoue, envoyez la sortie ; je ne fixerai de versions exactes (`pubspec.lock`) qu'après un `pub get` réussi chez vous. Les versions plus récentes de go_router ou flutter_lints peuvent produire des avertissements de dépréciation que je corrigerai à partir de votre sortie `flutter analyze`.

## 4. Non fait à cette étape (volontairement ou faute de pouvoir)

- **Service de disponibilité des fonctionnalités** (§5 du rapport de l'étape 3) : je l'avais prévu à l'étape 4, mais il a besoin des dépôts qui font les appels de sondage (`negotiations`, `badges/definitions`, etc.). Je le fais au début de l'étape 5, avec ces dépôts.
- **Aucun écran fonctionnel** : pas de formulaire de connexion ni d'inscription (étape 5). Sans écran de connexion, la session ne peut pas encore être ouverte depuis l'appareil : l'application affiche l'écran « connexion à venir ». La logique de session est donc validée par les tests, pas à la main.
- **Pas de test de `SecureTokenStorage`** (il dépend de la plateforme) ni de test de widget.
- **Projet Android non généré** : `flutter create` doit être lancé chez vous (§6).
- **Aucun serveur de test** : tous les tests utilisent des réponses simulées écrites d'après le code du backend.

## 5. Tests écrits (93 cas, **aucun exécuté**)

| Fichier | Cas | Couvre |
|---|---|---|
| `test/data/models_test.dart` | 29 | lecture JSON tolérante, utilisateur (deux formes), pagination (deux variantes), annonce (feed, Explorer, brute), détail, messagerie, notifications, premium, `PaymentStart` (https exigé), classements, FCFA, URLs de médias |
| `test/core/api_error_test.dart` | 12 | 401, 403 (4 cas), 404 (trois indices), 409, 422, 429, 503, 5xx, corps inattendu |
| `test/core/api_client_test.dart` | 19 | URL assemblée, jeton uniquement vers l'hôte de l'API, invalidation de session, 404/409/429/503/500, reprises GET, aucune reprise POST, délai dépassé, échec TLS |
| `test/core/session_controller_test.dart` | 18 | démarrage (sans jeton, valide, expiré, banni, suspendu, panne réseau, maintenance, réessai), rafraîchissement dû / non dû / en échec, connexion, inscription, déconnexion, invalidation, mise à jour utilisateur |
| `test/core/app_config_test.dart` | 9 | HTTPS hors debug, valeur par défaut debug, identifiants/paramètres refusés, résolution des médias |
| `test/app/router_redirect_test.dart` | 5 | redirections selon l'état de session, messages de fin de session |
| `test/security/no_tls_bypass_test.dart` | 1 | absence de contournement TLS, de `LogInterceptor`, de `print` dans `lib/` |

## 6. Commandes à lancer sur votre PC (Windows, PowerShell)

**Une seule fois : générer le projet Android** (depuis le dossier qui contient `quinch_mobile`) :
```powershell
flutter create --org sn.quinch --project-name quinch_mobile --platforms=android quinch_tmp
Copy-Item quinch_tmp\android quinch_mobile\android -Recurse
Copy-Item quinch_tmp\.metadata quinch_mobile\.metadata
Remove-Item quinch_tmp -Recurse -Force
Copy-Item quinch_mobile\android_setup\debug\AndroidManifest.xml quinch_mobile\android\app\src\debug\AndroidManifest.xml -Force
```
Puis, dans `quinch_mobile\android\app\src\main\AndroidManifest.xml` :
1. ajouter `<uses-permission android:name="android.permission.INTERNET"/>` juste avant `<application` (indispensable en release : sans elle, l'APK n'accède pas au réseau) ;
2. ajouter `android:allowBackup="false"` dans la balise `<application` (évite de restaurer un jeton chiffré sur un autre appareil).

**Ensuite** :
```powershell
cd quinch_mobile
flutter pub get
dart format .
flutter analyze
flutter test
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8080/api/v1
flutter build apk --release --dart-define=API_BASE_URL=https://api.quinch.sn/api/v1
```
- Émulateur Android : `10.0.2.2` désigne votre PC. Téléphone réel : remplacez par l'adresse IP de votre PC sur le Wi-Fi (backend lancé avec `docker compose up`, pare-feu Windows ouvert sur le port 8080). Cette adresse en `http` ne fonctionne qu'en debug.
- Renvoyez-moi la sortie complète de `flutter pub get`, `flutter analyze` et `flutter test` : je corrigerai le code à partir des résultats réels.
- Le build release n'est pas signé avec une clé de production ; la signature viendra à l'étape 7.

## 7. Blocages et risques

1. **Compilation non démontrée** (§0) : des erreurs de types ou d'API Flutter sont possibles dans les ~3 500 lignes écrites sans analyseur.
2. **Versions de dépendances non vérifiées** (§3).
3. **Vérification d'email cassée côté backend** (étape 3, §1.1) : inchangé, à décider de votre côté.
4. **Une session unique par compte** : se connecter sur le web déconnectera l'application ; l'écran de connexion l'expliquera (« session expirée »).
5. **Identifiant Android** à figer avant toute publication (§2).

## 8. Prochaines étapes

- **Étape 5** : service de disponibilité des fonctionnalités + dépôts (profil, produits, favoris, notifications, Premium, classements, support) ; écrans de connexion, inscription et mot de passe oublié en deux temps ; thème des composants ; puis feed, Explorer, recherche, détail, publication (sans média), notifications, Premium selon `public-config`.
- **Étape 6** : photos, vidéo (500 Mo, avertissement dès 200 Mo), lecteur, messagerie par interrogation, pièces jointes.
- **Étape 7** : tests complémentaires, signature, build release.
