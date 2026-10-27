import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quinch_mobile/core/media/chat_attachment.dart';
import 'package:quinch_mobile/core/media/picked_image.dart';
import 'package:quinch_mobile/core/media/picked_video.dart';
import 'package:quinch_mobile/core/network/api_error.dart';
import 'package:quinch_mobile/core/platform/image_picker.dart';
import 'package:quinch_mobile/data/models/chat.dart';
import 'package:quinch_mobile/features/chat/chat_page.dart';
import 'package:quinch_mobile/shared/widgets/product_widgets.dart';

import '../support/fakes.dart';
import '../support/pump.dart';

const mb = 1024 * 1024;

PickedImage photo(String name, [int size = 1000]) =>
    PickedImage(path: '/tmp/$name', name: name, sizeBytes: size);

PickedVideo clip(String name, [int size = 2 * mb]) =>
    PickedVideo(path: '/tmp/$name', name: name, sizeBytes: size);

FakeChatRepository emptyChat() =>
    FakeChatRepository()
      ..onConversation = (id) async => ConversationDetail(
        conversation: sampleConversation(id: id),
        messages: <ChatMessage>[],
      );

Future<ScreenEnv> pumpChat(
  WidgetTester tester,
  FakeChatRepository chat, {
  ImagePick? pickImage,
  VideoPick? pickVideo,
  List<Uri>? openedUrls,
}) => pumpScreen(
  tester,
  const ChatPage(conversationId: 'c1'),
  chat: chat,
  pickImage: pickImage,
  pickVideo: pickVideo,
  openedUrls: openedUrls,
  authenticated: true,
);

Future<void> chooseKind(WidgetTester tester, String label) async {
  await tester.tap(find.byTooltip('Joindre un fichier'));
  await tester.pumpAndSettle();
  await tester.tap(find.text(label));
  await tester.pumpAndSettle();
}

