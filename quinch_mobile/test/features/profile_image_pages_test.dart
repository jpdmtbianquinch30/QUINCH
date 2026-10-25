import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quinch_mobile/core/media/picked_image.dart';
import 'package:quinch_mobile/core/network/api_error.dart';
import 'package:quinch_mobile/features/profile/edit_profile_page.dart';

import '../support/fakes.dart';
import '../support/pump.dart';

const mb = 1024 * 1024;

PickedImage image(String name, int size) =>
    PickedImage(path: '/tmp/$name', name: name, sizeBytes: size);

void main() {
  group('EditProfilePage — photos', () {
    testWidgets('photo de profil : envoyée au serveur, confirmation', (
      tester,
    ) async {
      final env = await pumpScreen(
        tester,
        const EditProfilePage(),
        pickImage: () async => image('moi.jpg', 2 * mb),
      );

      await tapVisible(tester, find.text('Changer ma photo'));

      expect(env.profile.uploadedAvatars, hasLength(1));
      expect(env.profile.uploadedAvatars.single.name, 'moi.jpg');
      expect(env.profile.uploadedCovers, isEmpty);
      expect(find.text('Photo de profil mise à jour.'), findsOneWidget);
    });

    testWidgets('couverture : 6 Mo acceptés (limite de 10 Mo)', (tester) async {
      final env = await pumpScreen(
        tester,
        const EditProfilePage(),
        pickImage: () async => image('couv.png', 6 * mb),
      );

      await tapVisible(tester, find.text('Changer la couverture'));

      expect(env.profile.uploadedCovers, hasLength(1));
      expect(find.text('Photo de couverture mise à jour.'), findsOneWidget);
    });

    testWidgets('photo de profil de 6 Mo : refusée sans envoi', (tester) async {
      final env = await pumpScreen(
        tester,
        const EditProfilePage(),
        pickImage: () async => image('grosse.jpg', 6 * mb),
      );

      await tapVisible(tester, find.text('Changer ma photo'));

      expect(env.profile.uploadedAvatars, isEmpty);
      expect(find.textContaining('dépasse 5 Mo'), findsOneWidget);
    });

    testWidgets('format non accepté : refusé sans envoi', (tester) async {
      final env = await pumpScreen(
        tester,
        const EditProfilePage(),
        pickImage: () async => image('anim.gif', 1000),
      );

      await tapVisible(tester, find.text('Changer ma photo'));

      expect(env.profile.uploadedAvatars, isEmpty);
      expect(find.textContaining('JPEG, PNG ou WebP'), findsWidgets);
    });

    testWidgets('galerie fermée sans choix : rien ne se passe', (tester) async {
      final env = await pumpScreen(tester, const EditProfilePage());

      await tapVisible(tester, find.text('Changer ma photo'));

      expect(env.profile.uploadedAvatars, isEmpty);
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('galerie impossible à ouvrir : message clair', (tester) async {
      await pumpScreen(
        tester,
        const EditProfilePage(),
        pickImage: () async => throw Exception('plugin'),
      );

      await tapVisible(tester, find.text('Changer ma photo'));

      expect(find.text("Impossible d'ouvrir la galerie."), findsOneWidget);
    });

    testWidgets('refus du serveur : message du champ affiché', (tester) async {
      final profile = FakeProfileRepository();
      profile.onUploadAvatar = (image) async =>
          throw ApiError.fromResponse(422, <String, dynamic>{
            'message': 'The avatar field is invalid.',
            'errors': <String, dynamic>{
              'avatar': <String>['La photo doit être une image valide.'],
            },
          });
      await pumpScreen(
        tester,
        const EditProfilePage(),
        profile: profile,
        pickImage: () async => image('moi.jpg', 1000),
      );

      await tapVisible(tester, find.text('Changer ma photo'));

      expect(find.text('La photo doit être une image valide.'), findsOneWidget);
    });
  });
}
