import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:quinch_mobile/app/router.dart';
import 'package:quinch_mobile/core/network/api_error.dart';
import 'package:quinch_mobile/core/providers.dart';
import 'package:quinch_mobile/core/session/session_controller.dart';
import 'package:quinch_mobile/core/session/session_state.dart';
import 'package:quinch_mobile/features/auth/forgot_password_page.dart';
import 'package:quinch_mobile/features/auth/login_page.dart';
import 'package:quinch_mobile/features/auth/register_page.dart';
import 'package:quinch_mobile/data/models/user.dart';

import '../support/fakes.dart';

/// Monte une page dans un routeur minimal : les autres écrans sont remplacés par
/// des textes repères (aucune dépendance au vrai routeur ni au réseau).
Future<ProviderContainer> pumpPage(
  WidgetTester tester,
  Widget page,
  FakeAuthRepository repo,
) async {
  final container = ProviderContainer(
    overrides: [
      authRepositoryProvider.overrideWithValue(repo),
      tokenStorageProvider.overrideWithValue(InMemoryTokenStorage()),
      clockProvider.overrideWithValue(() => DateTime.utc(2026, 10, 19)),
    ],
  );
  addTearDown(container.dispose);

  Widget marker(String text) => Scaffold(body: Center(child: Text(text)));
  final router = GoRouter(
    routes: <RouteBase>[
      GoRoute(path: '/', builder: (context, state) => page),
      GoRoute(
        path: loginPath,
        builder: (context, state) => marker('ÉCRAN CONNEXION'),
      ),
      GoRoute(
        path: registerPath,
        builder: (context, state) => marker('ÉCRAN INSCRIPTION'),
      ),
      GoRoute(
        path: forgotPasswordPath,
        builder: (context, state) => marker('ÉCRAN OUBLI'),
      ),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

Finder field(int index) => find.byType(TextFormField).at(index);

Future<void> tapButton(WidgetTester tester, String label) async {
  final finder = find.widgetWithText(FilledButton, label);
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  group('LoginPage', () {
    testWidgets('formulaire vide : erreurs de saisie, aucun appel', (
      tester,
    ) async {
      final repo = FakeAuthRepository();
      await pumpPage(tester, const LoginPage(), repo);

      await tapButton(tester, 'Se connecter');

      expect(find.text('Saisissez votre adresse email.'), findsOneWidget);
      expect(find.text('Saisissez votre mot de passe.'), findsOneWidget);
      expect(repo.loginCalls, 0);
    });

    testWidgets('saisie valide : connexion et session ouverte', (tester) async {
      final repo = FakeAuthRepository();
      final container = await pumpPage(tester, const LoginPage(), repo);

      await tester.enterText(field(0), '  awa@example.sn ');
      await tester.enterText(field(1), 'Secret123');
      await tapButton(tester, 'Se connecter');

      expect(repo.loginCalls, 1);
      expect(repo.lastLoginEmail, 'awa@example.sn');
      expect(repo.lastLoginPassword, 'Secret123');
      expect(
        container.read(sessionControllerProvider),
        isA<SessionAuthenticated>(),
      );
    });

    testWidgets('refus du serveur : message affiché, session inchangée', (
      tester,
    ) async {
      final repo = FakeAuthRepository()
        ..onLogin = () async =>
            throw ApiError.fromResponse(422, <String, dynamic>{
              'message': 'invalide',
              'errors': <String, dynamic>{
                'email': <String>['Identifiants incorrects.'],
              },
            });
      final container = await pumpPage(tester, const LoginPage(), repo);

      await tester.enterText(field(0), 'awa@example.sn');
      await tester.enterText(field(1), 'mauvais');
      await tapButton(tester, 'Se connecter');

      expect(find.text('Identifiants incorrects.'), findsOneWidget);
      expect(
        container.read(sessionControllerProvider),
        isNot(isA<SessionAuthenticated>()),
      );
    });

    testWidgets('pendant la requête : bouton désactivé', (tester) async {
      final pending = Completer<AuthSession>();
      final repo = FakeAuthRepository()..onLogin = () => pending.future;
      await pumpPage(tester, const LoginPage(), repo);

      await tester.enterText(field(0), 'awa@example.sn');
      await tester.enterText(field(1), 'Secret123');
      await tester.tap(find.widgetWithText(FilledButton, 'Se connecter'));
      await tester.pump();

      final button = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(button.onPressed, isNull);

      pending.complete(testSession());
      await tester.pumpAndSettle();
      expect(repo.loginCalls, 1);
    });

    testWidgets('liens vers inscription et mot de passe oublié', (
      tester,
    ) async {
      await pumpPage(tester, const LoginPage(), FakeAuthRepository());

      await tester.ensureVisible(find.text('Créer un compte'));
      await tester.tap(find.text('Créer un compte'));
      await tester.pumpAndSettle();
      expect(find.text('ÉCRAN INSCRIPTION'), findsOneWidget);
    });
  });

  group('RegisterPage', () {
    Future<void> fillValid(WidgetTester tester) async {
      await tester.enterText(field(0), 'Awa Diop');
      await tester.enterText(field(1), 'awa_diop');
      await tester.enterText(field(2), 'awa@example.sn');
      await tester.enterText(field(3), 'Secret123');
      await tester.enterText(field(4), 'Secret123');
    }

    testWidgets('sans acceptation des conditions : refusé localement', (
      tester,
    ) async {
      final repo = FakeAuthRepository();
      await pumpPage(tester, const RegisterPage(), repo);

      await fillValid(tester);
      await tapButton(tester, 'Créer mon compte');

      expect(
        find.text('Vous devez accepter les conditions pour continuer.'),
        findsOneWidget,
      );
      expect(repo.lastRegister, isNull);
    });

    testWidgets('inscription valide : envoyée au serveur, session ouverte', (
      tester,
    ) async {
      final repo = FakeAuthRepository();
      final container = await pumpPage(tester, const RegisterPage(), repo);

      await fillValid(tester);
      await tester.ensureVisible(find.byType(CheckboxListTile));
      await tester.tap(find.byType(CheckboxListTile));
      await tester.pump();
      await tapButton(tester, 'Créer mon compte');

      expect(repo.lastRegister, <String, String>{
        'email': 'awa@example.sn',
        'fullName': 'Awa Diop',
        'username': 'awa_diop',
        'password': 'Secret123',
        'passwordConfirmation': 'Secret123',
      });
      expect(
        container.read(sessionControllerProvider),
        isA<SessionAuthenticated>(),
      );
    });

    testWidgets('erreur du serveur sur un champ : affichée sous ce champ', (
      tester,
    ) async {
      final repo = FakeAuthRepository()
        ..onRegister = () async =>
            throw ApiError.fromResponse(422, <String, dynamic>{
              'message': 'invalide',
              'errors': <String, dynamic>{
                'username': <String>["Ce nom d'utilisateur est déjà pris."],
              },
            });
      await pumpPage(tester, const RegisterPage(), repo);

      await fillValid(tester);
      await tester.ensureVisible(find.byType(CheckboxListTile));
      await tester.tap(find.byType(CheckboxListTile));
      await tester.pump();
      await tapButton(tester, 'Créer mon compte');

      expect(find.text("Ce nom d'utilisateur est déjà pris."), findsOneWidget);
    });
  });

  group('ForgotPasswordPage', () {
    testWidgets('étape 1 : demande du code, puis étape 2', (tester) async {
      final repo = FakeAuthRepository();
      await pumpPage(tester, const ForgotPasswordPage(), repo);

      await tester.enterText(field(0), 'awa@example.sn');
      await tapButton(tester, 'Envoyer le code');

      expect(repo.resetRequests, <String>['awa@example.sn']);
      expect(find.text('Code reçu par email'), findsOneWidget);
    });

    testWidgets(
      'étape 2 : changement du mot de passe puis retour à la connexion',
      (tester) async {
        final repo = FakeAuthRepository();
        await pumpPage(tester, const ForgotPasswordPage(), repo);

        await tester.enterText(field(0), 'awa@example.sn');
        await tapButton(tester, 'Envoyer le code');

        await tester.enterText(field(0), '123456');
        await tester.enterText(field(1), 'Nouveau123');
        await tester.enterText(field(2), 'Nouveau123');
        await tapButton(tester, 'Changer le mot de passe');

        expect(repo.lastReset, <String, String>{
          'email': 'awa@example.sn',
          'otp': '123456',
          'password': 'Nouveau123',
          'passwordConfirmation': 'Nouveau123',
        });
        expect(find.text('ÉCRAN CONNEXION'), findsOneWidget);
      },
    );

    testWidgets('code invalide : message du serveur, on reste sur l\'écran', (
      tester,
    ) async {
      final repo = FakeAuthRepository()
        ..onResetPassword = () async =>
            throw ApiError.fromResponse(422, <String, dynamic>{
              'error': 'invalid_otp',
              'message': 'Code invalide ou expiré.',
            });
      await pumpPage(tester, const ForgotPasswordPage(), repo);

      await tester.enterText(field(0), 'awa@example.sn');
      await tapButton(tester, 'Envoyer le code');
      await tester.enterText(field(0), '000000');
      await tester.enterText(field(1), 'Nouveau123');
      await tester.enterText(field(2), 'Nouveau123');
      await tapButton(tester, 'Changer le mot de passe');

      expect(find.text('Code invalide ou expiré.'), findsOneWidget);
      expect(find.text('ÉCRAN CONNEXION'), findsNothing);
    });
  });
}
