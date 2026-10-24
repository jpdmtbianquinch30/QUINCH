import 'package:flutter_test/flutter_test.dart';
import 'package:quinch_mobile/app/router.dart';
import 'package:quinch_mobile/core/format/time_ago.dart';
import 'package:quinch_mobile/features/notifications/notification_providers.dart';

void main() {
  group('timeAgoFr', () {
    final now = DateTime.utc(2026, 10, 19, 12);

    test('récent', () {
      expect(
        timeAgoFr(now.subtract(const Duration(seconds: 20)), now: now),
        "à l'instant",
      );
      expect(
        timeAgoFr(now.add(const Duration(minutes: 5)), now: now),
        "à l'instant",
      );
    });

    test('minutes, heures, jours', () {
      expect(
        timeAgoFr(now.subtract(const Duration(minutes: 5)), now: now),
        'il y a 5 min',
      );
      expect(
        timeAgoFr(now.subtract(const Duration(hours: 3)), now: now),
        'il y a 3 h',
      );
      expect(
        timeAgoFr(now.subtract(const Duration(days: 1, hours: 2)), now: now),
        'hier',
      );
      expect(
        timeAgoFr(now.subtract(const Duration(days: 4)), now: now),
        'il y a 4 j',
      );
    });

    test('au-delà d\'une semaine : date', () {
      final text = timeAgoFr(now.subtract(const Duration(days: 30)), now: now);
      expect(RegExp(r'^\d{2}/\d{2}/\d{4}$').hasMatch(text), isTrue);
    });

    test('date et heure', () {
      final text = formatDateTimeFr(DateTime(2026, 3, 5, 9, 7));
      expect(text, '05/03/2026 à 09:07');
    });
  });

  group('appPathForNotification', () {
    test('adresses connues', () {
      expect(
        appPathForNotification('/product/robe-wax'),
        productPath('robe-wax'),
      );
      expect(appPathForNotification('/seller/fatou'), sellerPath('fatou'));
      expect(appPathForNotification('/profile/edit'), editProfilePath);
      expect(appPathForNotification('/profile'), accountPath);
    });

    test('sans équivalent dans l\'application : aucune navigation', () {
      expect(appPathForNotification('/messages'), isNull);
      expect(appPathForNotification('/messages?user=abc'), isNull);
      expect(appPathForNotification('/admin/inbox'), isNull);
      expect(appPathForNotification('/guide/index.html'), isNull);
      expect(appPathForNotification('/product'), isNull);
      expect(appPathForNotification('/profile/settings/x'), isNull);
    });

    test('valeurs invalides ou externes : jamais ouvertes', () {
      expect(appPathForNotification(null), isNull);
      expect(appPathForNotification(''), isNull);
      expect(appPathForNotification('https://evil.example/product/x'), isNull);
      expect(appPathForNotification('product/robe'), isNull);
      expect(appPathForNotification('javascript:alert(1)'), isNull);
    });
  });
}
