import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quinch_mobile/core/format/fcfa.dart';
import 'package:quinch_mobile/core/network/api_error.dart';
import 'package:quinch_mobile/data/models/chat.dart';
import 'package:quinch_mobile/features/chat/chat_format.dart';
import 'package:quinch_mobile/features/chat/chat_page.dart';
import 'package:quinch_mobile/features/chat/messages_page.dart';
import 'package:quinch_mobile/shared/widgets/product_widgets.dart';

import '../support/fakes.dart';
import '../support/pump.dart';

final other = sampleMessage(
  id: 'm1',
  senderId: 'u2',
  body: 'Bonjour, toujours disponible ?',
  createdAt: '2026-10-25T10:00:00.000000Z',
);
final mine = sampleMessage(
  id: 'm2',
  senderId: 'u1',
  body: 'Oui !',
  createdAt: '2026-10-25T10:01:00.000000Z',
);

FakeChatRepository chatWith(List<ChatMessage> messages) =>
    FakeChatRepository()
      ..onConversation = (id) async => ConversationDetail(
        conversation: sampleConversation(id: id),
        messages: messages,
      );

Future<ScreenEnv> pumpChat(WidgetTester tester, FakeChatRepository chat) =>
    pumpScreen(
      tester,
      const ChatPage(conversationId: 'c1'),
      chat: chat,
      authenticated: true,
    );

Finder get confirmButton => find.widgetWithText(FilledButton, 'Supprimer');

