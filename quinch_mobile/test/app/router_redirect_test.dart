import 'package:flutter_test/flutter_test.dart';
import 'package:quinch_mobile/app/router.dart';
import 'package:quinch_mobile/core/network/api_error.dart';
import 'package:quinch_mobile/core/session/session_state.dart';

import '../support/fakes.dart';

void main() {
  group('resolveRedirect', () {
    test('démarrage : tout mène à l\'écran de chargement', () {
      const s = SessionStarting();
      expect(resolveRedirect(s, splashPath), isNull);
      expect(resolveRedirect(s, homePath), splashPath);
      expect(resolveRedirect(s, loginPath), splashPath);
    });

    test(
      'serveur indisponible : on reste sur l\'écran de chargement (avec « Réessayer »)',
      () {
        final s = SessionUnavailable(ApiError.network());
        expect(resolveRedirect(s, homePath), splashPath);
        expect(resolveRedirect(s, splashPath), isNull);
      },
    );

    test('non connecté : seul l\'écran de connexion est public', () {
      const s = SessionUnauthenticated();
      expect(resolveRedirect(s, loginPath), isNull);
      expect(resolveRedirect(s, registerPath), isNull);
      expect(resolveRedirect(s, forgotPasswordPath), isNull);
      expect(resolveRedirect(s, homePath), loginPath);
      expect(resolveRedirect(s, productPath('robe-wax')), loginPath);
      expect(resolveRedirect(s, editProfilePath), loginPath);
      expect(resolveRedirect(s, settingsPath), loginPath);
      expect(resolveRedirect(s, premiumPath), loginPath);
      expect(resolveRedirect(s, splashPath), loginPath);
    });

    test('connecté : on quitte chargement et connexion', () {
      final s = SessionAuthenticated(testUser());
      expect(resolveRedirect(s, homePath), isNull);
      expect(resolveRedirect(s, explorePath), isNull);
      expect(resolveRedirect(s, searchPath), isNull);
      expect(resolveRedirect(s, productPath('robe-wax')), isNull);
      for (final path in <String>[
        sellerPath('fatou'),
        editProfilePath,
        myProductsPath,
        blockedUsersPath,
        supportPath,
        settingsPath,
        notificationsPath,
        notificationPath('abc'),
        notificationPreferencesPath,
        premiumPath,
        rankingsPath,
      ]) {
        expect(resolveRedirect(s, path), isNull, reason: path);
      }
      expect(resolveRedirect(s, splashPath), homePath);
      expect(resolveRedirect(s, loginPath), homePath);
      expect(resolveRedirect(s, registerPath), homePath);
      expect(resolveRedirect(s, forgotPasswordPath), homePath);
    });
  });

  test('chemin d\'une annonce : slug encodé', () {
    expect(productPath('robe wax'), '/product/robe%20wax');
    expect(sellerPath('awa_diop'), '/seller/awa_diop');
    expect(notificationPath('a b'), '/notifications/a%20b');
  });

  test('messages de fin de session', () {
    expect(SessionEndReason.none.message, isNull);
    expect(SessionEndReason.expired.message, contains('expiré'));
    expect(SessionEndReason.accountBanned.message, isNotNull);
    expect(SessionEndReason.accountSuspended.message, isNotNull);
    expect(SessionEndReason.accountDeleted.message, contains('supprimé'));
    expect(SessionEndReason.loggedOut.message, isNotNull);
  });
}
