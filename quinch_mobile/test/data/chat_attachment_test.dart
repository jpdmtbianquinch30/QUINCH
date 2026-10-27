import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quinch_mobile/core/config/app_config.dart';
import 'package:quinch_mobile/core/features/feature_availability.dart';
import 'package:quinch_mobile/core/media/chat_attachment.dart';
import 'package:quinch_mobile/core/network/api_client.dart';
import 'package:quinch_mobile/core/network/api_error.dart';
import 'package:quinch_mobile/core/network/auth_token_holder.dart';
import 'package:quinch_mobile/core/network/dio_factory.dart';
import 'package:quinch_mobile/data/repositories/chat_repository.dart';

import '../support/fakes.dart';

const mb = 1024 * 1024;

ChatAttachment image(String name, int size) => ChatAttachment(
  path: '/tmp/$name',
  name: name,
  sizeBytes: size,
  kind: ChatAttachmentKind.image,
);

ChatAttachment video(String name, int size) => ChatAttachment(
  path: '/tmp/$name',
  name: name,
  sizeBytes: size,
  kind: ChatAttachmentKind.video,
);

void main() {
  group('validateChatAttachment', () {
    test('images : formats du serveur, 20 Mo maximum', () {
      for (final name in ['a.jpg', 'a.JPEG', 'a.png', 'a.webp', 'sans_ext']) {
        expect(validateChatAttachment(image(name, 1000)), isNull, reason: name);
      }
      expect(validateChatAttachment(image('a.jpg', 20 * mb)), isNull);
      expect(
        validateChatAttachment(image('a.jpg', 20 * mb + 1)),
        contains('20 Mo'),
      );
      expect(
        validateChatAttachment(image('a.gif', 1000)),
        contains('JPEG, PNG ou WebP'),
      );
      expect(validateChatAttachment(image('a.jpg', 0)), contains('vide'));
    });

    test('vidéos : MP4, WebM, MOV, MKV (pas AVI, refusé par le chat)', () {
      for (final name in ['a.mp4', 'a.WEBM', 'a.mov', 'a.mkv']) {
        expect(validateChatAttachment(video(name, 1000)), isNull, reason: name);
      }
      expect(
        validateChatAttachment(video('a.avi', 1000)),
        contains('MP4, WebM, MOV ou MKV'),
      );
      expect(
        validateChatAttachment(video('a.mp4', 21 * mb)),
        contains('20 Mo'),
      );
    });

    test('taille lisible', () {
      expect(formatFileSize(1), '1 Ko');
      expect(formatFileSize(340 * 1024), '340 Ko');
      expect(formatFileSize(mb), '1,0 Mo');
      expect(formatFileSize((2.5 * mb).toInt()), '2,5 Mo');
    });
  });

  group('ChatMessage : pièces jointes', () {
    test('accesseurs de métadonnées du serveur', () {
      final m = sampleMessage(
        type: 'file',
        body: '',
        metadata: <String, dynamic>{
          'file_url': '/storage/chat/a.pdf',
          'file_name': 'devis.pdf',
          'file_size': 348160,
          'mime_type': 'application/pdf',
        },
      );

      expect(m.isFile, isTrue);
      expect(m.isAttachment, isTrue);
      expect(m.fileUrl, '/storage/chat/a.pdf');
      expect(m.fileName, 'devis.pdf');
      expect(m.fileSize, 348160);
    });

    test('image, vidéo, texte : types distincts', () {
      expect(sampleMessage(type: 'image').isImage, isTrue);
      expect(sampleMessage(type: 'video').isVideo, isTrue);
      expect(sampleMessage().isAttachment, isFalse);
      expect(sampleMessage(type: 'image').fileUrl, isNull);
    });
  });

  group('ChatRepository.sendFile', () {
    late Directory tmp;
    late ChatAttachment picked;

    ChatRepository repoFor(FakeAdapter adapter) {
      final config = AppConfig.parse(
        'https://api.quinch.sn/api/v1',
        allowInsecure: false,
      );
      final tokens = AuthTokenHolder();
      return ChatRepository(
        ApiClient(
          dio: createDio(config: config, tokens: tokens, adapter: adapter),
          tokens: tokens,
        ),
      );
    }

    setUp(() async {
      tmp = await Directory.systemTemp.createTemp('quinch_chat_');
      final file = File('${tmp.path}/photo.jpg');
      await file.writeAsBytes(<int>[1, 2, 3]);
      picked = ChatAttachment(
        path: file.path,
        name: 'photo.jpg',
        sizeBytes: 3,
        kind: ChatAttachmentKind.image,
      );
    });

    tearDown(() async {
      // Sous Windows, le fichier peut rester verrouillé tant que le flux de
      // l'envoi n'est pas lu (le faux adaptateur ne le lit pas).
      try {
        await tmp.delete(recursive: true);
      } on FileSystemException {
        // dossier temporaire : nettoyé par le système
      }
    });

    test(
      'POST conversations/{id}/file, champ « file », message renvoyé',
      () async {
        final adapter = FakeAdapter(
          (o) async => jsonResponse(<String, dynamic>{
            'message': <String, dynamic>{
              'id': 'm9',
              'sender_id': 'u1',
              'type': 'image',
              'body': '',
              'metadata': <String, dynamic>{
                'file_url': 'https://api.quinch.sn/storage/chat/photo.jpg',
                'file_name': 'photo.jpg',
                'file_size': 3,
              },
            },
          }, 201),
        );

        final sent = await repoFor(adapter).sendFile('c1', picked);

        final request = adapter.requests.single;
        expect(request.method, 'POST');
        expect(request.uri.path, '/api/v1/conversations/c1/file');
        final form = request.data as FormData;
        expect(form.files.single.key, 'file');
        expect(form.files.single.value.filename, 'photo.jpg');
        expect(sent.isImage, isTrue);
        expect(sent.fileName, 'photo.jpg');
      },
    );

    test('403 « bientôt disponible » : message du serveur conservé', () async {
      final adapter = FakeAdapter(
        (o) async => jsonResponse(<String, dynamic>{
          'message': "L'envoi de ce type de fichier sera bientôt disponible.",
        }, 403),
      );

      await expectLater(
        repoFor(adapter).sendFile('c1', picked),
        throwsA(
          isA<ApiError>()
              .having((e) => e.statusCode, 'statusCode', 403)
              .having(
                (e) => e.userMessage,
                'userMessage',
                "L'envoi de ce type de fichier sera bientôt disponible.",
              ),
        ),
      );
    });
  });

  group('Indicateur chat_file', () {
    test('403 « bientôt disponible » : fonction indisponible', () {
      final error = ApiError.fromResponse(403, <String, dynamic>{
        'message': "L'envoi de ce type de fichier sera bientôt disponible.",
      });
      expect(
        statusAfterCall(FeatureStatus.unknown, error: error),
        FeatureStatus.unavailable,
      );
    });

    test('autre 403 ou autre erreur : état inchangé', () {
      final other = ApiError.fromResponse(403, <String, dynamic>{
        'message': "Cet utilisateur n'est pas joignable.",
      });
      expect(
        statusAfterCall(FeatureStatus.unknown, error: other),
        FeatureStatus.unknown,
      );
      expect(
        statusAfterCall(FeatureStatus.available, error: ApiError.network()),
        FeatureStatus.available,
      );
      expect(statusAfterCall(FeatureStatus.unknown), FeatureStatus.available);
    });
  });
}