void main() {
  group('Messages : appui long', () {
    testWidgets('mon message : copier ou supprimer', (tester) async {
      await pumpChat(tester, chatWith([other, mine]));

      await tester.longPress(find.text('Oui !'));
      await tester.pumpAndSettle();

      expect(find.text('Copier le texte'), findsOneWidget);
      expect(find.text('Supprimer le message'), findsOneWidget);
    });

    testWidgets('message de l\'autre : copier seulement', (tester) async {
      await pumpChat(tester, chatWith([other, mine]));

      await tester.longPress(find.text('Bonjour, toujours disponible ?'));
      await tester.pumpAndSettle();

      expect(find.text('Copier le texte'), findsOneWidget);
      expect(find.text('Supprimer le message'), findsNothing);
    });

    testWidgets('copier : texte placé dans le presse-papiers', (tester) async {
      final copied = <String>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied.add((call.arguments as Map)['text'] as String);
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      await pumpChat(tester, chatWith([other, mine]));

      await tester.longPress(find.text('Oui !'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Copier le texte'));
      await tester.pumpAndSettle();

      expect(copied, ['Oui !']);
      expect(find.text('Message copié.'), findsOneWidget);
    });
  });

  group('Supprimer un de mes messages', () {
    Future<void> startDelete(WidgetTester tester) async {
      await tester.longPress(find.text('Oui !'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Supprimer le message'));
      await tester.pumpAndSettle();
    }

    testWidgets('confirmation claire : supprimé pour les deux personnes', (
      tester,
    ) async {
      final chat = chatWith([other, mine]);
      await pumpChat(tester, chat);

      await startDelete(tester);

      expect(find.text('Supprimer ce message ?'), findsOneWidget);
      expect(find.text(deleteMessageWarning), findsOneWidget);
      expect(chat.deletedMessages, isEmpty);
      expect(find.text('Oui !'), findsOneWidget);
    });

    testWidgets('annuler : rien n\'est supprimé', (tester) async {
      final chat = chatWith([other, mine]);
      await pumpChat(tester, chat);
      await startDelete(tester);

      await tester.tap(find.text('Annuler'));
      await tester.pumpAndSettle();

      expect(chat.deletedMessages, isEmpty);
      expect(find.text('Oui !'), findsOneWidget);
    });

    testWidgets('confirmer : retiré de l\'écran après réponse du serveur', (
      tester,
    ) async {
      final chat = chatWith([other, mine]);
      await pumpChat(tester, chat);
      await startDelete(tester);

      await tester.tap(confirmButton);
      await tester.pumpAndSettle();

      expect(chat.deletedMessages, [('c1', 'm2')]);
      expect(find.text('Oui !'), findsNothing);
      expect(find.text('Bonjour, toujours disponible ?'), findsOneWidget);
    });

    testWidgets('refus du serveur : le message reste, erreur affichée', (
      tester,
    ) async {
      final chat = chatWith([other, mine])
        ..onDeleteMessage = (conversationId, messageId) async =>
            throw ApiError.fromResponse(403, <String, dynamic>{
              'message': 'Vous ne pouvez supprimer que vos propres messages.',
            });
      await pumpChat(tester, chat);
      await startDelete(tester);

      await tester.tap(confirmButton);
      await tester.pumpAndSettle();

      expect(find.text('Oui !'), findsOneWidget);
      expect(
        find.text('Vous ne pouvez supprimer que vos propres messages.'),
        findsOneWidget,
      );
    });

    testWidgets('serveur injoignable : le message reste', (tester) async {
      final chat = chatWith([other, mine])
        ..onDeleteMessage = (conversationId, messageId) async =>
            throw ApiError.network();
      await pumpChat(tester, chat);
      await startDelete(tester);

      await tester.tap(confirmButton);
      await tester.pumpAndSettle();

      expect(find.text('Oui !'), findsOneWidget);
      expect(find.text(ApiError.network().userMessage), findsOneWidget);
    });
  });

  group('Supprimer la conversation (depuis la conversation)', () {
    Future<void> startDelete(WidgetTester tester) async {
      await tester.tap(find.byTooltip('Options de la conversation'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Supprimer la conversation'));
      await tester.pumpAndSettle();
    }

    testWidgets('confirmation claire, rien n\'est supprimé avant', (
      tester,
    ) async {
      final chat = chatWith([other, mine]);
      await pumpChat(tester, chat);

      await startDelete(tester);

      expect(find.text('Supprimer cette conversation ?'), findsOneWidget);
      expect(find.text(deleteConversationWarning), findsOneWidget);
      expect(chat.deletedConversation, isEmpty);
    });

    testWidgets('annuler : on reste dans la conversation', (tester) async {
      final chat = chatWith([other, mine]);
      await pumpChat(tester, chat);
      await startDelete(tester);

      await tester.tap(find.text('Annuler'));
      await tester.pumpAndSettle();

      expect(chat.deletedConversation, isEmpty);
      expect(find.byType(ChatPage), findsOneWidget);
    });

    testWidgets('confirmer : suppression puis retour à la liste', (
      tester,
    ) async {
      final chat = chatWith([other, mine]);
      await pumpChat(tester, chat);
      await startDelete(tester);

      await tester.tap(confirmButton);
      await tester.pumpAndSettle();

      expect(chat.deletedConversation, ['c1']);
      expect(find.byType(ChatPage), findsNothing);
      expect(find.text('Conversation supprimée.'), findsOneWidget);
    });

    testWidgets('échec : on reste dans la conversation avec l\'erreur', (
      tester,
    ) async {
      final chat = chatWith([other, mine])
        ..onDeleteConversation = (id) async => throw ApiError.network();
      await pumpChat(tester, chat);
      await startDelete(tester);

      await tester.tap(confirmButton);
      await tester.pumpAndSettle();

      expect(find.byType(ChatPage), findsOneWidget);
      expect(find.text(ApiError.network().userMessage), findsOneWidget);
    });
  });

  group('Boîte de réception : suppression multiple', () {
    final c1 = sampleConversation(id: 'c1', otherName: 'Fatou Sow');
    final c2 = sampleConversation(id: 'c2', otherName: 'Moussa Ba');
    final c3 = sampleConversation(id: 'c3', otherName: 'Awa Diop');

    FakeChatRepository inbox() =>
        FakeChatRepository()
          ..onConversations = (page) async =>
              pageOf<Conversation>([c1, c2, c3]);

    Future<ScreenEnv> pumpInbox(WidgetTester tester, FakeChatRepository chat) =>
        pumpScreen(
          tester,
          const MessagesPage(),
          chat: chat,
          authenticated: true,
        );

    testWidgets('appui long : mode sélection avec compteur', (tester) async {
      await pumpInbox(tester, inbox());

      await tester.longPress(find.text('Fatou Sow'));
      await tester.pumpAndSettle();
      expect(find.text('1 sélectionnée'), findsOneWidget);
      expect(find.byType(Checkbox), findsNWidgets(3));

      await tester.tap(find.text('Moussa Ba'));
      await tester.pumpAndSettle();
      expect(find.text('2 sélectionnées'), findsOneWidget);

      // Toucher une ligne cochée la décoche ; sans sélection, on quitte le mode.
      await tester.tap(find.text('Moussa Ba'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Fatou Sow'));
      await tester.pumpAndSettle();
      expect(find.text('Messages'), findsOneWidget);
      expect(find.byType(Checkbox), findsNothing);
    });

    testWidgets('annuler la sélection', (tester) async {
      await pumpInbox(tester, inbox());
      await tester.longPress(find.text('Fatou Sow'));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Annuler la sélection'));
      await tester.pumpAndSettle();

      expect(find.text('Messages'), findsOneWidget);
    });

    testWidgets('retour système : annule la sélection sans quitter l\'écran', (
      tester,
    ) async {
      await pumpInbox(tester, inbox());
      await tester.longPress(find.text('Fatou Sow'));
      await tester.pumpAndSettle();

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(find.text('Messages'), findsOneWidget);
      expect(find.byType(MessagesPage), findsOneWidget);
    });

    testWidgets('confirmation claire avant la suppression', (tester) async {
      final chat = inbox();
      await pumpInbox(tester, chat);
      await tester.longPress(find.text('Fatou Sow'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Moussa Ba'));
      await tester.pumpAndSettle();

      await tester.tap(
        find.byTooltip('Supprimer les conversations sélectionnées'),
      );
      await tester.pumpAndSettle();

      expect(find.text('Supprimer 2 conversations ?'), findsOneWidget);
      expect(find.text(deleteConversationsWarning(2)), findsOneWidget);
      expect(chat.deletedBulk, isEmpty);
    });

    testWidgets(
      'confirmer : un seul appel, liste mise à jour après le serveur',
      (tester) async {
        var deleted = false;
        final chat = FakeChatRepository();
        chat.onConversations = (page) async =>
            pageOf<Conversation>(deleted ? [c3] : [c1, c2, c3]);
        chat.onDeleteConversations = (ids) async {
          deleted = true;
          return ids;
        };
        await pumpInbox(tester, chat);
        await tester.longPress(find.text('Fatou Sow'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Moussa Ba'));
        await tester.pumpAndSettle();
        await tester.tap(
          find.byTooltip('Supprimer les conversations sélectionnées'),
        );
        await tester.pumpAndSettle();

        await tester.tap(confirmButton);
        await tester.pumpAndSettle();

        expect(chat.deletedBulk, [
          ['c1', 'c2'],
        ]);
        expect(find.text('Conversations supprimées.'), findsOneWidget);
        expect(find.text('Fatou Sow'), findsNothing);
        expect(find.text('Moussa Ba'), findsNothing);
        expect(find.text('Awa Diop'), findsOneWidget);
        expect(find.text('Messages'), findsOneWidget);
      },
    );

    testWidgets('annuler la confirmation : rien n\'est supprimé', (
      tester,
    ) async {
      final chat = inbox();
      await pumpInbox(tester, chat);
      await tester.longPress(find.text('Fatou Sow'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byTooltip('Supprimer les conversations sélectionnées'),
      );
      await tester.pumpAndSettle();
      expect(find.text('Supprimer cette conversation ?'), findsOneWidget);

      await tester.tap(find.text('Annuler'));
      await tester.pumpAndSettle();

      expect(chat.deletedBulk, isEmpty);
      expect(find.text('1 sélectionnée'), findsOneWidget);
    });

    testWidgets('échec : conversations conservées, sélection gardée', (
      tester,
    ) async {
      final chat = inbox()
        ..onDeleteConversations = (ids) async => throw ApiError.network();
      await pumpInbox(tester, chat);
      await tester.longPress(find.text('Fatou Sow'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byTooltip('Supprimer les conversations sélectionnées'),
      );
      await tester.pumpAndSettle();

      await tester.tap(confirmButton);
      await tester.pumpAndSettle();

      expect(find.text('Fatou Sow'), findsOneWidget);
      expect(find.text('1 sélectionnée'), findsOneWidget);
      expect(find.text(ApiError.network().userMessage), findsOneWidget);
    });

    testWidgets('suppression partielle : signalée', (tester) async {
      final chat = inbox()..onDeleteConversations = (ids) async => [ids.first];
      await pumpInbox(tester, chat);
      await tester.longPress(find.text('Fatou Sow'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Moussa Ba'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byTooltip('Supprimer les conversations sélectionnées'),
      );
      await tester.pumpAndSettle();

      await tester.tap(confirmButton);
      await tester.pumpAndSettle();

      expect(
        find.text("Certaines conversations n'ont pas pu être supprimées."),
        findsOneWidget,
      );
    });
  });

  group('Cartes d\'annonce', () {
    ChatMessage tagged(Map<String, dynamic> metadata) => sampleMessage(
      id: 'm9',
      senderId: 'u1',
      body: 'Toujours disponible ?',
      type: 'product_tag',
      createdAt: '2026-10-25T10:02:00.000000Z',
      metadata: metadata,
    );

    testWidgets('image, titre et prix issus du serveur', (tester) async {
      await pumpChat(
        tester,
        chatWith([
          tagged(<String, dynamic>{
            'product_title': 'Robe wax rouge',
            'product_slug': 'robe-wax',
            'product_price': '15000.00',
            'product_image': 'https://cdn.example/robe.jpg',
          }),
        ]),
      );

      expect(find.text('Robe wax rouge'), findsOneWidget);
      expect(find.text(formatFcfa(15000)), findsOneWidget);
      expect(find.byType(QuinchImage), findsOneWidget);
      expect(find.text('Toujours disponible ?'), findsOneWidget);
    });

    testWidgets('champs absents : rien d\'inventé', (tester) async {
      await pumpChat(
        tester,
        chatWith([
          tagged(<String, dynamic>{'product_title': 'Robe wax rouge'}),
        ]),
      );

      expect(find.text('Robe wax rouge'), findsOneWidget);
      expect(find.byType(QuinchImage), findsNothing);
      expect(find.textContaining('FCFA'), findsNothing);
    });

    testWidgets('toucher la carte ouvre l\'annonce', (tester) async {
      await pumpChat(
        tester,
        chatWith([
          tagged(<String, dynamic>{
            'product_title': 'Robe wax rouge',
            'product_slug': 'robe-wax',
          }),
        ]),
      );

      await tester.tap(find.text('Robe wax rouge'));
      await tester.pumpAndSettle();

      expect(find.text('ROUTE /product/robe-wax'), findsOneWidget);
    });

    testWidgets('message de contact sans métadonnées : texte seul', (
      tester,
    ) async {
      await pumpChat(
        tester,
        chatWith([
          sampleMessage(
            id: 'm8',
            senderId: 'u1',
            body: 'Bonjour',
            type: 'product_tag',
          ),
        ]),
      );

      expect(find.text('Bonjour'), findsOneWidget);
      expect(find.byType(QuinchImage), findsNothing);
    });
  });
}
