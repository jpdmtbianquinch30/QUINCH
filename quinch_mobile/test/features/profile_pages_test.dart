import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quinch_mobile/app/router.dart';
import 'package:quinch_mobile/core/network/api_error.dart';
import 'package:quinch_mobile/core/session/session_controller.dart';
import 'package:quinch_mobile/core/session/session_state.dart';
import 'package:quinch_mobile/data/models/paginated.dart';
import 'package:quinch_mobile/data/models/product.dart';
import 'package:quinch_mobile/data/models/user.dart';
import 'package:quinch_mobile/data/repositories/safety_repository.dart';
import 'package:quinch_mobile/features/account/account_page.dart';
import 'package:quinch_mobile/features/product/product_detail_page.dart';
import 'package:quinch_mobile/features/profile/blocked_users_page.dart';
import 'package:quinch_mobile/features/profile/edit_profile_page.dart';
import 'package:quinch_mobile/features/profile/my_products_page.dart';
import 'package:quinch_mobile/features/profile/seller_profile_page.dart';
import 'package:quinch_mobile/features/profile/settings_page.dart';
import 'package:quinch_mobile/features/support/support_page.dart';

import '../support/fakes.dart';
import '../support/pump.dart';

void main() {
  group('EditProfilePage', () {
    testWidgets('préremplit le formulaire avec le profil du serveur', (
      tester,
    ) async {
      await pumpScreen(tester, const EditProfilePage());
      expect(find.text('Awa Diop'), findsOneWidget);
      expect(find.text('Dakar'), findsNWidgets(2)); // ville et région
      expect(find.text('Vendeuse de pagnes.'), findsOneWidget);
    });

    testWidgets('aucune modification : rien n\'est envoyé', (tester) async {
      final env = await pumpScreen(tester, const EditProfilePage());
      await tapVisible(
        tester,
        find.widgetWithText(FilledButton, 'Enregistrer'),
      );
      expect(find.text('Aucune modification.'), findsOneWidget);
      expect(env.profile.lastUpdate, isNull);
    });

    testWidgets(
      'modification du nom : seul ce champ est envoyé, session mise à jour',
      (tester) async {
        final profile = FakeProfileRepository()
          ..onUpdateProfile = () async => AppUser.fromJson(<String, dynamic>{
            'id': 'u1',
            'email': 'awa@example.sn',
            'username': 'awa',
            'full_name': 'Awa Sow',
          });
        final env = await pumpScreen(
          tester,
          const EditProfilePage(),
          profile: profile,
          authenticated: true,
        );

        await tester.enterText(fieldByLabel('Nom complet'), 'Awa Sow');
        await tapVisible(
          tester,
          find.widgetWithText(FilledButton, 'Enregistrer'),
        );

        expect(env.profile.lastUpdate, <String, String>{
          'full_name': 'Awa Sow',
        });
        expect(find.text('Profil mis à jour.'), findsOneWidget);
        final session = env.container.read(sessionControllerProvider);
        expect((session as SessionAuthenticated).user.fullName, 'Awa Sow');
      },
    );

    testWidgets('changer d\'email demande le mot de passe actuel', (
      tester,
    ) async {
      final env = await pumpScreen(tester, const EditProfilePage());
      expect(fieldByLabel('Mot de passe actuel'), findsNothing);

      await tester.enterText(
        fieldByLabel('Adresse email'),
        'nouveau@example.sn',
      );
      await tester.pump();
      expect(fieldByLabel('Mot de passe actuel'), findsOneWidget);

      await tapVisible(
        tester,
        find.widgetWithText(FilledButton, 'Enregistrer'),
      );
      expect(find.text('Saisissez votre mot de passe actuel.'), findsOneWidget);
      expect(env.profile.lastUpdate, isNull);

      await tester.enterText(fieldByLabel('Mot de passe actuel'), 'Secret123');
      await tapVisible(
        tester,
        find.widgetWithText(FilledButton, 'Enregistrer'),
      );
      expect(env.profile.lastUpdate, <String, String>{
        'email': 'nouveau@example.sn',
        'current_password': 'Secret123',
      });
    });

    testWidgets('erreur du serveur sur un champ : affichée sous ce champ', (
      tester,
    ) async {
      final profile = FakeProfileRepository()
        ..onUpdateProfile = () async =>
            throw ApiError.fromResponse(422, <String, dynamic>{
              'message': 'invalide',
              'errors': <String, dynamic>{
                'username': <String>["Ce nom d'utilisateur est déjà pris."],
              },
            });
      await pumpScreen(tester, const EditProfilePage(), profile: profile);

      await tester.enterText(fieldByLabel("Nom d'utilisateur"), 'fatou');
      await tapVisible(
        tester,
        find.widgetWithText(FilledButton, 'Enregistrer'),
      );
      expect(find.text("Ce nom d'utilisateur est déjà pris."), findsOneWidget);
    });

    testWidgets('téléphone : 9 chiffres exigés puis envoi avec l\'indicatif', (
      tester,
    ) async {
      final env = await pumpScreen(tester, const EditProfilePage());

      await tester.enterText(fieldByLabel('Numéro'), '12345');
      await tapVisible(
        tester,
        find.widgetWithText(FilledButton, 'Enregistrer le numéro'),
      );
      expect(find.text('Saisissez les 9 chiffres du numéro.'), findsOneWidget);
      expect(env.profile.phoneUpdated, isFalse);

      await tester.enterText(fieldByLabel('Numéro'), '771234567');
      await tapVisible(
        tester,
        find.widgetWithText(FilledButton, 'Enregistrer le numéro'),
      );
      expect(env.profile.lastPhone, '+221771234567');
      expect(find.text('Numéro enregistré.'), findsOneWidget);
    });

    testWidgets('téléphone : suppression du numéro', (tester) async {
      final profile = FakeProfileRepository()
        ..onMyProfile = () async => fullUser(phone: '+221771234567');
      final env = await pumpScreen(
        tester,
        const EditProfilePage(),
        profile: profile,
      );
      expect(find.text('771234567'), findsOneWidget);

      await tapVisible(
        tester,
        find.widgetWithText(TextButton, 'Supprimer mon numéro'),
      );
      expect(env.profile.phoneUpdated, isTrue);
      expect(env.profile.lastPhone, isNull);
      expect(find.text('Numéro supprimé.'), findsOneWidget);
    });
  });

  group('SellerProfilePage', () {
    testWidgets('affiche le vendeur et ses annonces', (tester) async {
      final profile = FakeProfileRepository()
        ..onSellerProducts = (username, page) async =>
            pageOf<ProductCard>(<ProductCard>[sampleCard(title: 'Robe wax')]);
      await pumpScreen(
        tester,
        const SellerProfilePage(username: 'fatou'),
        profile: profile,
      );

      expect(find.text('Fatou Sow'), findsOneWidget);
      expect(find.text('3 annonces'), findsOneWidget);
      expect(find.text('10 abonnés'), findsOneWidget);
      expect(find.text('Robe wax'), findsOneWidget);
    });

    testWidgets('s\'abonner : état et compteur mis à jour', (tester) async {
      final env = await pumpScreen(
        tester,
        const SellerProfilePage(username: 'fatou'),
      );

      await tester.tap(find.text("S'abonner"));
      await tester.pumpAndSettle();

      expect(env.profile.followed, <String>['seller-1']);
      expect(find.text('Abonné'), findsOneWidget);
      expect(find.text('11 abonnés'), findsOneWidget);

      await tester.tap(find.text('Abonné'));
      await tester.pumpAndSettle();
      expect(env.profile.unfollowed, <String>['seller-1']);
      expect(find.text("S'abonner"), findsOneWidget);
    });

    testWidgets('abonnements indisponibles : le bouton est masqué', (
      tester,
    ) async {
      final profile = FakeProfileRepository()
        ..onFollow = (id) async =>
            throw ApiError.fromResponse(404, <String, dynamic>{'message': ''});
      await pumpScreen(
        tester,
        const SellerProfilePage(username: 'fatou'),
        profile: profile,
      );

      await tester.tap(find.text("S'abonner"));
      await tester.pumpAndSettle();
      expect(find.text("S'abonner"), findsNothing);
    });

    testWidgets('mon propre profil : ni abonnement ni signalement', (
      tester,
    ) async {
      final profile = FakeProfileRepository()
        ..onPublicProfile = (username) async =>
            samplePublicProfile(id: 'u1', username: username);
      await pumpScreen(
        tester,
        const SellerProfilePage(username: 'awa'),
        profile: profile,
        authenticated: true,
      );
      expect(find.text('Fatou Sow'), findsOneWidget);
      expect(find.text("S'abonner"), findsNothing);
      expect(find.byType(PopupMenuButton<String>), findsNothing);
    });

    testWidgets('signaler le profil', (tester) async {
      final env = await pumpScreen(
        tester,
        const SellerProfilePage(username: 'fatou'),
      );

      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Signaler ce profil').last);
      await tester.pumpAndSettle();

      await tester.tap(
        find.widgetWithText(FilledButton, 'Envoyer le signalement'),
      );
      await tester.pumpAndSettle();
      expect(find.text('Choisissez un motif.'), findsOneWidget);

      await tester.tap(find.text('Spam'));
      await tester.pump();
      await tester.tap(
        find.widgetWithText(FilledButton, 'Envoyer le signalement'),
      );
      await tester.pumpAndSettle();

      expect(env.safety.reportedUsers, <String>['seller-1']);
      expect(env.safety.lastUserReason, UserReportReason.spam);
      expect(
        find.text('Signalement envoyé. Notre équipe va examiner ce profil.'),
        findsOneWidget,
      );
    });

    testWidgets(
      'signalement déjà en cours : message du serveur dans la feuille',
      (tester) async {
        final safety = FakeSafetyRepository()
          ..onReportUser = () async => throw ApiError.fromResponse(409, <
            String,
            dynamic
          >{
            'message':
                'Vous avez déjà signalé cet utilisateur. Le signalement est en cours de traitement.',
          });
        await pumpScreen(
          tester,
          const SellerProfilePage(username: 'fatou'),
          safety: safety,
        );

        await tester.tap(find.byType(PopupMenuButton<String>));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Signaler ce profil').last);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Fraude'));
        await tester.pump();
        await tester.tap(
          find.widgetWithText(FilledButton, 'Envoyer le signalement'),
        );
        await tester.pumpAndSettle();

        expect(find.textContaining('déjà signalé'), findsOneWidget);
      },
    );

    testWidgets('bloquer : confirmation puis retour', (tester) async {
      final env = await pumpScreen(
        tester,
        const SellerProfilePage(username: 'fatou'),
      );

      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Bloquer cet utilisateur'));
      await tester.pumpAndSettle();
      expect(find.text('Bloquer Fatou Sow ?'), findsOneWidget);

      await tester.tap(find.widgetWithText(FilledButton, 'Bloquer'));
      await tester.pumpAndSettle();

      expect(env.safety.blocked, <String>['seller-1']);
      expect(find.text('RACINE'), findsOneWidget);
    });
  });

  group('MyProductsPage', () {
    Paginated<ProductCard> two() => pageOf<ProductCard>(<ProductCard>[
      sampleCard(id: 'a', slug: 'a', title: 'Robe wax', status: 'active'),
      sampleCard(id: 'b', slug: 'b', title: 'Sac cuir', status: 'draft'),
    ]);

    testWidgets('liste mes annonces avec leur statut', (tester) async {
      final products = FakeProductRepository()
        ..onMyProducts = (page) async => two();
      await pumpScreen(tester, const MyProductsPage(), products: products);
      expect(find.text('Robe wax'), findsOneWidget);
      expect(find.text('En ligne'), findsOneWidget);
      expect(find.text('Brouillon'), findsOneWidget);
    });

    testWidgets('suppression : confirmation puis retrait de la liste', (
      tester,
    ) async {
      final products = FakeProductRepository()
        ..onMyProducts = (page) async => two();
      await pumpScreen(tester, const MyProductsPage(), products: products);

      await tester.tap(find.byIcon(Icons.delete_outline).first);
      await tester.pumpAndSettle();
      expect(find.text('Supprimer cette annonce ?'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Supprimer'));
      await tester.pumpAndSettle();

      expect(products.deleted, <String>['a']);
      expect(find.text('Robe wax'), findsNothing);
      expect(find.text('Sac cuir'), findsOneWidget);
    });

    testWidgets('échec de suppression : l\'annonce reste, message affiché', (
      tester,
    ) async {
      final products = FakeProductRepository();
      products.onMyProducts = (page) async => two();
      products.onDeleteProduct = (id) async => throw ApiError.fromResponse(
        403,
        <String, dynamic>{'message': 'Non autorisé.'},
      );
      await pumpScreen(tester, const MyProductsPage(), products: products);

      await tester.tap(find.byIcon(Icons.delete_outline).first);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Supprimer'));
      await tester.pumpAndSettle();

      expect(find.text('Robe wax'), findsOneWidget);
      expect(find.text('Non autorisé.'), findsOneWidget);
    });

    testWidgets('aucune annonce', (tester) async {
      await pumpScreen(tester, const MyProductsPage());
      expect(
        find.text("Vous n'avez pas encore publié d'annonce."),
        findsOneWidget,
      );
    });

    test('libellés de statut', () {
      expect(productStatusLabel('draft'), 'Brouillon');
      expect(productStatusLabel('sold'), 'Vendu');
      expect(productStatusLabel(null), '');
    });
  });

  group('BlockedUsersPage', () {
    testWidgets('liste puis déblocage', (tester) async {
      var calls = 0;
      final safety = FakeSafetyRepository()
        ..onBlockedUsers = () async {
          calls++;
          return calls == 1
              ? <BlockedUser>[
                  const BlockedUser(id: 'b1', fullName: 'Moussa Ba'),
                ]
              : <BlockedUser>[];
        };
      await pumpScreen(tester, const BlockedUsersPage(), safety: safety);
      expect(find.text('Moussa Ba'), findsOneWidget);

      await tester.tap(find.text('Débloquer'));
      await tester.pumpAndSettle();

      expect(safety.unblocked, <String>['b1']);
      expect(find.text('Moussa Ba'), findsNothing);
      expect(find.text("Vous n'avez bloqué personne."), findsOneWidget);
    });
  });

  group('SupportPage', () {
    testWidgets('description obligatoire', (tester) async {
      final env = await pumpScreen(tester, const SupportPage());
      await tapVisible(tester, find.widgetWithText(FilledButton, 'Envoyer'));
      expect(find.text('Décrivez le problème.'), findsOneWidget);
      expect(env.safety.lastSupportCategory, isNull);
    });

    testWidgets('envoi : catégorie choisie, message de remerciement, retour', (
      tester,
    ) async {
      final env = await pumpScreen(tester, const SupportPage());

      await tester.tap(find.text('Une suggestion'));
      await tester.pump();
      await tester.enterText(
        find.byType(TextFormField),
        'Ajouter un mode sombre',
      );
      await tapVisible(tester, find.widgetWithText(FilledButton, 'Envoyer'));

      expect(env.safety.lastSupportCategory, SupportCategory.suggestion);
      expect(env.safety.lastSupportDescription, 'Ajouter un mode sombre');
      expect(
        find.text('Signalement reçu. Merci pour votre retour.'),
        findsOneWidget,
      );
      expect(find.text('RACINE'), findsOneWidget);
    });
  });

  group('SettingsPage', () {
    testWidgets('changement de mot de passe', (tester) async {
      final env = await pumpScreen(tester, const SettingsPage());

      await tester.enterText(fieldByLabel('Mot de passe actuel'), 'Ancien123');
      await tester.enterText(
        fieldByLabel('Nouveau mot de passe'),
        'Nouveau123',
      );
      await tester.enterText(
        fieldByLabel('Confirmer le nouveau mot de passe'),
        'Nouveau123',
      );
      await tapVisible(
        tester,
        find.widgetWithText(FilledButton, 'Changer le mot de passe'),
      );

      expect(env.auth.lastPasswordChange, <String, String>{
        'current': 'Ancien123',
        'new': 'Nouveau123',
        'confirmation': 'Nouveau123',
      });
      expect(find.text('Mot de passe modifié avec succès.'), findsOneWidget);
    });

    testWidgets('confirmation différente : refus local', (tester) async {
      final env = await pumpScreen(tester, const SettingsPage());

      await tester.enterText(fieldByLabel('Mot de passe actuel'), 'Ancien123');
      await tester.enterText(
        fieldByLabel('Nouveau mot de passe'),
        'Nouveau123',
      );
      await tester.enterText(
        fieldByLabel('Confirmer le nouveau mot de passe'),
        'Autre1234',
      );
      await tapVisible(
        tester,
        find.widgetWithText(FilledButton, 'Changer le mot de passe'),
      );

      expect(
        find.text('Les mots de passe ne correspondent pas.'),
        findsOneWidget,
      );
      expect(env.auth.lastPasswordChange, isNull);
    });

    testWidgets('mot de passe actuel incorrect : message du serveur', (
      tester,
    ) async {
      final auth = FakeAuthRepository()
        ..onChangePassword = () async => throw ApiError.fromResponse(
          422,
          <String, dynamic>{'message': 'Le mot de passe actuel est incorrect.'},
        );
      await pumpScreen(tester, const SettingsPage(), auth: auth);

      await tester.enterText(fieldByLabel('Mot de passe actuel'), 'Mauvais123');
      await tester.enterText(
        fieldByLabel('Nouveau mot de passe'),
        'Nouveau123',
      );
      await tester.enterText(
        fieldByLabel('Confirmer le nouveau mot de passe'),
        'Nouveau123',
      );
      await tapVisible(
        tester,
        find.widgetWithText(FilledButton, 'Changer le mot de passe'),
      );

      expect(
        find.text('Le mot de passe actuel est incorrect.'),
        findsOneWidget,
      );
    });

    testWidgets('suppression du compte : mot de passe exigé, session fermée', (
      tester,
    ) async {
      final env = await pumpScreen(
        tester,
        const SettingsPage(),
        authenticated: true,
      );

      await tapVisible(
        tester,
        find.widgetWithText(OutlinedButton, 'Supprimer mon compte'),
      );
      expect(find.text('Supprimer votre compte ?'), findsOneWidget);

      await tester.tap(
        find.widgetWithText(FilledButton, 'Supprimer définitivement'),
      );
      await tester.pumpAndSettle();
      expect(find.text('Saisissez votre mot de passe.'), findsOneWidget);
      expect(env.auth.lastDeletePassword, isNull);

      await tester.enterText(find.byType(TextFormField).last, 'Secret123');
      await tester.tap(
        find.widgetWithText(FilledButton, 'Supprimer définitivement'),
      );
      await tester.pumpAndSettle();

      expect(env.auth.lastDeletePassword, 'Secret123');
      final session = env.container.read(sessionControllerProvider);
      expect(session, isA<SessionUnauthenticated>());
      expect(
        (session as SessionUnauthenticated).reason,
        SessionEndReason.accountDeleted,
      );
    });

    testWidgets('suppression : mot de passe refusé, le compte reste ouvert', (
      tester,
    ) async {
      final auth = FakeAuthRepository()
        ..onDeleteAccount = () async =>
            throw ApiError.fromResponse(422, <String, dynamic>{
              'message': 'invalide',
              'errors': <String, dynamic>{
                'password': <String>['Mot de passe incorrect.'],
              },
            });
      final env = await pumpScreen(
        tester,
        const SettingsPage(),
        auth: auth,
        authenticated: true,
      );

      await tapVisible(
        tester,
        find.widgetWithText(OutlinedButton, 'Supprimer mon compte'),
      );
      await tester.enterText(find.byType(TextFormField).last, 'Mauvais123');
      await tester.tap(
        find.widgetWithText(FilledButton, 'Supprimer définitivement'),
      );
      await tester.pumpAndSettle();

      expect(find.text('Mot de passe incorrect.'), findsOneWidget);
      expect(
        env.container.read(sessionControllerProvider),
        isA<SessionAuthenticated>(),
      );
    });
  });

  group('AccountPage', () {
    testWidgets('accès aux écrans du compte', (tester) async {
      final env = await pumpScreen(
        tester,
        const AccountPage(),
        authenticated: true,
      );
      expect(find.text('Awa Diop'), findsOneWidget);

      for (final entry in <String, String>{
        'Notifications': notificationsPath,
        'Premium': premiumPath,
        'Classements': rankingsPath,
        'Modifier mon profil': editProfilePath,
        'Mes annonces': myProductsPath,
        'Utilisateurs bloqués': blockedUsersPath,
        'Signaler un problème': supportPath,
        'Paramètres': settingsPath,
      }.entries) {
        await tester.tap(find.text(entry.key));
        await tester.pumpAndSettle();
        expect(
          find.text('ROUTE ${entry.value}'),
          findsOneWidget,
          reason: entry.key,
        );
        env.router.pop();
        await tester.pumpAndSettle();
      }
    });

    testWidgets('déconnexion : demande de confirmation', (tester) async {
      final env = await pumpScreen(
        tester,
        const AccountPage(),
        authenticated: true,
      );

      await tester.tap(find.widgetWithText(ListTile, 'Se déconnecter'));
      await tester.pumpAndSettle();
      expect(find.text('Se déconnecter ?'), findsOneWidget);
      expect(env.auth.logoutCalls, 0);

      await tester.tap(find.widgetWithText(FilledButton, 'Se déconnecter'));
      await tester.pumpAndSettle();
      expect(env.auth.logoutCalls, 1);
      expect(
        env.container.read(sessionControllerProvider),
        isA<SessionUnauthenticated>(),
      );
    });

    testWidgets('annuler la déconnexion ne ferme pas la session', (
      tester,
    ) async {
      final env = await pumpScreen(
        tester,
        const AccountPage(),
        authenticated: true,
      );
      await tester.tap(find.widgetWithText(ListTile, 'Se déconnecter'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Annuler'));
      await tester.pumpAndSettle();
      expect(env.auth.logoutCalls, 0);
      expect(
        env.container.read(sessionControllerProvider),
        isA<SessionAuthenticated>(),
      );
    });
  });

  group('ProductDetailPage (vendeur et signalement)', () {
    testWidgets('toucher le vendeur ouvre son profil', (tester) async {
      await pumpScreen(tester, const ProductDetailPage(slug: 'robe-wax'));
      await tapVisible(tester, find.text('Fatou Sow'));
      expect(find.text('ROUTE /seller/fatou'), findsOneWidget);
    });

    testWidgets('signaler l\'annonce', (tester) async {
      final env = await pumpScreen(
        tester,
        const ProductDetailPage(slug: 'robe-wax'),
        authenticated: true,
      );

      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text("Signaler l'annonce"));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Fraude ou arnaque'));
      await tester.pump();
      await tester.enterText(find.byType(TextField), 'Prix trop bas, suspect');
      await tester.tap(
        find.widgetWithText(FilledButton, 'Envoyer le signalement'),
      );
      await tester.pumpAndSettle();

      expect(env.safety.reportedProducts, <String>['p1']);
      expect(env.safety.lastProductReason, ProductReportReason.fraud);
      expect(env.safety.lastDescription, 'Prix trop bas, suspect');
      expect(
        find.text('Signalement envoyé. Merci pour votre vigilance.'),
        findsOneWidget,
      );
    });
  });
}
