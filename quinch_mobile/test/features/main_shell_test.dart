import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:quinch_mobile/app/router.dart';
import 'package:quinch_mobile/features/shell/main_shell.dart';

Widget page(String label) => Scaffold(body: Center(child: Text(label)));

StatefulShellBranch branch(String path, String label) => StatefulShellBranch(
  routes: <RouteBase>[
    GoRoute(path: path, builder: (context, state) => page(label)),
  ],
);

/// Mini-application : mêmes quatre onglets que la vraie, pages factices.
GoRouter buildRouter() => GoRouter(
  initialLocation: '/a',
  routes: <RouteBase>[
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) =>
          MainShell(navigationShell: navigationShell),
      branches: <StatefulShellBranch>[
        branch('/a', 'PAGE ACCUEIL'),
        branch('/b', 'PAGE EXPLORER'),
        branch('/c', 'PAGE FAVORIS'),
        branch('/d', 'PAGE COMPTE'),
      ],
    ),
    GoRoute(path: sellPath, builder: (context, state) => page('PAGE VENDRE')),
  ],
);

int selectedIndex(WidgetTester tester) =>
    tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex;

void main() {
  testWidgets('la barre propose Publier au centre', (tester) async {
    await tester.pumpWidget(MaterialApp.router(routerConfig: buildRouter()));
    await tester.pumpAndSettle();

    final bar = tester.widget<NavigationBar>(find.byType(NavigationBar));
    expect(bar.destinations, hasLength(5));
    for (final label in [
      'Accueil',
      'Explorer',
      'Publier',
      'Favoris',
      'Compte',
    ]) {
      expect(find.text(label), findsOneWidget, reason: label);
    }
    expect(find.text('PAGE ACCUEIL'), findsOneWidget);
    expect(selectedIndex(tester), 0);
  });

  testWidgets('Publier ouvre le formulaire sans quitter l\'onglet courant', (
    tester,
  ) async {
    final router = buildRouter();
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Explorer'));
    await tester.pumpAndSettle();
    expect(find.text('PAGE EXPLORER'), findsOneWidget);

    await tester.tap(find.text('Publier'));
    await tester.pumpAndSettle();
    expect(find.text('PAGE VENDRE'), findsOneWidget);

    router.pop();
    await tester.pumpAndSettle();
    expect(find.text('PAGE EXPLORER'), findsOneWidget);
    expect(selectedIndex(tester), 1);
  });

  testWidgets('Favoris et Compte restent liés aux bons onglets', (
    tester,
  ) async {
    await tester.pumpWidget(MaterialApp.router(routerConfig: buildRouter()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Favoris'));
    await tester.pumpAndSettle();
    expect(find.text('PAGE FAVORIS'), findsOneWidget);
    expect(selectedIndex(tester), 3);

    await tester.tap(find.text('Compte'));
    await tester.pumpAndSettle();
    expect(find.text('PAGE COMPTE'), findsOneWidget);
    expect(selectedIndex(tester), 4);

    await tester.tap(find.text('Accueil'));
    await tester.pumpAndSettle();
    expect(find.text('PAGE ACCUEIL'), findsOneWidget);
    expect(selectedIndex(tester), 0);
  });
}
