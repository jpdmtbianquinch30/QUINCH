# QUINCH Mobile — Étape 5, lot 5c-1 : compte, profils, signalements, support

## 0. État réel

- **Rien de ce lot n'a été compilé, analysé ni testé** (Flutter reste inaccessible de mon côté). Le lot 5b est validé chez vous : analyse sans problème, 174 tests réussis, émulateur OK.
- Tests écrits dans ce lot : **47 nouveaux** (221 au total), **aucun exécuté**.
- Contrôles faits : tous les `import` pointent vers des fichiers existants, aucun import inutile détecté par un script grossier. Ce n'est pas un compilateur.
- **Une refonte touche du code déjà validé** : la logique des listes paginées a été extraite dans `PagedCore` (pour la liste des annonces d'un vendeur, qui dépend d'un paramètre). Les 9 tests existants de `paged_notifier_test.dart` vérifient qu'elle se comporte comme avant.
- Aucune dépendance ajoutée. Backend, Docker, docker-compose : intacts.

## 1. Correction d'une annonce précédente

J'avais écrit que la « publication (sans média) » ferait partie du lot 5c. **C'est impossible** : le backend refuse de créer une annonce sans au moins une image ou une vidéo (`poster_file`, `image_files[]` ou `video_id`). La publication d'annonce, l'ajout de photo de profil / couverture et la modification d'une annonce passent donc à l'**étape 6** (médias).

## 2. Livré

| Écran | Ce qu'il fait | Endpoints |
|---|---|---|
| Compte | Identité, accès aux écrans ci-dessous, déconnexion avec confirmation | — |
| Modifier mon profil | Nom, nom d'utilisateur, email, présentation, site, ville, région ; téléphone à part (+221 et 9 chiffres, suppression possible) | `GET/PUT user/profile`, `PUT user/phone` |
| Profil vendeur | Fiche, nombre d'annonces et d'abonnés, annonces en ligne (grille paginée), s'abonner / se désabonner, signaler, bloquer | `users/{username}/profile`, `users/{username}/products`, `follow/{id}`, `unfollow/{id}`, `users/{id}/report`, `users/{id}/block` |
| Mes annonces | Liste avec statut (Brouillon, En ligne, Réservé, Vendu), suppression avec confirmation | `GET my-products`, `DELETE products/{id}` |
| Utilisateurs bloqués | Liste et déblocage | `GET users/blocked`, `POST users/{id}/unblock` |
| Signaler un problème | Catégorie (bug, suggestion, sécurité, autre) + description | `POST support/report` |
| Paramètres | Changement de mot de passe, suppression du compte (mot de passe exigé) | `PUT auth/change-password`, `POST auth/delete-account` |
| Détail d'annonce | Menu « Signaler l'annonce » (masqué sur ses propres annonces) ; toucher le vendeur ouvre son profil | `POST products/{id}/report` |

## 3. Décisions

- **Profil** : seuls les champs modifiés sont envoyés. La ville et la région ne sont envoyées que si elles sont renseignées (le serveur refuse une valeur vide). Changer d'email demande le mot de passe actuel, comme le serveur. Après enregistrement, l'utilisateur de la session est mis à jour.
- **Téléphone** : saisi sans indicatif, envoyé sous la forme `+221XXXXXXXXX`, comme l'exige le serveur ; vide ou « Supprimer » envoie `null`.
- **Abonnements** : le bouton dépend de la disponibilité de la fonction (service de la 5a). Si un abonnement renvoie un 404 sans message, la fonction est marquée indisponible et le bouton disparaît.
- **Signalements** : motifs limités aux valeurs que le serveur accepte ; un signalement déjà en cours (409) affiche le message du serveur dans la feuille.
- **Blocage** : confirmation, puis retour à l'écran précédent. Le déblocage se fait depuis « Utilisateurs bloqués » (le profil public n'indique pas si on a bloqué la personne).
- **Suppression de compte** : après succès, la session locale est fermée sans appeler le serveur et l'écran de connexion affiche « Votre compte a été supprimé. ».
- **Changement de mot de passe** : le serveur déconnecte les autres appareils ; cette session reste ouverte (l'écran le dit).

## 4. Limites connues

1. Pas de photo de profil ni de couverture, ni de publication ou modification d'annonce (étape 6).
2. Le nom de l'auteur sur les cartes du feed ne mène pas encore au profil vendeur : seul le détail d'annonce le fait.
3. Pas de notes ni d'avis, de badges, de collections de favoris (fonctions sous drapeau, non faites).
4. Un statut d'annonce inconnu s'affiche tel que renvoyé par le serveur (valeurs rencontrées dans le code : draft, active, reserved, sold ; d'autres peuvent exister).
5. Textes juridiques : toujours à faire (bloquant avant l'ouverture au public).

## 5. À essayer sur l'émulateur

1. **Compte** : les cinq entrées ouvrent chacune leur écran ; « Se déconnecter » demande confirmation.
2. **Modifier mon profil** : changer le nom ou la ville, enregistrer ; un nom d'utilisateur déjà pris affiche l'erreur du serveur sous le champ ; changer l'email demande le mot de passe actuel ; enregistrer puis supprimer un numéro.
3. **Profil vendeur** : depuis le détail d'une annonce, toucher le vendeur ; s'abonner / se désabonner ; menu : signaler (essayer deux fois pour voir le message « déjà signalé ») et bloquer, puis retrouver la personne dans « Utilisateurs bloqués » et la débloquer.
4. **Signaler une annonce** depuis son détail.
5. **Mes annonces** : si vous en avez, statuts et suppression.
6. **Paramètres** : changer le mot de passe (puis vérifier sur le web que l'ancien ne marche plus) ; **ne testez pas la suppression de compte avec un compte qui vous sert** : elle est définitive.

## 6. Commandes

Copiez le contenu de `quinch_mobile_etape5c1.zip` par-dessus votre dossier (il ne contient pas `android/`), puis :
```powershell
cd C:\xampp\htdocs\QUINCH\quinch_mobile
dart format .
flutter analyze
flutter test
flutter run -d emulator-5554 --dart-define=API_BASE_URL=http://10.0.2.2:8080/api/v1
```
Renvoyez les sorties de `flutter analyze` et `flutter test`, plus ce que vous avez vu sur l'émulateur.

## 7. Suite

- **Lot 5c-2** : notifications (liste par onglet, détail, lu / non lu, contestation, préférences sans réglage push), Premium selon `public-config`, classements, textes juridiques.
- **Étape 6** : photos, vidéo, publication et modification d'annonce, photo de profil, messagerie et contact vendeur.
