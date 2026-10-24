import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quinch_mobile/app/router.dart';
import 'package:quinch_mobile/core/network/api_error.dart';
import 'package:quinch_mobile/data/models/notifications.dart';
import 'package:quinch_mobile/data/repositories/notification_repository.dart';
import 'package:quinch_mobile/features/notifications/notification_detail_page.dart';
import 'package:quinch_mobile/features/notifications/notification_preferences_page.dart';
import 'package:quinch_mobile/features/notifications/notifications_page.dart';

import '../support/fakes.dart';
import '../support/pump.dart';

FakeNotificationRepository twoNotifications() {
  final repo = FakeNotificationRepository();
  repo.onList = (tab, page) async => pageOf<AppNotification>(<AppNotification>[
    sampleNotification(id: 'a', title: 'Fatou a aimé votre annonce'),
    sampleNotification(
      id: 'b',
      type: 'message',
      title: 'Nouveau message',
      isRead: true,
    ),
  ]);
  return repo;
}

void main() {
  group('NotificationsPage', () {
    testWidgets('liste les notifications, les non lues sont signalées', (
      tester,
    ) async {
      await pumpScreen(
        tester,
        const NotificationsPage(),
        notifications: twoNotifications(),
      );
      expect(find.text('Fatou a aimé votre annonce'), findsOneWidget);
      expect(find.text('Nouveau message'), findsOneWidget);
      expect(find.byIcon(Icons.circle), findsOneWidget); // pastille « non lue »
    });

    testWidgets('les onglets affichent le nombre de non lues', (tester) async {
      final repo = twoNotifications();
      repo.onUnreadCount = () async =>
          const NotificationCounts(all: 3, messages: 1);
      await pumpScreen(tester, const NotificationsPage(), notifications: repo);
      expect(find.text('Toutes (3)'), findsOneWidget);
      expect(find.text('Messages (1)'), findsOneWidget);
      expect(find.text('Système'), findsOneWidget);
    });

    testWidgets('changer d\'onglet charge l\'onglet choisi', (tester) async {
      final repo = twoNotifications();
      await pumpScreen(tester, const NotificationsPage(), notifications: repo);
      expect(repo.listedTabs, <NotificationTab>[NotificationTab.all]);

      await tester.tap(find.text('Messages'));
      await tester.pumpAndSettle();
      expect(repo.listedTabs.last, NotificationTab.messages);
    });

    testWidgets('toucher une notification non lue : marquée lue, puis détail', (
      tester,
    ) async {
      final repo = twoNotifications();
      await pumpScreen(tester, const NotificationsPage(), notifications: repo);

      await tester.tap(find.text('Fatou a aimé votre annonce'));
      await tester.pumpAndSettle();

      expect(repo.markedRead, <String>['a']);
      expect(find.text('ROUTE /notifications/a'), findsOneWidget);
    });

    testWidgets('toucher une notification déjà lue : pas d\'appel de lecture', (
      tester,
    ) async {
      final repo = twoNotifications();
      await pumpScreen(tester, const NotificationsPage(), notifications: repo);
      await tester.tap(find.text('Nouveau message'));
      await tester.pumpAndSettle();
      expect(repo.markedRead, isEmpty);
      expect(find.text('ROUTE /notifications/b'), findsOneWidget);
    });

    testWidgets('échec de la lecture : le détail s\'ouvre quand même', (
      tester,
    ) async {
      final repo = twoNotifications();
      repo.onMarkRead = (id) async => throw ApiError.network();
      await pumpScreen(tester, const NotificationsPage(), notifications: repo);
      await tester.tap(find.text('Fatou a aimé votre annonce'));
      await tester.pumpAndSettle();
      expect(find.text('ROUTE /notifications/a'), findsOneWidget);
    });

    testWidgets('supprimer une notification', (tester) async {
      final repo = twoNotifications();
      await pumpScreen(tester, const NotificationsPage(), notifications: repo);

      await tester.tap(find.byTooltip('Supprimer la notification').first);
      await tester.pumpAndSettle();

      expect(repo.deleted, <String>['a']);
      expect(find.text('Fatou a aimé votre annonce'), findsNothing);
      expect(find.text('Nouveau message'), findsOneWidget);
    });

    testWidgets(
      'échec de suppression : la notification reste, message affiché',
      (tester) async {
        final repo = twoNotifications();
        repo.onDelete = (id) async =>
            throw ApiError.fromResponse(500, <String, dynamic>{});
        await pumpScreen(
          tester,
          const NotificationsPage(),
          notifications: repo,
        );
        await tester.tap(find.byTooltip('Supprimer la notification').first);
        await tester.pumpAndSettle();
        expect(find.text('Fatou a aimé votre annonce'), findsOneWidget);
        expect(
          find.text(
            'Une erreur est survenue côté serveur. Réessayez plus tard.',
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets('tout marquer comme lu', (tester) async {
      final repo = twoNotifications();
      await pumpScreen(tester, const NotificationsPage(), notifications: repo);
      await tester.tap(find.byTooltip('Tout marquer comme lu'));
      await tester.pumpAndSettle();
      expect(repo.markedAll, <NotificationTab>[NotificationTab.all]);
      expect(repo.listedTabs.length, 2); // rechargement après l'action
    });

    testWidgets('aucune notification', (tester) async {
      await pumpScreen(tester, const NotificationsPage());
      expect(find.text('Aucune notification pour le moment.'), findsOneWidget);
    });

    testWidgets('erreur au chargement puis réessai', (tester) async {
      final repo = FakeNotificationRepository();
      repo.onList = (tab, page) async => throw ApiError.network();
      await pumpScreen(tester, const NotificationsPage(), notifications: repo);
      expect(
        find.text('Connexion impossible. Vérifiez votre réseau.'),
        findsOneWidget,
      );

      repo.onList = (tab, page) async => pageOf<AppNotification>(
        <AppNotification>[sampleNotification(title: 'Bienvenue')],
      );
      await tester.tap(find.text('Réessayer'));
      await tester.pumpAndSettle();
      expect(find.text('Bienvenue'), findsOneWidget);
    });

    test('icônes par type', () {
      expect(notificationIcon('like'), Icons.favorite_outline);
      expect(notificationIcon('message'), Icons.mail_outline);
      expect(notificationIcon('inconnu'), Icons.notifications_none);
    });
  });

  group('NotificationBell', () {
    Widget bellPage() =>
        Scaffold(appBar: AppBar(actions: const [NotificationBell()]));

    testWidgets('pastille du nombre de non lues', (tester) async {
      final repo = FakeNotificationRepository();
      repo.onUnreadCount = () async => const NotificationCounts(all: 3);
      await pumpScreen(tester, bellPage(), notifications: repo);
      expect(find.text('3'), findsOneWidget);
    });

    testWidgets('aucune pastille s\'il n\'y a rien de non lu', (tester) async {
      await pumpScreen(tester, bellPage());
      expect(find.text('0'), findsNothing);
    });

    testWidgets('plus de 99 : « 99+ »', (tester) async {
      final repo = FakeNotificationRepository();
      repo.onUnreadCount = () async => const NotificationCounts(all: 150);
      await pumpScreen(tester, bellPage(), notifications: repo);
      expect(find.text('99+'), findsOneWidget);
    });

    testWidgets('ouvre les notifications puis recompte au retour', (
      tester,
    ) async {
      final repo = FakeNotificationRepository();
      repo.onUnreadCount = () async => const NotificationCounts(all: 2);
      final env = await pumpScreen(tester, bellPage(), notifications: repo);
      final before = repo.unreadCalls;

      await tester.tap(find.byIcon(Icons.notifications_outlined));
      await tester.pumpAndSettle();
      expect(find.text('ROUTE $notificationsPath'), findsOneWidget);

      env.router.pop();
      await tester.pumpAndSettle();
      expect(repo.unreadCalls, greaterThan(before));
    });
  });

  group('NotificationDetailPage', () {
    testWidgets('titre, texte et bouton « Voir » vers une annonce', (
      tester,
    ) async {
      final repo = FakeNotificationRepository();
      repo.onDetail = (id) async => sampleNotificationDetail(
        id,
        actionUrl: '/product/robe-wax',
        title: 'Votre annonce est en ligne',
        body: 'Elle est visible par tous.',
      );
      await pumpScreen(
        tester,
        const NotificationDetailPage(id: 'n1'),
        notifications: repo,
      );

      expect(find.text('Votre annonce est en ligne'), findsOneWidget);
      expect(find.byType(SelectableText), findsOneWidget);
      await tapVisible(tester, find.text('Voir'));
      expect(find.text('ROUTE /product/robe-wax'), findsOneWidget);
    });

    testWidgets('adresse sans équivalent : pas de bouton « Voir »', (
      tester,
    ) async {
      final repo = FakeNotificationRepository();
      repo.onDetail = (id) async =>
          sampleNotificationDetail(id, actionUrl: '/messages?user=abc');
      await pumpScreen(
        tester,
        const NotificationDetailPage(id: 'n1'),
        notifications: repo,
      );
      expect(find.text('Voir'), findsNothing);
    });

    testWidgets('contester : message trop court refusé, puis envoi', (
      tester,
    ) async {
      final repo = FakeNotificationRepository();
      repo.onDetail = (id) async =>
          sampleNotificationDetail(id, canContest: true);
      await pumpScreen(
        tester,
        const NotificationDetailPage(id: 'n1'),
        notifications: repo,
      );

      await tapVisible(tester, find.text('Contester cette décision'));
      await tester.enterText(find.byType(TextField), 'court');
      await tester.tap(find.widgetWithText(FilledButton, 'Envoyer'));
      await tester.pumpAndSettle();
      expect(
        find.text('Expliquez votre démarche en au moins 10 caractères.'),
        findsOneWidget,
      );
      expect(repo.contested, isEmpty);

      repo.onDetail = (id) async => sampleNotificationDetail(
        id,
        canContest: false,
        appeal: <String, dynamic>{
          'id': 'a1',
          'status': 'pending',
          'message': 'Ce retrait est une erreur.',
        },
      );
      await tester.enterText(
        find.byType(TextField),
        'Ce retrait est une erreur.',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Envoyer'));
      await tester.pumpAndSettle();

      expect(repo.contested, <String, String>{
        'n1': 'Ce retrait est une erreur.',
      });
      expect(
        find.text("Votre message a été envoyé à l'équipe."),
        findsOneWidget,
      );
      expect(find.text('Votre contestation'), findsOneWidget);
      expect(find.text("Statut : En cours d'examen"), findsOneWidget);
      expect(find.text('Contester cette décision'), findsNothing);
    });

    testWidgets(
      'contestation déjà en cours (409) : message du serveur dans la fenêtre',
      (tester) async {
        final repo = FakeNotificationRepository();
        repo.onDetail = (id) async =>
            sampleNotificationDetail(id, canContest: true);
        repo.onContest = (id, message) async =>
            throw ApiError.fromResponse(409, <String, dynamic>{
              'message':
                  'Une contestation est déjà en cours pour cette décision.',
            });
        await pumpScreen(
          tester,
          const NotificationDetailPage(id: 'n1'),
          notifications: repo,
        );

        await tapVisible(tester, find.text('Contester cette décision'));
        await tester.enterText(
          find.byType(TextField),
          'Ce retrait est une erreur.',
        );
        await tester.tap(find.widgetWithText(FilledButton, 'Envoyer'));
        await tester.pumpAndSettle();

        expect(
          find.text('Une contestation est déjà en cours pour cette décision.'),
          findsOneWidget,
        );
      },
    );

    testWidgets('message de l\'équipe : bouton « Répondre »', (tester) async {
      final repo = FakeNotificationRepository();
      repo.onDetail = (id) async => sampleNotificationDetail(
        id,
        canContest: true,
        contestType: 'message',
      );
      await pumpScreen(
        tester,
        const NotificationDetailPage(id: 'n1'),
        notifications: repo,
      );
      expect(find.text('Répondre'), findsOneWidget);
      expect(find.text('Contester cette décision'), findsNothing);
    });

    testWidgets('contestation traitée : réponse de l\'équipe affichée', (
      tester,
    ) async {
      final repo = FakeNotificationRepository();
      repo.onDetail = (id) async => sampleNotificationDetail(
        id,
        appeal: <String, dynamic>{
          'id': 'a1',
          'status': 'accepted',
          'message': 'Ce retrait est une erreur.',
          'response': 'Votre vidéo a été rétablie.',
          'handled_at': '2026-10-19T10:00:00.000000Z',
        },
      );
      await pumpScreen(
        tester,
        const NotificationDetailPage(id: 'n1'),
        notifications: repo,
      );

      expect(find.text('Statut : Traitée'), findsOneWidget);
      expect(find.text("Réponse de l'équipe"), findsOneWidget);
      expect(find.byType(SelectableText), findsNWidgets(2)); // texte + réponse
    });

    testWidgets('notification introuvable : message d\'erreur', (tester) async {
      final repo = FakeNotificationRepository();
      repo.onDetail = (id) async =>
          throw ApiError.fromResponse(404, <String, dynamic>{'message': ''});
      await pumpScreen(
        tester,
        const NotificationDetailPage(id: 'x'),
        notifications: repo,
      );
      expect(find.text('Réessayer'), findsOneWidget);
    });
  });

  group('NotificationPreferencesPage', () {
    FakeNotificationRepository withPrefs() {
      final repo = FakeNotificationRepository();
      repo.onPreferences = () async => <NotificationPreference>[
        samplePreference(
          type: 'like',
          label: "Mentions « j'aime »",
          push: false,
        ),
        samplePreference(type: 'message', label: 'Messages', email: true),
      ];
      return repo;
    }

    testWidgets('affiche les types sans réglage « push »', (tester) async {
      await pumpScreen(
        tester,
        const NotificationPreferencesPage(),
        notifications: withPrefs(),
      );
      expect(find.text("Mentions « j'aime »"), findsOneWidget);
      expect(find.text('Messages'), findsOneWidget);
      expect(find.text("Dans l'application"), findsNWidgets(2));
      expect(find.text('Par email'), findsNWidgets(2));
      expect(find.textContaining('push', findRichText: true), findsNothing);
      expect(find.textContaining('Push'), findsNothing);
    });

    testWidgets('activer l\'email : liste complète envoyée, push conservé', (
      tester,
    ) async {
      final repo = withPrefs();
      await pumpScreen(
        tester,
        const NotificationPreferencesPage(),
        notifications: repo,
      );

      await tester.tap(
        find.byType(Switch).at(1),
      ); // « Par email » du premier type
      await tester.pumpAndSettle();

      final sent = repo.lastPreferences!;
      expect(sent, hasLength(2));
      expect(sent[0].emailEnabled, isTrue);
      expect(sent[0].pushEnabled, isFalse); // inchangé
      expect(
        sent[0].toPayload().keys,
        containsAll(<String>[
          'type',
          'push_enabled',
          'in_app_enabled',
          'email_enabled',
        ]),
      );
      expect(sent[1].emailEnabled, isTrue); // second type déjà activé, conservé
    });

    testWidgets(
      'échec de l\'enregistrement : réglage rétabli, message affiché',
      (tester) async {
        final repo = withPrefs();
        repo.onUpdatePreferences = (prefs) async => throw ApiError.network();
        await pumpScreen(
          tester,
          const NotificationPreferencesPage(),
          notifications: repo,
        );

        final before = tester.widget<Switch>(find.byType(Switch).at(1)).value;
        await tester.tap(find.byType(Switch).at(1));
        await tester.pumpAndSettle();

        expect(tester.widget<Switch>(find.byType(Switch).at(1)).value, before);
        expect(
          find.text('Connexion impossible. Vérifiez votre réseau.'),
          findsOneWidget,
        );
      },
    );

    testWidgets('aucune préférence', (tester) async {
      await pumpScreen(tester, const NotificationPreferencesPage());
      expect(find.text('Aucune préférence à régler.'), findsOneWidget);
    });
  });
}