void main() {
  group('Envoi de pièces jointes', () {
    testWidgets('photo : envoyée au serveur et affichée', (tester) async {
      final chat = emptyChat();
      await pumpChat(tester, chat, pickImage: () async => photo('moi.jpg'));

      await chooseKind(tester, 'Photo');

      final file = chat.sentFiles.single;
      expect(file.name, 'moi.jpg');
      expect(file.kind, ChatAttachmentKind.image);
      expect(find.textContaining('Non envoyé'), findsNothing);
      expect(find.textContaining('Envoi…'), findsNothing);
      // Le message envoyé s'affiche comme une photo dans la conversation.
      expect(find.byType(QuinchImage), findsOneWidget);
    });

    testWidgets('vidéo : proposée tant que le serveur ne dit pas non', (
      tester,
    ) async {
      final chat = emptyChat();
      await pumpChat(tester, chat, pickVideo: () async => clip('film.mp4'));

      await chooseKind(tester, 'Vidéo');

      expect(chat.sentFiles.single.kind, ChatAttachmentKind.video);
    });

    testWidgets(
      'serveur : « bientôt disponible » → la vidéo n\'est plus proposée',
      (tester) async {
        var galleryCalls = 0;
        final chat = emptyChat()
          ..onSendFile = (id, file, onProgress) async =>
              throw ApiError.fromResponse(403, <String, dynamic>{
                'message':
                    "L'envoi de ce type de fichier sera bientôt disponible.",
              });
        await pumpChat(
          tester,
          chat,
          pickImage: () async {
            galleryCalls++;
            return null;
          },
          pickVideo: () async => clip('film.mp4'),
        );

        await chooseKind(tester, 'Vidéo');
        expect(
          find.text(
            "Non envoyé : L'envoi de ce type de fichier sera bientôt disponible.",
          ),
          findsOneWidget,
        );

        // Plus de choix Photo/Vidéo : la galerie des photos s'ouvre directement.
        await tester.tap(find.byTooltip('Joindre un fichier'));
        await tester.pumpAndSettle();
        expect(find.text('Vidéo'), findsNothing);
        expect(galleryCalls, 1);
      },
    );

    testWidgets('plus de 20 Mo ou format refusé : aucun envoi', (tester) async {
      var next = photo('gros.jpg', 21 * mb);
      final chat = emptyChat();
      await pumpChat(tester, chat, pickImage: () async => next);

      await chooseKind(tester, 'Photo');
      expect(find.textContaining('dépasse 20 Mo'), findsOneWidget);

      // Le bandeau d'erreur recouvre le bouton « Joindre » : on attend qu'il
      // disparaisse avant le second essai.
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();

      next = photo('anim.gif');
      await chooseKind(tester, 'Photo');
      expect(find.textContaining('JPEG, PNG ou WebP'), findsOneWidget);
      expect(chat.sentFiles, isEmpty);
    });

    testWidgets('galerie fermée sans choix : rien ne se passe', (tester) async {
      final chat = emptyChat();
      await pumpChat(tester, chat);

      await chooseKind(tester, 'Photo');

      expect(chat.sentFiles, isEmpty);
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('progression de l\'envoi', (tester) async {
      final gate = Completer<ChatMessage>();
      void Function(double)? report;
      final chat = emptyChat()
        ..onSendFile = (id, file, onProgress) {
          report = onProgress;
          return gate.future;
        };
      await pumpChat(tester, chat, pickImage: () async => photo('moi.jpg'));

      await chooseKind(tester, 'Photo');
      expect(find.text('Envoi… 0 %'), findsOneWidget);

      report!(0.5);
      await tester.pump();
      expect(find.text('Envoi… 50 %'), findsOneWidget);

      gate.complete(
        sampleMessage(
          id: 'f1',
          senderId: 'u1',
          type: 'image',
          body: '',
          metadata: <String, dynamic>{'file_url': 'https://x.example/a.jpg'},
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('Envoi…'), findsNothing);
    });

    testWidgets('échec puis nouvel essai', (tester) async {
      var attempts = 0;
      final chat = emptyChat()
        ..onSendFile = (id, file, onProgress) async {
          attempts++;
          if (attempts == 1) {
            throw ApiError.network();
          }
          return sampleMessage(
            id: 'f1',
            senderId: 'u1',
            type: 'image',
            body: '',
            metadata: <String, dynamic>{'file_url': 'https://x.example/a.jpg'},
          );
        };
      await pumpChat(tester, chat, pickImage: () async => photo('moi.jpg'));

      await chooseKind(tester, 'Photo');
      expect(find.textContaining('Non envoyé'), findsOneWidget);
      expect(find.text('moi.jpg'), findsOneWidget);

      await tester.tap(find.text('Réessayer'));
      await tester.pumpAndSettle();

      expect(chat.sentFiles, hasLength(2));
      expect(find.textContaining('Non envoyé'), findsNothing);
    });
  });

  group('Pièces jointes reçues', () {
    ChatMessage received({
      required String id,
      required String type,
      required String at,
      Map<String, dynamic>? metadata,
    }) => sampleMessage(
      id: id,
      type: type,
      body: '',
      createdAt: at,
      metadata: metadata,
    );

    FakeChatRepository chatWith(List<ChatMessage> messages) =>
        FakeChatRepository()
          ..onConversation = (id) async => ConversationDetail(
            conversation: sampleConversation(id: id),
            messages: messages,
          );

    testWidgets('fichier et vidéo : nom, taille, ouverture', (tester) async {
      final opened = <Uri>[];
      final chat = chatWith([
        received(
          id: 'a',
          type: 'file',
          at: '2026-10-25T10:00:00.000000Z',
          metadata: <String, dynamic>{
            'file_url': '/storage/chat/devis.pdf',
            'file_name': 'devis.pdf',
            'file_size': 348160,
          },
        ),
        received(
          id: 'b',
          type: 'video',
          at: '2026-10-25T10:01:00.000000Z',
          metadata: <String, dynamic>{
            'file_url': 'https://cdn.example/clip.mp4',
            'file_name': 'clip.mp4',
            'file_size': 3 * mb,
          },
        ),
      ]);
      await pumpChat(tester, chat, openedUrls: opened);

      expect(find.text('devis.pdf'), findsOneWidget);
      expect(find.text('340 Ko'), findsOneWidget);
      expect(find.text('clip.mp4'), findsOneWidget);
      expect(find.text('3,0 Mo'), findsOneWidget);

      await tester.tap(find.text('devis.pdf'));
      await tester.pumpAndSettle();
      expect(
        opened.last,
        Uri.parse('https://api.quinch.sn/storage/chat/devis.pdf'),
      );

      await tester.tap(find.text('clip.mp4'));
      await tester.pumpAndSettle();
      expect(opened.last, Uri.parse('https://cdn.example/clip.mp4'));
    });

    testWidgets('adresse non sûre : jamais ouverte', (tester) async {
      final opened = <Uri>[];
      final chat = chatWith([
        received(
          id: 'a',
          type: 'file',
          at: '2026-10-25T10:00:00.000000Z',
          metadata: <String, dynamic>{
            'file_url': 'http://evil.example/a.pdf',
            'file_name': 'piege.pdf',
          },
        ),
        received(
          id: 'b',
          type: 'file',
          at: '2026-10-25T10:01:00.000000Z',
          metadata: <String, dynamic>{
            'file_url': 'javascript:alert(1)',
            'file_name': 'script.pdf',
          },
        ),
      ]);
      await pumpChat(tester, chat, openedUrls: opened);

      await tester.tap(find.text('piege.pdf'));
      await tester.pumpAndSettle();
      expect(find.text('Ce fichier ne peut pas être ouvert.'), findsOneWidget);

      await tester.tap(find.text('script.pdf'));
      await tester.pumpAndSettle();

      expect(opened, isEmpty);
    });

    testWidgets('image : affichage en grand puis fermeture', (tester) async {
      final chat = chatWith([
        received(
          id: 'a',
          type: 'image',
          at: '2026-10-25T10:00:00.000000Z',
          metadata: <String, dynamic>{
            'file_url': 'https://cdn.example/photo.jpg',
            'file_name': 'photo.jpg',
          },
        ),
      ]);
      await pumpChat(tester, chat);

      await tester.tap(find.byType(QuinchImage));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Fermer'), findsOneWidget);

      await tester.tap(find.byTooltip('Fermer'));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Fermer'), findsNothing);
    });

    testWidgets('pièce jointe sans métadonnées : libellé par défaut', (
      tester,
    ) async {
      final chat = chatWith([
        received(id: 'a', type: 'file', at: '2026-10-25T10:00:00.000000Z'),
      ]);
      await pumpChat(tester, chat);

      expect(find.text('Fichier'), findsOneWidget);
      expect(find.text('Ouvrir'), findsOneWidget);
    });
  });
}
