import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:quinch_mobile/app/router.dart';
import 'package:quinch_mobile/core/network/api_error.dart';
import 'package:quinch_mobile/data/models/chat.dart';
import 'package:quinch_mobile/features/chat/chat_page.dart';
import 'package:quinch_mobile/features/chat/messages_page.dart';

import '../support/fakes.dart';
import '../support/pump.dart';

const t1 = '2026-10-25T10:00:00.000000Z';
const t2 = '2026-10-25T10:01:00.000000Z';
const t3 = '2026-10-25T10:02:00.000000Z';
const t4 = '2026-10-25T10:03:00.000000Z';

final m1 = sampleMessage(
  id: 'm1',
  senderId: 'u2',
  body: 'Bonjour, toujours disponible ?',
  createdAt: t1,
);
final m2 = sampleMessage(
  id: 'm2',
  senderId: 'u1',
  body: 'Oui !',
  createdAt: t2,
);

FakeChatRepository chatWith(List<ChatMessage> messages) =>
    FakeChatRepository()
      ..onConversation = (id) async => ConversationDetail(
        conversation: sampleConversation(id: id, productTitle: 'Robe wax'),
        messages: messages,
      );

Future<ScreenEnv> pumpChat(WidgetTester tester, FakeChatRepository chat) =>
    pumpScreen(
      tester,
      const ChatPage(conversationId: 'c1'),
      chat: chat,
      authenticated: true,
    );

Finder get sendButton => find.widgetWithIcon(IconButton, Icons.send);

Future<void> typeMessage(WidgetTester tester, String text) async {
  await tester.enterText(find.byType(TextField), text);
  await tester.pump();
}

Future<void> tapSend(WidgetTester tester) async {
  await tester.tap(find.byTooltip('Envoyer'));
  await tester.pumpAndSettle();
}

/// Laisse passer un intervalle de consultation et traite sa réponse.
Future<void> nextPoll(WidgetTester tester) async {
  await tester.pump(ChatPage.pollInterval);
  await tester.pump();
}

