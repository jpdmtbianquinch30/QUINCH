import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/router.dart';

/// Navigation principale : une pile de navigation par onglet (l'état de chaque
/// onglet est conservé quand on change d'onglet).
///
/// Le bouton central « Publier » n'est pas un onglet : il ouvre le formulaire de
/// publication par-dessus l'onglet courant, qui reste inchangé.
class MainShell extends StatelessWidget {
  const MainShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  /// Position du bouton « Publier » dans la barre (entre Explorer et Favoris).
  static const publishIndex = 2;

  /// Les onglets (branches) sont 0 Accueil, 1 Explorer, 2 Favoris, 3 Compte ;
  /// dans la barre, « Publier » s'intercale à la position [publishIndex].
  static int _barIndexOfBranch(int branch) =>
      branch < publishIndex ? branch : branch + 1;

  static int _branchOfBarIndex(int barIndex) =>
      barIndex < publishIndex ? barIndex : barIndex - 1;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _barIndexOfBranch(navigationShell.currentIndex),
        onDestinationSelected: (index) {
          if (index == publishIndex) {
            context.push(sellPath);
            return;
          }
          final branch = _branchOfBarIndex(index);
          navigationShell.goBranch(
            branch,
            initialLocation: branch == navigationShell.currentIndex,
          );
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.play_circle_outline),
            selectedIcon: Icon(Icons.play_circle),
            label: 'Accueil',
          ),
          NavigationDestination(
            icon: Icon(Icons.explore_outlined),
            selectedIcon: Icon(Icons.explore),
            label: 'Explorer',
          ),
          NavigationDestination(
            icon: Icon(Icons.add_circle, size: 32),
            label: 'Publier',
            tooltip: 'Publier une annonce',
          ),
          NavigationDestination(
            icon: Icon(Icons.bookmark_border),
            selectedIcon: Icon(Icons.bookmark),
            label: 'Favoris',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Compte',
          ),
        ],
      ),
    );
  }
}
