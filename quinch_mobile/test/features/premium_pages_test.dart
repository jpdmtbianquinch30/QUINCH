import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quinch_mobile/app/router.dart';
import 'package:quinch_mobile/core/format/fcfa.dart';
import 'package:quinch_mobile/core/network/api_error.dart';
import 'package:quinch_mobile/data/models/premium.dart';
import 'package:quinch_mobile/data/repositories/ranking_repository.dart';
import 'package:quinch_mobile/features/premium/premium_page.dart';
import 'package:quinch_mobile/features/rankings/rankings_page.dart';

import '../support/fakes.dart';
import '../support/pump.dart';

PublicConfig paymentsOn() => const PublicConfig(
  beta: false,
  listingFeeWithVideo: 150,
  premiumOfferSlots: 100,
  premiumPayments: true,
);

void main() {
  group('PremiumPage — compte gratuit, bêta', () {
    testWidgets('paiements coupés : message clair, aucune formule à acheter', (
      tester,
    ) async {
      await pumpScreen(tester, const PremiumPage());

      expect(find.text('Votre compte est gratuit'), findsOneWidget);
      expect(
        find.textContaining("Le paiement n'est pas actif pour la version bêta"),
        findsOneWidget,
      );
      expect(find.text('Choisir'), findsNothing);
      expect(find.text('Offre de lancement'), findsOneWidget);
      expect(
        find.text('90 jours de Premium offerts. 40 places restantes sur 100.'),
        findsOneWidget,
      );
    });

    testWidgets('demander l\'offre de lancement', (tester) async {
      final env = await pumpScreen(tester, const PremiumPage());

      await tapVisible(tester, find.text("Demander l'offre de lancement"));

      expect(env.premium.applyCalls, 1);
      expect(find.textContaining('Candidature envoyée'), findsOneWidget);
    });

    testWidgets('email non vérifié : message du serveur, rien d\'inventé', (
      tester,
    ) async {
      final premium = FakePremiumRepository();
      premium.onApply = () async =>
          throw ApiError.fromResponse(403, <String, dynamic>{
            'error': 'email_not_verified',
            'message':
                'Veuillez confirmer votre adresse e-mail avant de continuer.',
          });
      await pumpScreen(tester, const PremiumPage(), premium: premium);

      await tapVisible(tester, find.text("Demander l'offre de lancement"));
      expect(
        find.text(
          'Veuillez confirmer votre adresse e-mail avant de continuer.',
        ),
        findsOneWidget,
      );
    });

    // Un test par état : monter l'écran plusieurs fois dans un même test laisse un
    // minuteur de nettoyage Riverpod en attente.
    final applicationStates = <String, String>{
      'pending': "Votre candidature est en cours d'examen.",
      'granted': 'Offre accordée. Merci !',
      'rejected': "Votre candidature n'a pas été retenue.",
    };
    for (final entry in applicationStates.entries) {
      testWidgets('état de la candidature : ${entry.key}', (tester) async {
        final premium = FakePremiumRepository();
        premium.onOffer = () async => PremiumOffer(
          slotsTotal: 100,
          slotsLeft: 40,
          days: 90,
          myStatus: entry.key,
        );
        await pumpScreen(tester, const PremiumPage(), premium: premium);
        expect(find.text(entry.value), findsOneWidget);
        expect(find.text("Demander l'offre de lancement"), findsNothing);
      });
    }

    testWidgets('plus aucune place', (tester) async {
      final premium = FakePremiumRepository();
      premium.onOffer = () async =>
          const PremiumOffer(slotsTotal: 100, slotsLeft: 0, days: 90);
      await pumpScreen(tester, const PremiumPage(), premium: premium);
      expect(
        find.text("Toutes les places de l'offre sont attribuées."),
        findsOneWidget,
      );
      expect(find.text("Demander l'offre de lancement"), findsNothing);
    });

    testWidgets(
      'l\'offre est facultative : son échec n\'empêche pas l\'écran',
      (tester) async {
        final premium = FakePremiumRepository();
        premium.onOffer = () async => throw ApiError.network();
        await pumpScreen(tester, const PremiumPage(), premium: premium);
        expect(find.text('Votre compte est gratuit'), findsOneWidget);
        expect(find.text('Offre de lancement'), findsNothing);
      },
    );
  });

  group('PremiumPage — paiements actifs', () {
    FakePremiumRepository payable() {
      final premium = FakePremiumRepository();
      premium.onConfig = () async => paymentsOn();
      return premium;
    }

    testWidgets('formules et prix en FCFA', (tester) async {
      await pumpScreen(tester, const PremiumPage(), premium: payable());
      expect(find.text('Mensuel'), findsOneWidget);
      expect(find.text(formatFcfa(2000)), findsOneWidget);
      expect(find.text('Annuel'), findsOneWidget);
      expect(find.text(formatFcfa(20000)), findsOneWidget);
      expect(find.text('Choisir'), findsNWidgets(2));
    });

    testWidgets(
      'choisir une formule : confirmation, ouverture du paiement, jamais « payé »',
      (tester) async {
        final opened = <Uri>[];
        final premium = payable();
        final env = await pumpScreen(
          tester,
          const PremiumPage(),
          premium: premium,
          openedUrls: opened,
        );

        await tapVisible(tester, find.text('Choisir').first);
        expect(find.text('Formule Mensuel'), findsOneWidget);
        await tester.tap(find.widgetWithText(FilledButton, 'Continuer'));
        await tester.pumpAndSettle();

        expect(env.premium.subscribed, <String>['monthly']);
        expect(opened.single.toString(), 'https://pay.example/session/abc');
        expect(
          find.textContaining('Paiement en cours de traitement'),
          findsOneWidget,
        );
        expect(find.textContaining('confirmé'), findsNothing);
        expect(find.text('Votre compte est gratuit'), findsOneWidget);
      },
    );

    testWidgets('annuler la confirmation : aucun appel', (tester) async {
      final opened = <Uri>[];
      final env = await pumpScreen(
        tester,
        const PremiumPage(),
        premium: payable(),
        openedUrls: opened,
      );
      await tapVisible(tester, find.text('Choisir').first);
      await tester.tap(find.text('Annuler'));
      await tester.pumpAndSettle();
      expect(env.premium.subscribed, isEmpty);
      expect(opened, isEmpty);
    });

    testWidgets(
      'adresse de paiement absente ou non sécurisée : rien n\'est ouvert',
      (tester) async {
        final opened = <Uri>[];
        final premium = payable();
        premium.onSubscribe = (plan) async => null;
        await pumpScreen(
          tester,
          const PremiumPage(),
          premium: premium,
          openedUrls: opened,
        );

        await tapVisible(tester, find.text('Choisir').first);
        await tester.tap(find.widgetWithText(FilledButton, 'Continuer'));
        await tester.pumpAndSettle();

        expect(opened, isEmpty);
        expect(
          find.text(
            'Le lien de paiement est indisponible. Réessayez plus tard.',
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets('navigateur introuvable : message adapté', (tester) async {
      await pumpScreen(
        tester,
        const PremiumPage(),
        premium: payable(),
        urlOpens: false,
      );
      await tapVisible(tester, find.text('Choisir').first);
      await tester.tap(find.widgetWithText(FilledButton, 'Continuer'));
      await tester.pumpAndSettle();
      expect(
        find.text("Impossible d'ouvrir la page de paiement."),
        findsOneWidget,
      );
    });

    testWidgets('refus du serveur : son message est affiché', (tester) async {
      final premium = payable();
      // 422 : le message du serveur est affiché. Les erreurs 5xx, elles, sont
      // volontairement remplacées par un message générique (pas de détail interne).
      premium.onSubscribe = (plan) async => throw ApiError.fromResponse(
        422,
        <String, dynamic>{'message': "L'abonnement n'a pas pu être initié."},
      );
      await pumpScreen(tester, const PremiumPage(), premium: premium);
      await tapVisible(tester, find.text('Choisir').first);
      await tester.tap(find.widgetWithText(FilledButton, 'Continuer'));
      await tester.pumpAndSettle();
      expect(find.text("L'abonnement n'a pas pu être initié."), findsOneWidget);
    });
  });

  group('PremiumPage — paiement en attente et compte Premium', () {
    testWidgets(
      '« Vérifier mon paiement » : tant que le serveur ne confirme pas, rien n\'est déclaré réussi',
      (tester) async {
        final premium = FakePremiumRepository();
        premium.onStatus = () async => const PremiumStatus(
          isPremium: false,
          pendingSubscription: <String, dynamic>{
            'id': 's1',
            'status': 'pending',
          },
        );
        await pumpScreen(
          tester,
          const PremiumPage(),
          premium: premium,
          authenticated: true,
        );
        expect(
          find.textContaining('en attente de confirmation'),
          findsOneWidget,
        );

        await tapVisible(tester, find.text('Vérifier mon paiement'));
        expect(
          find.text("Le paiement n'est pas encore confirmé par le serveur."),
          findsOneWidget,
        );
        expect(find.text('Votre compte est gratuit'), findsOneWidget);
      },
    );

    testWidgets('le serveur confirme : compte Premium et utilisateur relu', (
      tester,
    ) async {
      var confirmed = false;
      final premium = FakePremiumRepository();
      premium.onStatus = () async => confirmed
          ? PremiumStatus(
              isPremium: true,
              plan: 'monthly',
              expiresAt: DateTime.utc(2099, 1, 1),
              daysRemaining: 30,
            )
          : const PremiumStatus(
              isPremium: false,
              pendingSubscription: <String, dynamic>{
                'id': 's1',
                'status': 'pending',
              },
            );
      final env = await pumpScreen(
        tester,
        const PremiumPage(),
        premium: premium,
        authenticated: true,
      );
      final meBefore = env.auth.meCalls;

      confirmed = true;
      await tapVisible(tester, find.text('Vérifier mon paiement'));

      expect(
        find.text('Paiement confirmé : votre compte est Premium.'),
        findsOneWidget,
      );
      expect(find.text('Votre compte est Premium'), findsOneWidget);
      expect(find.text('Formule : Mensuel'), findsOneWidget);
      expect(find.textContaining('30 jours restants'), findsOneWidget);
      expect(env.auth.meCalls, greaterThan(meBefore));
      expect(find.text('Choisir'), findsNothing);
      expect(find.text('Offre de lancement'), findsNothing);
    });

    testWidgets('compte Premium : date de fin affichée', (tester) async {
      final premium = FakePremiumRepository();
      premium.onStatus = () async => PremiumStatus(
        isPremium: true,
        plan: 'annual',
        expiresAt: DateTime.utc(2027, 3, 5, 12),
        daysRemaining: 1,
      );
      await pumpScreen(tester, const PremiumPage(), premium: premium);
      expect(find.text('Formule : Annuel'), findsOneWidget);
      expect(
        find.text("Valable jusqu'au 05/03/2027 (1 jour restant)"),
        findsOneWidget,
      );
    });

    testWidgets('lien vers les classements', (tester) async {
      await pumpScreen(tester, const PremiumPage());
      await tapVisible(tester, find.text('Classements'));
      expect(find.text('ROUTE $rankingsPath'), findsOneWidget);
    });

    testWidgets('erreur de chargement puis réessai', (tester) async {
      final premium = FakePremiumRepository();
      premium.onStatus = () async => throw ApiError.network();
      await pumpScreen(tester, const PremiumPage(), premium: premium);
      expect(
        find.text('Connexion impossible. Vérifiez votre réseau.'),
        findsOneWidget,
      );

      premium.onStatus = () async => const PremiumStatus(isPremium: false);
      await tester.tap(find.text('Réessayer'));
      await tester.pumpAndSettle();
      expect(find.text('Votre compte est gratuit'), findsOneWidget);
    });

    test('libellés de formule', () {
      expect(planLabel('monthly'), 'Mensuel');
      expect(planLabel('annual'), 'Annuel');
      expect(planLabel(null), '');
      expect(planLabel('autre'), 'autre');
    });
  });

  group('RankingsPage', () {
    testWidgets('compte gratuit : réservé aux Premium, lien vers l\'offre', (
      tester,
    ) async {
      final rankings = FakeRankingRepository();
      rankings.onPreferences = () async => const RankingPreferences(
        isPremium: false,
        optIn: false,
        anonymous: false,
      );
      await pumpScreen(tester, const RankingsPage(), rankings: rankings);

      expect(
        find.text('Les classements sont réservés aux comptes Premium.'),
        findsOneWidget,
      );
      expect(rankings.requested, isEmpty);
      await tester.tap(find.text('Découvrir Premium'));
      await tester.pumpAndSettle();
      expect(find.text('ROUTE $premiumPath'), findsOneWidget);
    });

    testWidgets('classement des vendeurs : mesures et ouverture du profil', (
      tester,
    ) async {
      final rankings = FakeRankingRepository();
      rankings.onUsers = (kind) async => <RankingEntry>[
        rankingEntry(
          metrics: const <String, dynamic>{
            'score': 90,
            'total_views': 70,
            'total_likes': 20,
            'products_count': 4,
          },
        ),
        rankingEntry(
          rank: 2,
          name: 'Utilisateur anonyme',
          username: null,
          anonymous: true,
        ),
      ];
      await pumpScreen(tester, const RankingsPage(), rankings: rankings);

      expect(find.text('#1'), findsOneWidget);
      expect(find.text('Fatou Sow'), findsOneWidget);
      expect(
        find.text("90 points · 70 vues · 20 j'aime · 4 annonces"),
        findsOneWidget,
      );

      await tester.tap(find.text('Fatou Sow'));
      await tester.pumpAndSettle();
      expect(find.text('ROUTE /seller/fatou'), findsOneWidget);
    });

    testWidgets('profil anonyme : affiché sans ouverture possible', (
      tester,
    ) async {
      final rankings = FakeRankingRepository();
      rankings.onUsers = (kind) async => <RankingEntry>[
        rankingEntry(
          name: 'Utilisateur anonyme',
          username: null,
          anonymous: true,
        ),
      ];
      await pumpScreen(tester, const RankingsPage(), rankings: rankings);

      await tester.tap(find.text('Utilisateur anonyme'));
      await tester.pumpAndSettle();
      expect(find.textContaining('ROUTE /seller'), findsNothing);
    });

    testWidgets('classement des annonces : ouverture de l\'annonce', (
      tester,
    ) async {
      final rankings = FakeRankingRepository();
      rankings.onProducts = () async => <ProductRankingEntry>[
        const ProductRankingEntry(
          rank: 1,
          productId: 'p1',
          productSlug: 'robe-wax',
          title: 'Robe wax',
          viewCount: 321,
          anonymous: false,
          sellerName: 'Fatou Sow',
        ),
      ];
      await pumpScreen(tester, const RankingsPage(), rankings: rankings);

      await tester.tap(find.text('Annonces'));
      await tester.pumpAndSettle();
      expect(find.text('Robe wax'), findsOneWidget);
      expect(find.text('321 vues · Fatou Sow'), findsOneWidget);

      await tester.tap(find.text('Robe wax'));
      await tester.pumpAndSettle();
      expect(find.text('ROUTE /product/robe-wax'), findsOneWidget);
    });

    testWidgets('profils et abonnés : textes de mesure', (tester) async {
      final rankings = FakeRankingRepository();
      rankings.onUsers = (kind) async => <RankingEntry>[
        rankingEntry(
          metrics: kind == RankingKind.profiles
              ? const <String, dynamic>{'profile_views_count': 1}
              : const <String, dynamic>{'followers_count': 12},
        ),
      ];
      await pumpScreen(tester, const RankingsPage(), rankings: rankings);

      await tester.tap(find.text('Profils'));
      await tester.pumpAndSettle();
      expect(find.text('1 visite de profil'), findsOneWidget);

      await tester.tap(find.text('Abonnés'));
      await tester.pumpAndSettle();
      expect(find.text('12 abonnés'), findsOneWidget);
    });

    testWidgets('préférences : participer et rester anonyme', (tester) async {
      final rankings = FakeRankingRepository();
      rankings.onPreferences = () async => const RankingPreferences(
        isPremium: true,
        optIn: false,
        anonymous: false,
      );
      await pumpScreen(tester, const RankingsPage(), rankings: rankings);

      // Tant que la participation est coupée, l'anonymat n'est pas réglable.
      expect(
        tester.widget<Switch>(find.byType(Switch).at(1)).onChanged,
        isNull,
      );

      await tester.tap(find.byType(Switch).at(0));
      await tester.pumpAndSettle();
      expect(rankings.updates.last, (true, false));
      expect(
        tester.widget<Switch>(find.byType(Switch).at(1)).onChanged,
        isNotNull,
      );

      await tester.tap(find.byType(Switch).at(1));
      await tester.pumpAndSettle();
      expect(rankings.updates.last, (true, true));
    });

    testWidgets('échec de l\'enregistrement : réglage rétabli', (tester) async {
      final rankings = FakeRankingRepository();
      rankings.onUpdate = (optIn, anonymous) async => throw ApiError.network();
      await pumpScreen(tester, const RankingsPage(), rankings: rankings);

      final before = tester.widget<Switch>(find.byType(Switch).at(0)).value;
      await tester.tap(find.byType(Switch).at(0));
      await tester.pumpAndSettle();
      expect(tester.widget<Switch>(find.byType(Switch).at(0)).value, before);
      expect(
        find.text('Connexion impossible. Vérifiez votre réseau.'),
        findsOneWidget,
      );
    });

    testWidgets('classement vide', (tester) async {
      await pumpScreen(tester, const RankingsPage());
      expect(find.text("Aucun classement pour l'instant."), findsOneWidget);
    });

    testWidgets(
      'accès refusé (abonnement expiré entre-temps) : message du serveur et réessai',
      (tester) async {
        final rankings = FakeRankingRepository();
        rankings.onUsers = (kind) async =>
            throw ApiError.fromResponse(403, <String, dynamic>{
              'message': 'Les classements sont reserves aux comptes Premium.',
            });
        await pumpScreen(tester, const RankingsPage(), rankings: rankings);
        expect(
          find.text('Les classements sont reserves aux comptes Premium.'),
          findsOneWidget,
        );
        expect(find.text('Réessayer'), findsOneWidget);
      },
    );
  });
}