void main() {
  group('MessagesPage (boîte de réception)', () {
    Future<ScreenEnv> pumpInbox(WidgetTester tester, FakeChatRepository chat) =>
        pumpScreen(
          tester,
          const MessagesPage(),
          chat: chat,
          authenticated: true,
        );

    testWidgets('conversations, dernier message, annonce et non lus', (
      tester,
    ) async {
      final chat = FakeChatRepository()
        ..onConversations = (page) async => pageOf<Conversation>([
          sampleConversation(
            id: 'c1',
            otherName: 'Fatou Sow',
            unread: 3,
            last: sampleMessage(body: 'Oui, disponible'),
            productTitle: 'Robe wax',
          ),
          sampleConversation(
            id: 'c2',
            otherName: 'Moussa Ba',
            last: sampleMessage(id: 'm7', type: 'image', body: ''),
          ),
        ]);
      await pumpInbox(tester, chat);

      expect(find.text('Fatou Sow'), findsOneWidget);
      expect(find.text('À propos de : Robe wax'), findsOneWidget);
      expect(find.text('Oui, disponible'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
      expect(find.text('Moussa Ba'), findsOneWidget);
      expect(find.text('Photo'), findsOneWidget);
    });

    testWidgets('aucune conversation : message d\'invitation', (tester) async {
      await pumpInbox(tester, FakeChatRepository());

      expect(find.textContaining('Aucune conversation'), findsOneWidget);
    });

    testWidgets('erreur réseau : « Réessayer »', (tester) async {
      var attempts = 0;
      final chat = FakeChatRepository()
        ..onConversations = (page) async {
          attempts++;
          if (attempts == 1) {
            throw ApiError.network();
          }
          return pageOf<Conversation>([sampleConversation(id: 'c1')]);
        };
      await pumpInbox(tester, chat);
      expect(find.text('Réessayer'), findsOneWidget);

      await tapVisible(tester, find.text('Réessayer'));

      expect(find.text('Fatou Sow'), findsOneWidget);
    });

    testWidgets('ouvrir une conversation puis revenir : liste rechargée', (
      tester,
    ) async {
      final chat = FakeChatRepository()
        ..onConversations = (page) async =>
            pageOf<Conversation>([sampleConversation(id: 'c1')]);
      await pumpInbox(tester, chat);
      final before = chat.conversationsCalls;

      await tapVisible(tester, find.text('Fatou Sow'));
      expect(find.text('ROUTE /messages/c1'), findsOneWidget);

      GoRouter.of(tester.element(find.text('ROUTE /messages/c1'))).pop();
      await tester.pumpAndSettle();

      expect(chat.conversationsCalls, greaterThan(before));
    });
  });

  group('ChatPage', () {
    testWidgets('messages, interlocuteur et annonce liée', (tester) async {
      await pumpChat(tester, chatWith([m1, m2]));

      expect(find.text('Fatou Sow'), findsOneWidget);
      expect(find.text('Robe wax'), findsOneWidget);
      expect(find.text('Bonjour, toujours disponible ?'), findsOneWidget);
      expect(find.text('Oui !'), findsOneWidget);
    });

    testWidgets('conversation vide : invitation à écrire', (tester) async {
      await pumpChat(tester, chatWith(<ChatMessage>[]));

      expect(
        find.textContaining('Aucun message pour le moment'),
        findsOneWidget,
      );
    });

    testWidgets('chargement impossible : message et nouvel essai', (
      tester,
    ) async {
      var attempts = 0;
      final chat = chatWith([m1])
        ..onConversation = (id) async {
          attempts++;
          if (attempts == 1) {
            throw ApiError.network();
          }
          return ConversationDetail(
            conversation: sampleConversation(id: id),
            messages: [m1],
          );
        };
      await pumpChat(tester, chat);
      expect(find.text(ApiError.network().userMessage), findsOneWidget);

      await tapVisible(tester, find.widgetWithText(FilledButton, 'Réessayer'));

      expect(find.text('Bonjour, toujours disponible ?'), findsOneWidget);
    });

    testWidgets('envoi : message affiché, champ vidé', (tester) async {
      final chat = chatWith([m1]);
      await pumpChat(tester, chat);

      await typeMessage(tester, 'Salut');
      await tapSend(tester);

      expect(chat.sent, ['Salut']);
      expect(find.text('Salut'), findsOneWidget);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        isEmpty,
      );
    });

    testWidgets('message vide ou d\'espaces : envoi impossible', (
      tester,
    ) async {
      await pumpChat(tester, chatWith([m1]));
      expect(tester.widget<IconButton>(sendButton).onPressed, isNull);

      await typeMessage(tester, '   ');
      expect(tester.widget<IconButton>(sendButton).onPressed, isNull);

      await typeMessage(tester, 'a');
      expect(tester.widget<IconButton>(sendButton).onPressed, isNotNull);
    });

    testWidgets('limite de 2000 caractères', (tester) async {
      await pumpChat(tester, chatWith([m1]));

      await typeMessage(tester, 'x' * 2100);

      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        hasLength(2000),
      );
    });

    testWidgets('envoi en cours : « Envoi… »', (tester) async {
      final gate = Completer<ChatMessage>();
      final chat = chatWith([m1])..onSend = (id, body) => gate.future;
      await pumpChat(tester, chat);

      await typeMessage(tester, 'Salut');
      await tester.tap(find.byTooltip('Envoyer'));
      await tester.pump();

      expect(find.text('Envoi…'), findsOneWidget);
      gate.complete(sampleMessage(id: 's1', senderId: 'u1', body: 'Salut'));
      await tester.pumpAndSettle();
      expect(find.text('Envoi…'), findsNothing);
    });

    testWidgets('utilisateur bloqué : message non envoyé, réessayer', (
      tester,
    ) async {
      final chat = chatWith([m1])
        ..onSend = (id, body) async => throw ApiError.fromResponse(
          403,
          <String, dynamic>{'message': "Cet utilisateur n'est pas joignable."},
        );
      await pumpChat(tester, chat);

      await typeMessage(tester, 'Salut');
      await tapSend(tester);

      expect(
        find.text("Non envoyé : Cet utilisateur n'est pas joignable."),
        findsOneWidget,
      );
      expect(find.text('Salut'), findsOneWidget);

      chat.onSend = (id, body) async =>
          sampleMessage(id: 's1', senderId: 'u1', body: body, createdAt: t4);
      await tester.tap(find.text('Réessayer'));
      await tester.pumpAndSettle();

      expect(chat.sent, ['Salut', 'Salut']);
      expect(find.textContaining('Non envoyé'), findsNothing);
      expect(find.text('Salut'), findsOneWidget);
    });

    testWidgets('supprimer un message non envoyé', (tester) async {
      final chat = chatWith([m1])
        ..onSend = (id, body) async => throw ApiError.network();
      await pumpChat(tester, chat);
      await typeMessage(tester, 'Salut');
      await tapSend(tester);
      expect(find.textContaining('Non envoyé'), findsOneWidget);

      await tester.tap(find.text('Supprimer'));
      await tester.pumpAndSettle();

      expect(find.text('Salut'), findsNothing);
    });

    testWidgets('types non gérés et message lié à une annonce', (tester) async {
      final tagged = sampleMessage(
        id: 'm3',
        senderId: 'u1',
        body: 'Toujours disponible ?',
        type: 'product_tag',
        createdAt: t3,
        metadata: <String, dynamic>{
          'product_title': 'Robe wax rouge',
          'product_slug': 'robe-wax',
        },
      );
      final audio = sampleMessage(
        id: 'm4',
        type: 'audio',
        body: '',
        createdAt: t4,
      );
      await pumpChat(tester, chatWith([m1, tagged, audio]));

      expect(find.text('Robe wax rouge'), findsOneWidget);
      expect(find.text('Toujours disponible ?'), findsOneWidget);
      expect(find.textContaining("n'est pas pris en charge"), findsOneWidget);
    });
  });

  group('ChatPage — actualisation périodique', () {
    testWidgets('nouveaux messages demandés après le dernier connu', (
      tester,
    ) async {
      final chat = chatWith([m1, m2]);
      final m3 = sampleMessage(
        id: 'm3',
        senderId: 'u2',
        body: 'Parfait, merci',
        createdAt: t3,
      );
      chat.onSince = (id, after) async => NewMessages(messages: [m3]);
      await pumpChat(tester, chat);
      expect(chat.sinceAfters, isEmpty);

      await nextPoll(tester);
      expect(chat.sinceAfters, [t2]);
      expect(find.text('Parfait, merci'), findsOneWidget);

      // Le message déjà connu n'est pas ajouté une seconde fois.
      await nextPoll(tester);
      expect(chat.sinceAfters, [t2, t3]);
      expect(find.text('Parfait, merci'), findsOneWidget);
    });

    testWidgets('message envoyé puis renvoyé par le serveur : une seule fois', (
      tester,
    ) async {
      final sent = sampleMessage(
        id: 's1',
        senderId: 'u1',
        body: 'Salut',
        createdAt: t3,
      );
      final chat = chatWith([m1, m2]);
      chat.onSend = (id, body) async => sent;
      chat.onSince = (id, after) async => NewMessages(messages: [sent]);
      await pumpChat(tester, chat);
      await typeMessage(tester, 'Salut');
      await tapSend(tester);

      await nextPoll(tester);

      expect(find.text('Salut'), findsOneWidget);
    });

    testWidgets('application en arrière-plan : aucune consultation', (
      tester,
    ) async {
      final chat = chatWith([m1]);
      await pumpChat(tester, chat);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await nextPoll(tester);
      await nextPoll(tester);
      expect(chat.sinceAfters, isEmpty);

      // Comme sur un appareil : en pause → masquée → inactive → active.
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(chat.sinceAfters, hasLength(1));
    });

    testWidgets('écran recouvert par un autre : aucune consultation', (
      tester,
    ) async {
      final chat = chatWith([m1]);
      await pumpChat(tester, chat);

      GoRouter.of(tester.element(find.byType(ChatPage))).push(messagesPath);
      await tester.pumpAndSettle();
      await nextPoll(tester);

      expect(chat.sinceAfters, isEmpty);
    });

    testWidgets('connexion perdue : bandeau, puis retour à la normale', (
      tester,
    ) async {
      final chat = chatWith([m1]);
      chat.onSince = (id, after) async => throw ApiError.network();
      await pumpChat(tester, chat);

      await nextPoll(tester);
      expect(find.textContaining('Connexion perdue'), findsOneWidget);

      chat.onSince = (id, after) async => const NewMessages(messages: []);
      await nextPoll(tester);
      expect(find.textContaining('Connexion perdue'), findsNothing);
    });

    testWidgets('écran fermé : la consultation s\'arrête', (tester) async {
      final chat = chatWith([m1]);
      await pumpChat(tester, chat);

      GoRouter.of(tester.element(find.byType(ChatPage))).pop();
      await tester.pumpAndSettle();
      await nextPoll(tester);

      expect(chat.sinceAfters, isEmpty);
    });
  });
}
