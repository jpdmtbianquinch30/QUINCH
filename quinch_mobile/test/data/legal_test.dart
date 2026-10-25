import 'package:flutter_test/flutter_test.dart';
import 'package:quinch_mobile/core/config/app_config.dart';
import 'package:quinch_mobile/core/network/api_client.dart';
import 'package:quinch_mobile/core/network/auth_token_holder.dart';
import 'package:quinch_mobile/core/network/dio_factory.dart';
import 'package:quinch_mobile/data/models/legal.dart';
import 'package:quinch_mobile/data/repositories/legal_repository.dart';

import '../support/fakes.dart';

// Lecture de réponses simulées d'après `LegalController::info` du backend.
// Elles ne prouvent pas le comportement d'un vrai serveur.

void main() {
  group('LegalInfo.fromJson', () {
    test('lit toutes les informations fournies par le serveur', () {
      final info = LegalInfo.fromJson(<String, dynamic>{
        'publisher': <String, dynamic>{
          'name': 'Atelier Test SARL',
          'status': 'SARL',
          'address': '1 rue de Test, Dakar',
          'registration': 'NINEA 000000',
          'director': 'Awa Test',
        },
        'cdp_receipt': 'CDP-0001',
        'contact_email': 'contact@example.sn',
        'privacy_email': 'privacy@example.sn',
        'hosting': <String, dynamic>{
          'provider': 'Hébergeur Test',
          'location': 'Pays Test',
        },
        'versions': <String, dynamic>{'terms': '2026-10', 'privacy': '2026-11'},
        'retention': <String, dynamic>{
          'anonymized_content_days': 30,
          'audit_logs_days': '180',
        },
      });

      expect(info.publisher.name, 'Atelier Test SARL');
      expect(info.publisher.status, 'SARL');
      expect(info.publisher.address, '1 rue de Test, Dakar');
      expect(info.publisher.registration, 'NINEA 000000');
      expect(info.publisher.director, 'Awa Test');
      expect(info.cdpReceipt, 'CDP-0001');
      expect(info.contactEmail, 'contact@example.sn');
      expect(info.privacyEmail, 'privacy@example.sn');
      expect(info.hostingProvider, 'Hébergeur Test');
      expect(info.hostingLocation, 'Pays Test');
      expect(info.termsVersion, '2026-10');
      expect(info.privacyVersion, '2026-11');
      expect(info.anonymizedContentDays, 30);
      expect(info.auditLogsDays, 180);
    });

    test('valeurs vides : null, rien n\'est inventé', () {
      final info = LegalInfo.fromJson(<String, dynamic>{
        'publisher': <String, dynamic>{'name': '', 'address': ''},
        'cdp_receipt': '',
        'contact_email': '',
        'hosting': <String, dynamic>{'provider': '', 'location': ''},
        'versions': <String, dynamic>{},
        'retention': <String, dynamic>{},
      });

      expect(info.publisher.name, isNull);
      expect(info.publisher.address, isNull);
      expect(info.cdpReceipt, isNull);
      expect(info.contactEmail, isNull);
      expect(info.hostingProvider, isNull);
      expect(info.termsVersion, isNull);
      expect(info.anonymizedContentDays, isNull);
      expect(info.auditLogsDays, isNull);
    });

    test('réponse inattendue : aucune exception', () {
      final info = LegalInfo.fromJson(null);
      expect(info.publisher.name, isNull);
      expect(info.contactEmail, isNull);
      expect(LegalInfo.fromJson('texte').privacyVersion, isNull);
    });
  });

  group('LegalRepository', () {
    late FakeAdapter adapter;
    late ApiClient api;

    setUp(() {
      adapter = FakeAdapter(
        (o) async => jsonResponse(<String, dynamic>{
          'publisher': <String, dynamic>{'name': 'Atelier Test SARL'},
          'contact_email': 'contact@example.sn',
          'versions': <String, dynamic>{'terms': '2026-10'},
        }, 200),
      );
      final config = AppConfig.parse(
        'https://api.quinch.sn/api/v1',
        allowInsecure: false,
      );
      final tokens = AuthTokenHolder();
      api = ApiClient(
        dio: createDio(config: config, tokens: tokens, adapter: adapter),
        tokens: tokens,
      );
    });

    test('GET legal/info, sans jeton, sans corps', () async {
      final info = await LegalRepository(api).info();

      final request = adapter.requests.single;
      expect(request.method, 'GET');
      expect(request.uri.path, '/api/v1/legal/info');
      expect(request.headers.containsKey('Authorization'), isFalse);
      expect(info.publisher.name, 'Atelier Test SARL');
      expect(info.termsVersion, '2026-10');
    });
  });
}
