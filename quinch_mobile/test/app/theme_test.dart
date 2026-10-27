import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quinch_mobile/app/theme.dart';
import 'package:quinch_mobile/shared/widgets/app_widgets.dart';

/// Rapport de contraste WCAG entre deux couleurs opaques.
double contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final hi = la > lb ? la : lb;
  final lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  group('Jetons de design (valeurs d\'Angular)', () {
    test('sombre : fond, cartes et accent', () {
      final theme = QuinchTheme.dark();
      expect(theme.brightness, Brightness.dark);
      expect(theme.scaffoldBackgroundColor, const Color(0xFF0A0E1A));
      expect(theme.colorScheme.surface, const Color(0xFF1A1F35));
      expect(theme.colorScheme.primary, const Color(0xFF4F6EF7));
      expect(theme.colorScheme.secondary, const Color(0xFF10B981));
      expect(theme.colorScheme.error, const Color(0xFFEF4444));
    });

    test('clair : fond, cartes et accent', () {
      final theme = QuinchTheme.light();
      expect(theme.brightness, Brightness.light);
      expect(theme.scaffoldBackgroundColor, const Color(0xFFF5F7FA));
      expect(theme.colorScheme.surface, const Color(0xFFFFFFFF));
      expect(theme.colorScheme.primary, const Color(0xFF4F6EF7));
      expect(theme.colorScheme.error, const Color(0xFFDC2626));
    });

    test('la police Inter est appliquée aux styles de texte', () {
      for (final theme in [QuinchTheme.dark(), QuinchTheme.light()]) {
        expect(theme.textTheme.bodyMedium?.fontFamily, 'Inter');
        expect(theme.textTheme.titleMedium?.fontFamily, 'Inter');
        expect(theme.textTheme.labelLarge?.fontFamily, 'Inter');
      }
    });

    test('les rayons et espacements reprennent ceux d\'Angular', () {
      expect(QuinchRadius.sm, 8);
      expect(QuinchRadius.md, 12);
      expect(QuinchRadius.lg, 16);
      expect(QuinchRadius.xl, 24);
      expect(QuinchSpacing.md, 16);
    });
  });

  group('Lisibilité (contraste >= 4,5)', () {
    for (final entry in {
      'sombre': QuinchPalette.dark,
      'clair': QuinchPalette.light,
    }.entries) {
      final p = entry.value;
      test('${entry.key} : textes sur fonds', () {
        for (final bg in [p.background, p.card, p.elevated, p.input]) {
          expect(contrast(p.textPrimary, bg), greaterThanOrEqualTo(4.5));
          expect(contrast(p.textSecondary, bg), greaterThanOrEqualTo(4.5));
        }
      });
      test('${entry.key} : accent utilisé comme texte', () {
        expect(contrast(p.accentText, p.background), greaterThanOrEqualTo(4.5));
        expect(contrast(p.accentText, p.card), greaterThanOrEqualTo(4.5));
      });
    }

    test('conteneurs d\'erreur et d\'accent lisibles', () {
      for (final theme in [QuinchTheme.dark(), QuinchTheme.light()]) {
        final s = theme.colorScheme;
        expect(
          contrast(s.onErrorContainer, s.errorContainer),
          greaterThanOrEqualTo(4.5),
        );
        expect(
          contrast(s.onPrimaryContainer, s.primaryContainer),
          greaterThanOrEqualTo(4.5),
        );
        expect(
          contrast(s.onSecondaryContainer, s.secondaryContainer),
          greaterThanOrEqualTo(4.5),
        );
      }
    });
  });

  group('Rôles de couleur lus par les écrans', () {
    test(
      'outline est opaque (icônes visibles), outlineVariant translucide',
      () {
        for (final theme in [QuinchTheme.dark(), QuinchTheme.light()]) {
          expect(theme.colorScheme.outline.a, 1.0);
          expect(theme.colorScheme.outlineVariant.a, lessThan(0.2));
        }
      },
    );
  });

  group('LoadingButton', () {
    for (final entry in {
      'sombre': QuinchTheme.dark(),
      'clair': QuinchTheme.light(),
    }.entries) {
      testWidgets('${entry.key} : reste un FilledButton actif avec dégradé', (
        tester,
      ) async {
        var taps = 0;
        await tester.pumpWidget(
          MaterialApp(
            theme: entry.value,
            home: Scaffold(
              body: Padding(
                padding: const EdgeInsets.all(16),
                child: LoadingButton(
                  label: 'Valider',
                  onPressed: () => taps++,
                  isLoading: false,
                ),
              ),
            ),
          ),
        );

        final button = find.widgetWithText(FilledButton, 'Valider');
        expect(button, findsOneWidget);
        expect(tester.widget<FilledButton>(button).onPressed, isNotNull);

        final decorated = tester.widget<DecoratedBox>(
          find
              .descendant(
                of: find.byType(LoadingButton),
                matching: find.byType(DecoratedBox),
              )
              .first,
        );
        expect((decorated.decoration as BoxDecoration).gradient, isNotNull);

        await tester.tap(button);
        expect(taps, 1);
      });
    }

    testWidgets('en chargement : bouton désactivé et indicateur affiché', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: QuinchTheme.dark(),
          home: Scaffold(
            body: LoadingButton(
              label: 'Valider',
              onPressed: () {},
              isLoading: true,
            ),
          ),
        ),
      );

      final button = find.byType(FilledButton);
      expect(button, findsOneWidget);
      expect(tester.widget<FilledButton>(button).onPressed, isNull);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Valider'), findsNothing);
    });
  });
}
