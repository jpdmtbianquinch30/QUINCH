import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quinch_mobile/core/config/app_config.dart';
import 'package:quinch_mobile/core/media/picked_video.dart';
import 'package:quinch_mobile/core/network/api_client.dart';
import 'package:quinch_mobile/core/network/api_error.dart';
import 'package:quinch_mobile/core/network/auth_token_holder.dart';
import 'package:quinch_mobile/core/network/dio_factory.dart';
import 'package:quinch_mobile/data/repositories/product_repository.dart';

import '../support/fakes.dart';

const mb = 1024 * 1024;

PickedVideo video(String name, int size) =>
    PickedVideo(path: '/tmp/$name', name: name, sizeBytes: size);

void main() {
  group('validateListingVideo', () {
    test('formats acceptés, quelle que soit la casse', () {
      for (final name in [
        'a.mp4',
        'a.MOV',
        'a.avi',
        'a.WebM',
        'sans_extension',
      ]) {
        expect(validateListingVideo(video(name, 1000)), isNull, reason: name);
      }
    });

    test('500 Mo maximum', () {
      expect(validateListingVideo(video('a.mp4', 500 * mb)), isNull);
      expect(
        validateListingVideo(video('a.mp4', 500 * mb + 1)),
        'La vidéo ne doit pas dépasser 500 Mo.',
      );
    });

    test('format refusé, fichier vide', () {
      expect(
        validateListingVideo(video('a.mkv', 1000)),
        contains('MP4, MOV, AVI ou WebM'),
      );
      expect(validateListingVideo(video('a.mp4', 0)), contains('vide'));
    });

    test('avertissement au-delà de 200 Mo seulement', () {
      expect(videoNeedsSizeWarning(video('a.mp4', 200 * mb)), isFalse);
      expect(videoNeedsSizeWarning(video('a.mp4', 200 * mb + 1)), isTrue);
    });

    test('taille affichée arrondie au Mo supérieur', () {
      expect(formatMegabytes(230 * mb), '230 Mo');
      expect(formatMegabytes(1), '1 Mo');
      expect(formatMegabytes(250 * mb + 1), '251 Mo');
    });
  });

  group('ProductRepository.uploadVideo', () {
    late Directory tmp;
    late PickedVideo picked;

    ProductRepository repoFor(FakeAdapter adapter) {
      final config = AppConfig.parse(
        'https://api.quinch.sn/api/v1',
        allowInsecure: false,
      );
      final tokens = AuthTokenHolder();
      return ProductRepository(
        ApiClient(
          dio: createDio(config: config, tokens: tokens, adapter: adapter),
          tokens: tokens,
        ),
      );
    }

    setUp(() async {
      tmp = await Directory.systemTemp.createTemp('quinch_vid_');
      final file = File('${tmp.path}/clip.mp4');
      await file.writeAsBytes(<int>[1, 2, 3]);
      picked = PickedVideo(path: file.path, name: 'clip.mp4', sizeBytes: 3);
    });

    tearDown(() async {
      // Voir profile_images_test : sous Windows le fichier peut rester verrouillé.
      try {
        await tmp.delete(recursive: true);
      } on FileSystemException {
        // dossier temporaire : nettoyé par le système
      }
    });

    test('201 : POST products/upload-video, champ « video »', () async {
      final adapter = FakeAdapter(
        (o) async => jsonResponse(<String, dynamic>{
          'message': 'Vidéo uploadée avec succès. Traitement en cours.',
          'video': <String, dynamic>{'id': 'vid-9'},
        }, 201),
      );

      final uploaded = await repoFor(adapter).uploadVideo(picked);

      final request = adapter.requests.single;
      expect(request.method, 'POST');
      expect(request.uri.path, '/api/v1/products/upload-video');
      final form = request.data as FormData;
      expect(form.files.single.key, 'video');
      expect(form.files.single.value.filename, 'clip.mp4');
      expect(uploaded.id, 'vid-9');
      expect(uploaded.alreadyOnServer, isFalse);
    });

    test('409 avec la vidéo du compte : reprise', () async {
      final adapter = FakeAdapter(
        (o) async => jsonResponse(<String, dynamic>{
          'message': 'Cette vidéo existe déjà.',
          'video': <String, dynamic>{'id': 'vid-own'},
        }, 409),
      );

      final uploaded = await repoFor(adapter).uploadVideo(picked);

      expect(uploaded.id, 'vid-own');
      expect(uploaded.alreadyOnServer, isTrue);
    });

    test('409 sans vidéo (celle d\'un autre) : erreur relancée', () async {
      final adapter = FakeAdapter(
        (o) async => jsonResponse(<String, dynamic>{
          'message': 'Cette vidéo existe déjà.',
        }, 409),
      );

      await expectLater(
        repoFor(adapter).uploadVideo(picked),
        throwsA(
          isA<ApiError>()
              .having((e) => e.statusCode, 'statusCode', 409)
              .having(
                (e) => e.serverMessage,
                'message',
                'Cette vidéo existe déjà.',
              ),
        ),
      );
    });

    test('422 bloquée par la modération : message du serveur', () async {
      final adapter = FakeAdapter(
        (o) async => jsonResponse(<String, dynamic>{
          'message': 'Cette vidéo a été retirée par la modération.',
          'code': 'video_blocked',
        }, 422),
      );

      await expectLater(
        repoFor(adapter).uploadVideo(picked),
        throwsA(
          isA<ApiError>()
              .having((e) => e.kind, 'kind', ApiErrorKind.validation)
              .having(
                (e) => e.userMessage,
                'userMessage',
                'Cette vidéo a été retirée par la modération.',
              ),
        ),
      );
    });

    test('réponse sans identifiant de vidéo : erreur', () async {
      final adapter = FakeAdapter(
        (o) async => jsonResponse(<String, dynamic>{}, 201),
      );

      await expectLater(
        repoFor(adapter).uploadVideo(picked),
        throwsA(isA<ApiError>()),
      );
    });
  });
}
