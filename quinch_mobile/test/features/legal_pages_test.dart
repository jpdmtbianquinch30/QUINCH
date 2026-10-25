import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quinch_mobile/core/network/api_error.dart';
import 'package:quinch_mobile/data/models/legal.dart';
import 'package:quinch_mobile/features/auth/register_page.dart';
import 'package:quinch_mobile/features/legal/legal_content.dart';
import 'package:quinch_mobile/features/legal/legal_page.dart';
import 'package:quinch_mobile/features/profile/settings_page.dart';

import '../support/fakes.dart';
import '../support/pump.dart';

String allText(LegalDocument doc) => [
  doc.title,
  doc.version,
  for (final s in doc.sections) ...[s.title, ...s.paragraphs],
].join('\n');

void main() {
  group('Contenu juridique (reprise du texte web)', () {
    test('conditions : 12 articles, éditeur et contact issus du serveur', () {
      final doc = buildLegalDocument(LegalDocKey.terms, sampleLegalInfo());

      expect(doc.title, "Conditions d'utilisation");
      expect(doc.version, '2026-10');
      expect(doc.sections, hasLength(12));
      expect(doc.sections.first.title, '1. Objet');
      expect(doc.sections.last.title, '12. Droit applicable');
      final text = allText(doc);
      expect(text, contains('service édité par Atelier Test SARL'));
      expect(text, contains('écrivant à contact@example.sn.'));
      expect(text, contains('Écrivez à contact@example.sn pour signaler'));
      expect(text, isNot(contains(legalPlaceholder)));
    });

    test(
      'sans informations : « [à compléter] », jamais de valeur inventée',
      () {
        final doc = buildLegalDocument(LegalDocKey.terms, null);

        expect(doc.version, legalPlaceholder);
        expect(allText(doc), contains('service édité par [à compléter]'));
      },
    );

    test('éditeur vide côté serveur : « [à compléter] »', () {
      final doc = buildLegalDocument(
        LegalDocKey.terms,
        LegalInfo.fromJson(<String, dynamic>{
          'publisher': <String, dynamic>{'name': '   '},
        }),
      );
      expect(allText(doc), contains('service édité par [à compléter]'));
    });

    test('confidentialité : 11 sections, durées issues du serveur', () {
      final info = LegalInfo.fromJson(<String, dynamic>{
        'publisher': <String, dynamic>{'name': 'Atelier Test SARL'},
        'contact_email': 'contact@example.sn',
        'privacy_email': 'privacy@example.sn',
        'hosting': <String, dynamic>{
          'provider': 'Hébergeur Test',
          'location': 'Pays Test',
        },
        'versions': <String, dynamic>{'privacy': '2026-10'},
        'retention': <String, dynamic>{
          'anonymized_content_days': 45,
          'audit_logs_days': 90,
        },
      });
      final doc = buildLegalDocument(LegalDocKey.privacy, info);

      expect(doc.title, 'Politique de confidentialité');
      expect(doc.version, '2026-10');
      expect(doc.sections, hasLength(11));
      final text = allText(doc);
      expect(text, contains('effacés définitivement après 45 jours'));
      expect(text, contains('de sécurité) : 90 jours.'));
      expect(text, contains('Hébergement et stockage : Hébergeur Test.'));
      expect(text, contains('situés en : Pays Test.'));
      expect(text, contains('exercer vos droits : privacy@example.sn.'));
    });

    test(
      'confidentialité : durées du texte web si le serveur n\'en donne pas',
      () {
        final text = allText(buildLegalDocument(LegalDocKey.privacy, null));
        expect(text, contains('effacés définitivement après 30 jours'));
        expect(text, contains('de sécurité) : 180 jours.'));
      },
    );

    test('confidentialité : repli sur le contact général pour les droits', () {
      final info = LegalInfo.fromJson(<String, dynamic>{
        'contact_email': 'contact@example.sn',
        'privacy_email': '',
      });
      final text = allText(buildLegalDocument(LegalDocKey.privacy, info));
      expect(text, contains('exercer vos droits : contact@example.sn.'));
    });

    test('confidentialité : récépissé CDP affiché seulement s\'il existe', () {
      final without = allText(
        buildLegalDocument(LegalDocKey.privacy, sampleLegalInfo()),
      );
      expect(without, contains('est en cours de déclaration'));
      expect(without, isNot(contains('récépissé')));

      final withReceipt = allText(
        buildLegalDocument(
          LegalDocKey.privacy,
          LegalInfo.fromJson(<String, dynamic>{'cdp_receipt': ' CDP-0001 '}),
        ),
      );
      expect(withReceipt, contains('récépissé n° CDP-0001.'));
      expect(withReceipt, isNot(contains('est en cours de déclaration')));
    });

    test(
      'mentions légales : sans version, éditeur et hébergeur renseignés',
      () {
        final doc = buildLegalDocument(LegalDocKey.notice, sampleLegalInfo());

        expect(doc.title, 'Mentions légales');
        expect(doc.version, isEmpty);
        expect(doc.sections, hasLength(5));
        final text = allText(doc);
        expect(text, contains('QUINCH est édité par : Atelier Test SARL.'));
        expect(text, contains('Adresse : 1 rue de Test, Dakar.'));
        expect(text, contains('Directeur de la publication : Awa Test.'));
        expect(text, contains('hébergé par Hébergeur Test'));
      },
    );

    test('chemins identiques à ceux du projet web', () {
      expect(LegalDocKey.terms.path, '/legal/cgu');
      expect(LegalDocKey.privacy.path, '/legal/confidentialite');
      expect(LegalDocKey.notice.path, '/legal/mentions-legales');
    });
  });

  group('LegalPage', () {
    testWidgets('affiche le titre, la version et les articles', (tester) async {
      final env = await pumpScreen(
        tester,
        const LegalPage(docKey: LegalDocKey.terms),
      );

      expect(env.legal.infoCalls, 1);
      expect(find.text('Version 2026-10'), findsOneWidget);
      expect(find.text('1. Objet'), findsOneWidget);
      expect(
        find.textContaining('service édité par Atelier Test SARL'),
        findsOneWidget,
      );
      await tester.scrollUntilVisible(find.text('12. Droit applicable'), 400);
      expect(find.text('12. Droit applicable'), findsOneWidget);
    });

    testWidgets(
      'serveur injoignable : message et « Réessayer », pas de texte',
      (tester) async {
        final legal = FakeLegalRepository();
        var attempts = 0;
        legal.onInfo = () async {
          attempts++;
          if (attempts == 1) {
            throw ApiError.network();
          }
          return sampleLegalInfo();
        };
        await pumpScreen(
          tester,
          const LegalPage(docKey: LegalDocKey.privacy),
          legal: legal,
        );

        expect(find.text(ApiError.network().userMessage), findsOneWidget);
        expect(
          find.text('1. Qui est responsable de vos données'),
          findsNothing,
        );

        await tapVisible(
          tester,
          find.widgetWithText(FilledButton, 'Réessayer'),
        );

        expect(legal.infoCalls, 2);
        expect(
          find.text('1. Qui est responsable de vos données'),
          findsOneWidget,
        );
      },
    );

    testWidgets('lien vers un autre texte juridique', (tester) async {
      await pumpScreen(tester, const LegalPage(docKey: LegalDocKey.terms));

      final link = find.widgetWithText(
        TextButton,
        'Politique de confidentialité',
      );
      await tester.scrollUntilVisible(link, 400);
      await tapVisible(tester, link);

      expect(find.text('ROUTE /legal/confidentialite'), findsOneWidget);
    });
  });

  group('Accès aux textes depuis l\'application', () {
    testWidgets(
      'inscription : liens vers les conditions et la confidentialité',
      (tester) async {
        await pumpScreen(tester, const RegisterPage());

        await tapVisible(
          tester,
          find.widgetWithText(TextButton, "Lire les conditions d'utilisation"),
        );
        expect(find.text('ROUTE /legal/cgu'), findsOneWidget);
      },
    );

    testWidgets('inscription : lien vers la politique de confidentialité', (
      tester,
    ) async {
      await pumpScreen(tester, const RegisterPage());

      await tapVisible(
        tester,
        find.widgetWithText(TextButton, 'Lire la politique de confidentialité'),
      );
      expect(find.text('ROUTE /legal/confidentialite'), findsOneWidget);
    });

    testWidgets('paramètres : les trois textes sont accessibles', (
      tester,
    ) async {
      await pumpScreen(tester, const SettingsPage());

      expect(find.text("Conditions d'utilisation"), findsOneWidget);
      expect(find.text('Politique de confidentialité'), findsOneWidget);
      await tapVisible(tester, find.text('Mentions légales'));
      expect(find.text('ROUTE /legal/mentions-legales'), findsOneWidget);
    });
  });
}
