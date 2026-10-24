import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quinch_mobile/core/network/api_error.dart';
import 'package:quinch_mobile/core/providers.dart';
import 'package:quinch_mobile/core/session/session_controller.dart';
import 'package:quinch_mobile/core/session/session_state.dart';

import '../support/fakes.dart';

void main() {
  final now = DateTime.utc(2026, 10, 19, 12);
  late FakeAuthRepository repo;
  late InMemoryTokenStorage storage;
  late ProviderContainer container;

  SessionController controller() =>
      container.read(sessionControllerProvider.notifier);
  SessionState state() => container.read(sessionControllerProvider);

  setUp(() {
    repo = FakeAuthRepository();
    storage = InMemoryTokenStorage();
    container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(repo),
        tokenStorageProvider.overrideWithValue(storage),
        clockProvider.overrideWithValue(() => now),
      ],
    );
    addTearDown(container.dispose);
  });

  test('état initial : démarrage', () {
    expect(state(), isA<SessionStarting>());
  });

  group('start()', () {
    test('sans jeton : non connecté, aucun appel réseau', () async {
      await controller().start();
      expect(state(), isA<SessionUnauthenticated>());
      expect(repo.meCalls, 0);
    });

    test('jeton valide : connecté, jeton chargé en mémoire', () async {
      storage.token = 'tok';
      storage.issuedAt = now.subtract(const Duration(days: 1));
      await controller().start();
      final s = state();
      expect(s, isA<SessionAuthenticated>());
      expect((s as SessionAuthenticated).user.fullName, 'Awa Diop');
      expect(container.read(authTokenHolderProvider).token, 'tok');
      expect(repo.refreshCalls, 0);
    });

    test('date d\'émission inconnue : on la pose sans rafraîchir', () async {
      storage.token = 'tok';
      await controller().start();
      expect(repo.refreshCalls, 0);
      expect(storage.issuedAt, now);
    });

    test('jeton de plus de 7 jours : rafraîchi et remplacé', () async {
      storage.token = 'tok';
      storage.issuedAt = now.subtract(const Duration(days: 8));
      await controller().start();
      expect(repo.refreshCalls, 1);
      expect(storage.token, 'tok-refreshed');
      expect(storage.issuedAt, now);
      expect(container.read(authTokenHolderProvider).token, 'tok-refreshed');
      expect(state(), isA<SessionAuthenticated>());
    });

    test('échec du rafraîchissement : la session reste ouverte', () async {
      storage.token = 'tok';
      storage.issuedAt = now.subtract(const Duration(days: 8));
      repo.onRefresh = () async => throw ApiError.network();
      await controller().start();
      expect(state(), isA<SessionAuthenticated>());
      expect(storage.token, 'tok');
    });

    test('401 : session expirée, jeton effacé', () async {
      storage.token = 'tok';
      repo.onMe = () async =>
          throw ApiError.fromResponse(401, <String, dynamic>{});
      await controller().start();
      final s = state();
      expect(s, isA<SessionUnauthenticated>());
      expect((s as SessionUnauthenticated).reason, SessionEndReason.expired);
      expect(storage.token, isNull);
      expect(container.read(authTokenHolderProvider).token, isNull);
    });

    test('compte banni : motif conservé', () async {
      storage.token = 'tok';
      repo.onMe = () async => throw ApiError.fromResponse(
        403,
        <String, dynamic>{'error': 'account_banned'},
      );
      await controller().start();
      expect(
        (state() as SessionUnauthenticated).reason,
        SessionEndReason.accountBanned,
      );
    });

    test('compte suspendu : motif conservé', () async {
      storage.token = 'tok';
      repo.onMe = () async => throw ApiError.fromResponse(
        403,
        <String, dynamic>{'error': 'account_suspended'},
      );
      await controller().start();
      expect(
        (state() as SessionUnauthenticated).reason,
        SessionEndReason.accountSuspended,
      );
    });

    test('panne réseau : jeton conservé, état « indisponible »', () async {
      storage.token = 'tok';
      repo.onMe = () async => throw ApiError.network();
      await controller().start();
      expect(state(), isA<SessionUnavailable>());
      expect(storage.token, 'tok');
      expect(container.read(authTokenHolderProvider).token, 'tok');
    });

    test('maintenance ou erreur 5xx : jamais de déconnexion', () async {
      storage.token = 'tok';
      repo.onMe = () async => throw ApiError.fromResponse(
        503,
        <String, dynamic>{'error': 'maintenance'},
      );
      await controller().start();
      expect(state(), isA<SessionUnavailable>());
      expect(storage.token, 'tok');
    });

    test('réessayer après une panne : la session se rétablit', () async {
      storage.token = 'tok';
      storage.issuedAt = now;
      repo.onMe = () async => throw ApiError.network();
      await controller().start();
      expect(state(), isA<SessionUnavailable>());
      repo.onMe = () async => testUser();
      await controller().start();
      expect(state(), isA<SessionAuthenticated>());
    });
  });

  group('connexion', () {
    test('succès : jeton persisté et session ouverte', () async {
      await controller().start();
      await controller().login(email: 'awa@example.com', password: 'Secret123');
      expect(state(), isA<SessionAuthenticated>());
      expect(storage.token, 'tok-new');
      expect(storage.issuedAt, now);
      expect(container.read(authTokenHolderProvider).token, 'tok-new');
    });

    test('échec : l\'erreur est relancée, rien n\'est stocké', () async {
      await controller().start();
      repo.onLogin = () async =>
          throw ApiError.fromResponse(422, <String, dynamic>{
            'errors': <String, dynamic>{
              'email': <String>['Identifiants incorrects.'],
            },
          });
      await expectLater(
        controller().login(email: 'a@b.c', password: 'x'),
        throwsA(
          isA<ApiError>().having(
            (e) => e.kind,
            'kind',
            ApiErrorKind.validation,
          ),
        ),
      );
      expect(state(), isA<SessionUnauthenticated>());
      expect(storage.token, isNull);
    });

    test('inscription : même traitement que la connexion', () async {
      await controller().start();
      await controller().register(
        email: 'awa@example.com',
        fullName: 'Awa Diop',
        username: 'awa',
        password: 'Secret123',
        passwordConfirmation: 'Secret123',
      );
      expect(state(), isA<SessionAuthenticated>());
      expect(storage.token, 'tok-new');
    });
  });

  group('déconnexion et invalidation', () {
    test('logout : session fermée même si le serveur échoue', () async {
      storage.token = 'tok';
      await controller().start();
      repo.onLogout = () async => throw ApiError.network();
      await controller().logout();
      expect(repo.logoutCalls, 1);
      final s = state();
      expect(s, isA<SessionUnauthenticated>());
      expect((s as SessionUnauthenticated).reason, SessionEndReason.loggedOut);
      expect(storage.token, isNull);
      expect(container.read(authTokenHolderProvider).token, isNull);
    });

    test(
      'handleSessionInvalid : ferme la session, le premier motif est conservé',
      () async {
        storage.token = 'tok';
        await controller().start();
        controller().handleSessionInvalid(
          ApiError.fromResponse(403, <String, dynamic>{
            'error': 'account_suspended',
          }),
        );
        controller().handleSessionInvalid(
          ApiError.fromResponse(401, <String, dynamic>{}),
        );
        await Future<void>.delayed(Duration.zero);
        expect(
          (state() as SessionUnauthenticated).reason,
          SessionEndReason.accountSuspended,
        );
        expect(storage.token, isNull);
      },
    );

    test(
      'updateUser : remplace l\'utilisateur seulement si connecté',
      () async {
        controller().updateUser(testUser(name: 'Ignoré'));
        expect(state(), isA<SessionStarting>());

        storage.token = 'tok';
        await controller().start();
        controller().updateUser(testUser(name: 'Nouveau Nom'));
        expect((state() as SessionAuthenticated).user.fullName, 'Nouveau Nom');
      },
    );
  });
}
