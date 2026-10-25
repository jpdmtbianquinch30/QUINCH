import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quinch_mobile/core/config/app_config.dart';
import 'package:quinch_mobile/core/media/picked_image.dart';
import 'package:quinch_mobile/core/network/api_client.dart';
import 'package:quinch_mobile/core/network/auth_token_holder.dart';
import 'package:quinch_mobile/core/network/dio_factory.dart';
import 'package:quinch_mobile/data/repositories/profile_repository.dart';

import '../support/fakes.dart';

PickedImage image(String name, int size) =>
    PickedImage(path: '/tmp/$name', name: name, sizeBytes: size);

const mb = 1024 * 1024;

void main() {
  group('validateProfileImage', () {
    test('image valide : aucune erreur', () {
      expect(
        validateProfileImage(ProfileImageKind.avatar, image('a.jpg', 1000)),
        isNull,
      );
      expect(
        validateProfileImage(ProfileImageKind.avatar, image('A.WEBP', 1000)),
        isNull,
      );
    });

    test('photo de profil : 5 Mo maximum, couverture : 10 Mo maximum', () {
      expect(
        validateProfileImage(ProfileImageKind.avatar, image('a.png', 5 * mb)),
        isNull,
      );
      expect(
        validateProfileImage(
          ProfileImageKind.avatar,
          image('a.png', 5 * mb + 1),
        ),
        contains('5 Mo'),
      );
      expect(
        validateProfileImage(ProfileImageKind.cover, image('c.png', 6 * mb)),
        isNull,
      );
      expect(
        validateProfileImage(
          ProfileImageKind.cover,
          image('c.png', 10 * mb + 1),
        ),
        contains('10 Mo'),
      );
    });

    test('format non accepté, fichier vide', () {
      expect(
        validateProfileImage(ProfileImageKind.avatar, image('a.gif', 1000)),
        contains('JPEG, PNG ou WebP'),
      );
      expect(
        validateProfileImage(ProfileImageKind.avatar, image('a.jpg', 0)),
        contains('vide'),
      );
    });

    test('sans extension : le serveur tranchera', () {
      expect(
        validateProfileImage(ProfileImageKind.avatar, image('photo', 1000)),
        isNull,
      );
    });

    test('champs attendus par le serveur', () {
      expect(ProfileImageKind.avatar.field, 'avatar');
      expect(ProfileImageKind.cover.field, 'cover');
    });
  });

  group('ProfileRepository — envoi des photos', () {
    late FakeAdapter adapter;
    late ApiClient api;
    late Directory tmp;
    late PickedImage picked;

    setUp(() async {
      tmp = await Directory.systemTemp.createTemp('quinch_img_');
      final file = File('${tmp.path}/photo.jpg');
      await file.writeAsBytes(<int>[1, 2, 3, 4]);
      picked = PickedImage(path: file.path, name: 'photo.jpg', sizeBytes: 4);

      adapter = FakeAdapter(
        (o) async => jsonResponse(<String, dynamic>{
          'message': 'Photo de profil mise à jour.',
          'avatar_url': 'https://api.quinch.sn/storage/avatars/u1/x.jpg',
          'user': <String, dynamic>{
            'id': 'u1',
            'email': 'awa@example.sn',
            'username': 'awa',
            'full_name': 'Awa Diop',
            'avatar_url': 'https://api.quinch.sn/storage/avatars/u1/x.jpg',
          },
        }, 200),
      );
      final config = AppConfig.parse(
        'https://api.quinch.sn/api/v1',
        allowInsecure: false,
      );
      final tokens = AuthTokenHolder();
      api = ApiClient(
        dio: createDio(config: config, tokens: tokens, adapter: adapter),
        tokens: tokens,
      );
    });

    tearDown(() async {
      // Sous Windows, le fichier peut rester verrouillé tant que le flux de
      // l'envoi n'est pas lu (le faux adaptateur ne le lit pas). Le dossier
      // est temporaire : le système le nettoiera.
      try {
        await tmp.delete(recursive: true);
      } on FileSystemException {
        // ignoré volontairement
      }
    });

    test('avatar : POST user/upload-avatar, champ « avatar »', () async {
      final user = await ProfileRepository(api).uploadAvatar(picked);

      final request = adapter.requests.single;
      expect(request.method, 'POST');
      expect(request.uri.path, '/api/v1/user/upload-avatar');
      final form = request.data as FormData;
      expect(form.files.single.key, 'avatar');
      expect(form.files.single.value.filename, 'photo.jpg');
      expect(user.avatarUrl, 'https://api.quinch.sn/storage/avatars/u1/x.jpg');
    });

    test('couverture : POST user/upload-cover, champ « cover »', () async {
      await ProfileRepository(api).uploadCover(picked);

      final request = adapter.requests.single;
      expect(request.method, 'POST');
      expect(request.uri.path, '/api/v1/user/upload-cover');
      expect((request.data as FormData).files.single.key, 'cover');
    });
  });
}
