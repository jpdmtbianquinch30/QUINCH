import 'package:flutter_test/flutter_test.dart';
import 'package:quinch_mobile/core/config/app_config.dart';

void main() {
  group('AppConfig.parse', () {
    test(
      'debug sans valeur : utilise la valeur par défaut du backend local',
      () {
        final config = AppConfig.parse('', allowInsecure: true);
        expect(config.apiBaseUrl, 'http://10.0.2.2:8080/api/v1/');
        expect(config.apiHost, '10.0.2.2');
      },
    );

    test('hors debug sans valeur : refusé', () {
      expect(
        () => AppConfig.parse('', allowInsecure: false),
        throwsA(isA<ConfigException>()),
      );
    });

    test('hors debug : http refusé', () {
      expect(
        () => AppConfig.parse(
          'http://api.quinch.sn/api/v1',
          allowInsecure: false,
        ),
        throwsA(isA<ConfigException>()),
      );
    });

    test('hors debug : https accepté et terminé par un slash', () {
      final config = AppConfig.parse(
        'https://api.quinch.sn/api/v1',
        allowInsecure: false,
      );
      expect(config.apiBaseUrl, 'https://api.quinch.sn/api/v1/');
      expect(config.apiHost, 'api.quinch.sn');
    });

    test('debug : http accepté', () {
      final config = AppConfig.parse(
        'http://192.168.1.20:8080/api/v1/',
        allowInsecure: true,
      );
      expect(config.apiBaseUrl, 'http://192.168.1.20:8080/api/v1/');
    });

    test('identifiants dans l\'URL refusés', () {
      expect(
        () => AppConfig.parse(
          'https://user:pass@api.quinch.sn/api/v1',
          allowInsecure: false,
        ),
        throwsA(isA<ConfigException>()),
      );
    });

    test('paramètres et fragment refusés', () {
      expect(
        () => AppConfig.parse(
          'https://api.quinch.sn/api/v1?x=1',
          allowInsecure: false,
        ),
        throwsA(isA<ConfigException>()),
      );
      expect(
        () => AppConfig.parse(
          'https://api.quinch.sn/api/v1#f',
          allowInsecure: false,
        ),
        throwsA(isA<ConfigException>()),
      );
    });

    test('valeur invalide refusée', () {
      expect(
        () => AppConfig.parse('pas une url', allowInsecure: true),
        throwsA(isA<ConfigException>()),
      );
      expect(
        () => AppConfig.parse('ftp://api.quinch.sn/', allowInsecure: true),
        throwsA(isA<ConfigException>()),
      );
    });

    test('les médias relatifs sont résolus sur l\'origine du serveur', () {
      final config = AppConfig.parse(
        'https://api.quinch.sn/api/v1',
        allowInsecure: false,
      );
      expect(
        config.media.resolve('/api/v1/videos/abc/stream'),
        'https://api.quinch.sn/api/v1/videos/abc/stream',
      );
    });
  });
}
