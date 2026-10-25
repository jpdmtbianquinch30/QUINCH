import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quinch_mobile/features/feed/feed_card.dart';
import 'package:quinch_mobile/features/product/product_detail_page.dart';

import '../support/fakes.dart';
import '../support/pump.dart';

Finder get playButton => find.byTooltip('Lire la vidéo');
Finder get surface => find.byKey(const Key('video-surface'));

void main() {
  group('Lecteur vidéo (carte du feed)', () {
    Widget feedCard({String id = 'p1', String videoId = 'v1'}) => FeedCard(
      card: sampleCard(
        id: id,
        slug: 'annonce-$id',
        video: sampleVideoJson(id: videoId),
      ),
    );

    testWidgets('avant le toucher : image seule, rien n\'est téléchargé', (
      tester,
    ) async {
      final env = await pumpScreen(tester, feedCard());

      expect(playButton, findsOneWidget);
      expect(env.video.sessions, isEmpty);
    });

    testWidgets('toucher « Lire » : flux public, son coupé, lecture lancée', (
      tester,
    ) async {
      final env = await pumpScreen(tester, feedCard());

      await tapVisible(tester, playButton);

      final session = env.video.sessions.single;
      expect(session.url.path, '/api/v1/videos/v1/stream');
      expect(session.url.hasQuery, isFalse);
      expect(session.playing, isTrue);
      expect(session.muted, isTrue);
      expect(find.byTooltip('Fermer la vidéo'), findsOneWidget);
      expect(find.byTooltip('Activer le son'), findsOneWidget);
    });

    testWidgets('chargement : indicateur puis lecture', (tester) async {
      final gate = Completer<void>();
      final video = FakeVideoFactory()..initGate = gate.future;
      final env = await pumpScreen(tester, feedCard(), video: video);

      await tester.tap(playButton);
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(env.video.sessions.single.playing, isFalse);

      gate.complete();
      await tester.pumpAndSettle();
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(env.video.sessions.single.playing, isTrue);
    });

    testWidgets('toucher la vidéo : pause puis reprise', (tester) async {
      final env = await pumpScreen(tester, feedCard());
      await tapVisible(tester, playButton);
      final session = env.video.sessions.single;

      await tester.tap(surface);
      await tester.pumpAndSettle();
      expect(session.playing, isFalse);
      expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);

      await tester.tap(surface);
      await tester.pumpAndSettle();
      expect(session.playing, isTrue);
    });

    testWidgets('fin de la vidéo : un toucher la relance depuis le début', (
      tester,
    ) async {
      final env = await pumpScreen(tester, feedCard());
      await tapVisible(tester, playButton);
      final session = env.video.sessions.single;

      session.finish();
      await tester.pumpAndSettle();
      await tester.tap(surface);
      await tester.pumpAndSettle();

      expect(session.restarts, 1);
      expect(session.playing, isTrue);
    });

    testWidgets('son : activer puis couper', (tester) async {
      final env = await pumpScreen(tester, feedCard());
      await tapVisible(tester, playButton);
      final session = env.video.sessions.single;

      await tapVisible(tester, find.byTooltip('Activer le son'));
      expect(session.muted, isFalse);
      expect(find.byTooltip('Couper le son'), findsOneWidget);

      await tapVisible(tester, find.byTooltip('Couper le son'));
      expect(session.muted, isTrue);
    });

    testWidgets('fermer : le lecteur est libéré, retour à l\'image', (
      tester,
    ) async {
      final env = await pumpScreen(tester, feedCard());
      await tapVisible(tester, playButton);

      await tapVisible(tester, find.byTooltip('Fermer la vidéo'));

      expect(env.video.sessions.single.disposed, isTrue);
      expect(playButton, findsOneWidget);
    });

    testWidgets('application en arrière-plan : mise en pause', (tester) async {
      final env = await pumpScreen(tester, feedCard());
      await tapVisible(tester, playButton);
      final session = env.video.sessions.single;
      expect(session.playing, isTrue);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pumpAndSettle();

      expect(session.playing, isFalse);
    });

    testWidgets('une seule vidéo à la fois', (tester) async {
      final env = await pumpScreen(
        tester,
        ListView(
          children: [
            feedCard(id: 'p1', videoId: 'v1'),
            feedCard(id: 'p2', videoId: 'v2'),
          ],
        ),
      );

      await tapVisible(tester, playButton.first);
      final first = env.video.sessions.single;
      expect(first.playing, isTrue);

      await tapVisible(tester, playButton.last);

      expect(first.disposed, isTrue);
      expect(env.video.sessions, hasLength(2));
      expect(env.video.sessions.last.url.path, '/api/v1/videos/v2/stream');
      expect(env.video.sessions.last.playing, isTrue);
      // La première carte est revenue à l'image.
      expect(playButton, findsOneWidget);
    });

    testWidgets('échec au démarrage : message puis nouvel essai', (
      tester,
    ) async {
      final video = FakeVideoFactory()..failInitialize = true;
      final env = await pumpScreen(tester, feedCard(), video: video);

      await tapVisible(tester, playButton);
      expect(find.text('Vidéo indisponible pour le moment.'), findsOneWidget);
      expect(env.video.sessions.single.disposed, isTrue);

      video.failInitialize = false;
      await tapVisible(tester, find.widgetWithText(FilledButton, 'Réessayer'));

      expect(env.video.sessions, hasLength(2));
      expect(env.video.sessions.last.playing, isTrue);
      expect(find.text('Vidéo indisponible pour le moment.'), findsNothing);
    });

    testWidgets('erreur en cours de lecture : message d\'indisponibilité', (
      tester,
    ) async {
      final env = await pumpScreen(tester, feedCard());
      await tapVisible(tester, playButton);

      env.video.sessions.single.fail();
      await tester.pumpAndSettle();

      expect(find.text('Vidéo indisponible pour le moment.'), findsOneWidget);
      expect(env.video.sessions.single.disposed, isTrue);
    });

    testWidgets('annonce sans adresse de flux : indisponible, rien créé', (
      tester,
    ) async {
      final env = await pumpScreen(
        tester,
        FeedCard(
          card: sampleCard(video: <String, dynamic>{'id': 'v9', 'duration': 5}),
        ),
      );

      await tapVisible(tester, playButton);

      expect(find.text('Vidéo indisponible pour le moment.'), findsOneWidget);
      expect(env.video.sessions, isEmpty);
    });

    testWidgets('annonce sans vidéo : pas de bouton « Lire »', (tester) async {
      await pumpScreen(tester, FeedCard(card: sampleCard()));

      expect(playButton, findsNothing);
    });
  });

  group('Lecteur vidéo (détail de l\'annonce)', () {
    testWidgets('le bouton « Lire » lance la vidéo de l\'annonce', (
      tester,
    ) async {
      final products = FakeProductRepository()
        ..onDetail = (slug) async =>
            sampleDetail(video: sampleVideoJson(id: 'v7'));
      final env = await pumpScreen(
        tester,
        const ProductDetailPage(slug: 'robe-wax'),
        products: products,
      );

      await tapVisible(tester, playButton);

      expect(env.video.sessions.single.url.path, '/api/v1/videos/v7/stream');
      expect(env.video.sessions.single.playing, isTrue);
    });

    testWidgets('sans vidéo : galerie seule', (tester) async {
      await pumpScreen(tester, const ProductDetailPage(slug: 'robe-wax'));

      expect(playButton, findsNothing);
    });
  });
}
