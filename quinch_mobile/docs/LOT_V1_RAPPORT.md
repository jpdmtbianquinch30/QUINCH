# Lot V1 — jetons de design, police Inter, thèmes de composants

Statut : **non validé**. Code écrit et relu, mais ni compilé ni testé (Flutter indisponible
dans l'environnement de rédaction). La validation attend vos résultats.

## Fichiers (chemins relatifs à `quinch_mobile/`)

| Fichier | Nature |
|---|---|
| `lib/app/theme.dart` | modifié : palettes sombre/clair d'Angular, rayons, espacements, dégradé, thèmes de composants |
| `lib/shared/widgets/app_widgets.dart` | modifié : `LoadingButton` avec dégradé et halo ; bordure des 2 champs confiée au thème |
| `pubspec.yaml` | modifié : déclaration de la police Inter (aucune dépendance ajoutée) |
| `assets/fonts/Inter-{Regular,Medium,SemiBold,Bold}.ttf` | nouveaux (Inter 4.1) |
| `assets/fonts/LICENSE-Inter.txt` | nouveau (SIL OFL 1.1) |
| `test/app/theme_test.dart` | nouveau |

Non touchés : Laravel, Angular, Docker, `android/`.

## À exécuter (dans cet ordre)

```
flutter pub get
dart format .
flutter analyze
flutter test
```

Envoyez-moi les sorties complètes, et si possible des captures de l'émulateur (sombre ET clair)
de : connexion, Accueil, Explorer, détail d'une annonce, Compte, Paramètres, une feuille de filtres.

## Points vérifiés / non vérifiés

- Vérifié : les noms et paramètres d'API utilisés (`CardThemeData`, `DialogThemeData`,
  `AppBarThemeData`, `InputDecorationThemeData`, constructeur `ColorScheme`, etc.) existent
  dans le code source de Flutter 3.38.4 ; la syntaxe des 3 fichiers Dart est valide.
- **Non vérifié** : compilation, `flutter analyze`, tests, rendu à l'écran.
- Les tests existants n'utilisent pas ce thème (`MaterialApp.router` sans thème) et retrouvent
  les boutons par `FilledButton` : `LoadingButton` reste un `FilledButton`.

## Choix à connaître

1. Puces sélectionnées : fond accent translucide + texte normal (Angular : fond accent plein,
   texte blanc). Choix de robustesse : la lisibilité ne dépend pas de l'état de la puce.
2. Texte blanc sur l'émeraude Service : contraste faible (≈ 2,5), identique à Angular.
   À trancher plus tard (texte foncé ou vert plus sombre).
3. `ColorScheme.outline` = gris visible (utilisé pour des icônes) ; la bordure translucide
   d'Angular est `outlineVariant`.
4. Une quinzaine d'écrans posent encore `border: OutlineInputBorder()` sur leurs champs.
   Le thème définit tous les états de bordure ; l'effet réel est à confirmer sur capture.
5. Pas encore fait (lots suivants) : mode sombre par défaut + interrupteur (V2), logo (V2),
   notifications SnackBar teintées succès/erreur, cartes d'annonce enrichies (V3).
6. Barre du bas : indicateur et couleurs changent, mais le bouton Publier garde son icône
   actuelle jusqu'au lot V6.
