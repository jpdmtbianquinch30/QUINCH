import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quinch_mobile/core/network/api_error.dart';
import 'package:quinch_mobile/data/models/chat.dart';
import 'package:quinch_mobile/features/account/account_page.dart';
import 'package:quinch_mobile/features/feed/feed_page.dart';
import 'package:quinch_mobile/features/product/product_detail_page.dart';
import 'package:quinch_mobile/features/profile/seller_profile_page.dart';

import '../support/fakes.dart';
import '../support/pump.dart';

Finder get sendInDialog => find.widgetWithText(FilledButton, 'Envoyer');

FakeChatRepository chatWithUnread(List<int> unread) =>
    FakeChatRepository()
      ..onConversations = (page) async => pageOf<Conversation>([
        for (var i = 0; i < unread.length; i++)
          sampleConversation(id: 'c$i', unread: unread[i]),
      ]);

Future<ScreenEnv> pumpDetail(
  WidgetTester tester, {
  String sellerId = 's1',
  FakeChatRepository? chat,
}) async {
  final products = FakeProductRepository()
    ..onDetail = (slug) async => sampleDetail(sellerId: sellerId);
  final env = await pumpScreen(
    tester,
    const ProductDetailPage(slug: 'robe-wax'),
    products: products,
    chat: chat,
    authenticated: true,
  );
  tester.view.physicalSize = const Size(400, 2400);
  await tester.pumpAndSettle();
  return env;
}

void main() {
  group('Contacter le vendeur — fiche annonce', () {
    testWidgets('message prérempli avec le titre, envoi lié à l\'annonce', (
      tester,
    ) async {
      final env = await pumpDetail(tester);

      await tester.tap(find.text('Contacter le vendeur'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(
        find.textContaining('est-elle toujours disponible'),
        findsOneWidget,
      );

      await tester.tap(sendInDialog);
      await tester.pumpAndSettle();

      final started = env.chat.started.single;
      expect(started.sellerId, 's1');
      expect(started.productId, 'p1');
      expect(started.message, contains('Robe wax'));
      expect(find.text('ROUTE /messages/c1'), findsOneWidget);
    });

    testWidgets('annuler : aucune conversation créée', (tester) async {
      final env = await pumpDetail(tester);

      await tester.tap(find.text('Contacter le vendeur'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Annuler'));
      await tester.pumpAndSettle();

      expect(env.chat.started, isEmpty);
      expect(find.byType(AlertDialog), findsNothing);
    });

    testWidgets('message vide : envoi impossible', (tester) async {
      await pumpDetail(tester);
      await tester.tap(find.text('Contacter le vendeur'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), '   ');
      await tester.pump();

      expect(tester.widget<FilledButton>(sendInDialog).onPressed, isNull);
    });

    testWidgets('limite de 1000 caractères du premier message', (tester) async {
      await pumpDetail(tester);
      await tester.tap(find.text('Contacter le vendeur'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'x' * 1100);
      await tester.pump();

      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        hasLength(1000),
      );
    });

    testWidgets('utilisateur bloqué : message du serveur, dialogue conservé', (
      tester,
    ) async {
      final chat = FakeChatRepository()
        ..onStart = (sellerId, message, productId) async =>
            throw ApiError.fromResponse(403, <String, dynamic>{
              'message': "Cet utilisateur n'est pas joignable.",
            });
      await pumpDetail(tester, chat: chat);

      await tester.tap(find.text('Contacter le vendeur'));
      await tester.pumpAndSettle();
      await tester.tap(sendInDialog);
      await tester.pumpAndSettle();

      expect(find.text("Cet utilisateur n'est pas joignable."), findsOneWidget);
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('ROUTE /messages/c1'), findsNothing);
      expect(tester.widget<FilledButton>(sendInDialog).onPressed, isNotNull);
    });

    testWidgets('ma propre annonce : pas de bouton', (tester) async {
      await pumpDetail(tester, sellerId: 'u1');

      expect(find.text('Contacter le vendeur'), findsNothing);
    });
  });

  group('Contacter — profil vendeur', () {
    testWidgets('conversation générale, sans annonce', (tester) async {
      final env = await pumpScreen(
        tester,
        const SellerProfilePage(username: 'fatou'),
        authenticated: true,
      );

      await tapVisible(tester, find.text('Contacter'));
      expect(find.textContaining('Bonjour !'), findsOneWidget);
      await tester.tap(sendInDialog);
      await tester.pumpAndSettle();

      final started = env.chat.started.single;
      expect(started.sellerId, 'seller-1');
      expect(started.productId, isNull);
      expect(find.text('ROUTE /messages/c1'), findsOneWidget);
    });

    testWidgets('mon propre profil : pas de bouton', (tester) async {
      final profile = FakeProfileRepository()
        ..onPublicProfile = (username) async =>
            samplePublicProfile(id: 'u1', username: 'awa');
      await pumpScreen(
        tester,
        const SellerProfilePage(username: 'awa'),
        profile: profile,
        authenticated: true,
      );

      expect(find.text('Contacter'), findsNothing);
    });
  });

  group('Accès aux messages', () {
    testWidgets('Compte : entrée « Messages » avec le nombre de non lus', (
      tester,
    ) async {
      await pumpScreen(
        tester,
        const AccountPage(),
        chat: chatWithUnread([2, 1]),
        authenticated: true,
      );

      expect(find.text('Messages'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);

      await tapVisible(tester, find.text('Messages'));
      expect(find.text('ROUTE /messages'), findsOneWidget);
    });

    testWidgets('Accueil : enveloppe avec compteur de non lus', (tester) async {
      await pumpScreen(
        tester,
        const FeedPage(),
        chat: chatWithUnread([3]),
        authenticated: true,
      );

      expect(find.byTooltip('Messages (3 non lus)'), findsOneWidget);

      await tester.tap(find.byTooltip('Messages (3 non lus)'));
      await tester.pumpAndSettle();
      expect(find.text('ROUTE /messages'), findsOneWidget);
    });

    testWidgets('Accueil : sans message non lu, pas de compteur', (
      tester,
    ) async {
      await pumpScreen(tester, const FeedPage(), authenticated: true);

      expect(find.byTooltip('Messages'), findsOneWidget);
    });

    testWidgets('Accueil : compteur indisponible, l\'écran reste utilisable', (
      tester,
    ) async {
      final chat = FakeChatRepository()
        ..onConversations = (page) async => throw ApiError.network();
      await pumpScreen(
        tester,
        const FeedPage(),
        chat: chat,
        authenticated: true,
      );

      expect(find.byTooltip('Messages'), findsOneWidget);
    });
  });
}
