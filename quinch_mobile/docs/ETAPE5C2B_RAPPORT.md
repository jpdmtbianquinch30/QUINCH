# QUINCH Mobile — Étape 5, lot 5c-2b : Premium et classements

## 0. État réel

- **Rien de ce lot n'a été compilé, analysé ni testé** (Flutter reste inaccessible de mon côté). Le lot 5c-2a est validé chez vous : 264 tests réussis.
- Tests écrits dans ce lot : **39 nouveaux** (303 au total), **aucun exécuté**.
- Contrôles faits : tous les `import` pointent vers des fichiers existants, aucun import inutile ni enchaînement `..a = … ..b = …` risqué détecté par un script. Ce n'est pas un compilateur.
- **Une dépendance ajoutée : `url_launcher: ^6.3.1`** (ouverture de la page de paiement dans le navigateur). Sa version n'est pas vérifiée contre pub.dev : `flutter pub get` tranchera. Il faut donc le lancer cette fois.
- Backend, Docker, docker-compose : intacts.

## 1. Livré

| Écran | Ce qu'il fait | Endpoints |
|---|---|---|
| Premium | Statut du compte (formule, date de fin, jours restants) ; formules et prix en FCFA ; offre de lancement ; « Vérifier mon paiement » ; lien vers les classements | `GET public-config`, `premium/plans`, `premium/status`, `premium/offer`, `POST premium/offer/apply`, `POST premium/subscribe` |
| Classements | Réservés aux Premium : message et lien vers l'offre sinon. Vendeurs, Annonces, Profils, Abonnés ; réglages « Apparaître dans les classements » et « Rester anonyme » | `GET rankings/preferences`, `PATCH rankings/preferences`, `GET rankings/sellers`, `products`, `profiles`, `followers` |

Entrées ajoutées dans le Compte : « Premium » et « Classements ».

## 2. Paiements : règles appliquées

- Source de vérité : `public-config`. Si `premium_payments` est faux (bêta), **aucun bouton de paiement** n'est affiché, seulement : « Le paiement n'est pas actif pour la version bêta. Les formules seront disponibles prochainement. »
- Paiements actifs : « Choisir » → confirmation (« Vous allez être redirigé vers une page de paiement sécurisée, hors de QUINCH ») → `POST premium/subscribe` → ouverture de l'adresse **dans le navigateur**, seulement si elle est en `https`. Une adresse absente ou en `http` n'est jamais ouverte.
- **Jamais « payé » sans le serveur** : après l'ouverture, l'écran affiche « Paiement en cours de traitement… ». Le serveur confirme via un webhook, et l'application ne peut que relire `premium/status`. Le bouton « Vérifier mon paiement » le fait ; seul `is_premium: true` du serveur déclenche « Paiement confirmé » et fait passer l'écran en Premium. Un test vérifie qu'aucun message de confirmation n'apparaît avant.
- **Pas de retour automatique** : Wave ramène l'utilisateur vers la page web, pas vers l'application (aucun lien profond côté serveur). L'utilisateur revient lui-même dans l'application.
- Mode de paiement envoyé : `wave`, valeur par défaut du backend. Les modes activés ne sont exposés par aucune route ; si un mode est refusé, le message du serveur s'affiche.
- **Offre de lancement** : places restantes, durée, candidature. États : en cours d'examen, accordée, non retenue, plus de place. L'offre est facultative : si elle échoue à charger, le reste de l'écran s'affiche.
- **Email non vérifié** : le serveur répond 403 « confirmez votre adresse e-mail » à la candidature et à l'abonnement. Comme la vérification d'email du backend de l'archive est cassée (étape 3, §1.1), l'application affiche le message du serveur tel quel et ne propose aucune action inexistante. Si vous avez réparé ce point dans votre dépôt, tout fonctionnera normalement.
- Après une confirmation de paiement, l'utilisateur de la session est relu (`auth/me`).

## 3. Classements : décisions

- Quatre formes de réponse vérifiées dans le code : vendeurs (points, vues, j'aime, annonces), profils (visites), abonnés (nombre), annonces (forme propre : titre, vendeur, vues). Un profil anonyme s'affiche « Utilisateur anonyme » et n'est pas cliquable.
- « Rester anonyme » n'est réglable que si la participation est activée. Chaque changement envoie les deux valeurs ; en cas d'échec, le réglage revient à son état précédent.
- Un 403 pendant la consultation (abonnement expiré entre-temps) affiche le message du serveur avec « Réessayer ».

## 4. Robustesse

Les messages des actions Premium sont affichés avec un messager d'écran capturé avant les attentes réseau, et l'écran garde ses données pendant un rechargement : sinon la reconstruction après un paiement ou une candidature aurait détruit les boutons avant l'affichage du message.

## 5. Limites connues

1. Pas de retour automatique après paiement (voir §2).
2. Pas de choix de mode de paiement.
3. Les frais de publication d'annonce avec vidéo (150 F hors bêta) relèvent de la publication, à l'étape 6.
4. Une formule ou un statut inconnus s'affichent tels que renvoyés par le serveur.
5. **Aucun test de paiement réel** : en bêta les paiements sont coupés, et un paiement Wave ne peut pas être simulé.

## 6. À essayer sur l'émulateur

1. Compte → Premium : en bêta, statut « gratuit », message sur le paiement, offre de lancement.
2. « Demander l'offre de lancement » : soit une confirmation, soit le message du serveur (par exemple email non confirmé).
3. Tirer pour actualiser.
4. Compte → Classements : message « réservé aux Premium » avec un compte gratuit ; avec un compte Premium (accordé depuis l'administration du site), les quatre classements et les deux réglages.
5. Toucher une ligne : le profil du vendeur ou l'annonce s'ouvre.

## 7. Commandes

Copiez le contenu de `quinch_mobile_etape5c2b.zip` par-dessus votre dossier (il ne contient pas `android/`), puis :
```powershell
cd C:\xampp\htdocs\QUINCH\quinch_mobile
flutter pub get
dart format .
flutter analyze
flutter test
flutter run -d emulator-5554 --dart-define=API_BASE_URL=http://10.0.2.2:8080/api/v1
```
Renvoyez les sorties de `flutter pub get`, `flutter analyze` et `flutter test`, plus ce que vous avez vu sur l'émulateur.

## 8. Suite

- **Lot 5c-2c** : textes juridiques (conditions d'utilisation, confidentialité), **bloquants avant l'ouverture de l'inscription au public**.
- **Étape 6** : photos, vidéo (500 Mo, avertissement dès 200 Mo), lecture dans le feed, publication et modification d'annonce, photo de profil, messagerie.
- **Étape 7** : build release signé.
