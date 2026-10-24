# QUINCH Mobile — Étape 5, lot 5c-2a : notifications

## 0. État réel

- **Rien de ce lot n'a été compilé, analysé ni testé** (Flutter reste inaccessible de mon côté). Le lot 5c-1 est validé chez vous : 221 tests réussis.
- Tests écrits dans ce lot : **43 nouveaux** (264 au total), **aucun exécuté**.
- Contrôles faits : tous les `import` pointent vers des fichiers existants, aucun import inutile ni enchaînement `..a = … ..b = …` risqué détecté par un script. Ce n'est pas un compilateur.
- Aucune dépendance ajoutée. Backend, Docker, docker-compose : intacts.
- Modifications de code déjà validé : `AppNotification`, `NotificationPreference` et `NotificationDetail` (modèles), `PagedCore` (ajout d'une méthode de mise à jour d'un élément), le feed (cloche), le compte et les paramètres (nouvelles entrées), le routeur.

## 1. Livré

| Écran | Ce qu'il fait | Endpoints |
|---|---|---|
| Cloche (barre du feed) | Pastille du nombre de non lues ; ouvre la liste ; recompte au retour | `GET notifications/unread-count` |
| Notifications | 4 onglets (Toutes, Interactions, Messages, Système) avec le nombre de non lues ; liste paginée ; une notification s'ouvre et se marque lue ; suppression ; « Tout marquer comme lu » (de l'onglet) | `GET notifications`, `POST notifications/{id}/read`, `POST notifications/read-all`, `DELETE notifications/{id}` |
| Détail | Titre, texte, date ; bouton « Voir » si la notification mène à un écran de l'application ; contester une décision, ou répondre à l'équipe ; statut et réponse de l'équipe | `GET notifications/{id}`, `POST notifications/{id}/contest` |
| Préférences | Par type : « Dans l'application » et « Par email » | `GET` et `PUT notifications/preferences` |

Entrées ajoutées : « Notifications » dans le Compte, « Préférences de notification » dans les Paramètres.

## 2. Décisions

- **Aucun push** : il n'y a pas de réglage « push » à l'écran et le texte précise que les notifications sur l'appareil ne sont pas disponibles. Le serveur n'a aucun mécanisme d'enregistrement d'appareil.
- **Préférences** : le serveur remplace une valeur absente par sa valeur par défaut (push et application à vrai, email à faux). L'application envoie donc toujours la liste complète avec les trois valeurs, en renvoyant `push_enabled` tel qu'elle l'a reçu. Un test le vérifie. En cas d'échec, le réglage revient à son état précédent.
- **Adresses de page** : les notifications portent une adresse du site web (`/product/…`, `/seller/…`, `/profile`, `/profile/edit`, `/messages…`, `/admin/…`, `/guide/…`). Seules les quatre premières ont un équivalent dans l'application ; les autres n'ouvrent rien. Les adresses externes, relatives ou mal formées sont ignorées : une adresse venue du serveur n'ouvre jamais un écran qui n'est pas dans la liste.
- **Contestation et réponse** : un message de l'équipe (`type = message`) affiche « Répondre » ; une décision de modération affiche « Contester cette décision ». Longueur 10 à 2000 caractères, contrôlée avant l'envoi. Les erreurs du serveur (contestation déjà en cours, décision non contestable) s'affichent dans la fenêtre. Seul le statut `pending` est certain ; tout autre statut avec une date de traitement s'affiche « Traitée », avec la réponse de l'équipe s'il y en a une.
- **Pas de temps réel** : le nombre de non lues est relu quand on revient de la liste et à l'ouverture du feed. Il n'y a pas de rafraîchissement automatique en arrière-plan.
- **Lecture** : ouvrir une notification la marque lue avant d'afficher le détail ; si cet appel échoue, le détail s'ouvre quand même. Le serveur ne la marque pas lue lui-même.

## 3. Limites connues

1. **Bandeaux d'annonces** (`notifications/announcements`) : non faits, leur forme n'a pas été vérifiée.
2. **Messagerie** : une notification de message n'ouvre pas encore la conversation (étape 6).
3. Pas de mise à jour automatique : une notification arrivée pendant que l'application est ouverte n'apparaît qu'en tirant pour actualiser ou en rouvrant l'écran.
4. Les icônes se basent sur le type ; un type inconnu reçoit l'icône générique.

## 4. À essayer sur l'émulateur

Il faut des notifications dans la base. Vous en obtenez en agissant depuis un deuxième compte : aimer ou enregistrer une annonce de votre compte, s'abonner à votre profil. Un message de l'équipe ou un retrait de vidéo se déclenche depuis le panneau d'administration du site.

1. Feed : la cloche affiche la pastille ; l'ouvrir ; revenir : la pastille est mise à jour.
2. Notifications : onglets avec compteurs ; ouvrir une non lue (elle se marque lue) ; supprimer ; « Tout marquer comme lu ».
3. Détail d'une notification d'annonce ou de vendeur : bouton « Voir ».
4. Détail d'une décision de modération : contester avec moins de 10 caractères (refus), puis avec un message valide ; le statut passe à « En cours d'examen ».
5. Compte, Paramètres, Préférences de notification : activer « Par email » sur un type ; vérifier sur le site que le réglage est resté.

## 5. Commandes

Copiez le contenu de `quinch_mobile_etape5c2a.zip` par-dessus votre dossier (il ne contient pas `android/`), puis :
```powershell
cd C:\xampp\htdocs\QUINCH\quinch_mobile
dart format .
flutter analyze
flutter test
flutter run -d emulator-5554 --dart-define=API_BASE_URL=http://10.0.2.2:8080/api/v1
```
Renvoyez les sorties de `flutter analyze` et `flutter test`, plus ce que vous avez vu sur l'émulateur.

## 6. Suite

- **Lot 5c-2b** : Premium selon `public-config` (offres, statut, offre de lancement, paiement jamais déclaré réussi sans confirmation du serveur) et classements.
- **Lot 5c-2c** : textes juridiques (conditions d'utilisation, confidentialité), bloquants avant l'ouverture de l'inscription au public.
- **Étape 6** : photos, vidéo, publication et modification d'annonce, photo de profil, messagerie.
