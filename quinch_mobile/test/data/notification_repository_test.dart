import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quinch_mobile/core/config/app_config.dart';
import 'package:quinch_mobile/core/network/api_client.dart';
import 'package:quinch_mobile/core/network/auth_token_holder.dart';
import 'package:quinch_mobile/core/network/dio_factory.dart';
import 'package:quinch_mobile/data/models/notifications.dart';
import 'package:quinch_mobile/data/repositories/notification_repository.dart';

import '../support/fakes.dart';

// Paramètres et corps ENVOYÉS, et lecture de réponses simulées d'après le code
// du backend. Ils ne prouvent pas le comportement d'un vrai serveur.

void main() {
  late FakeAdapter adapter;
  late NotificationRepository repo;

  void build(Future<ResponseBody> Function(RequestOptions) handler) {
    adapter = FakeAdapter(handler);
    final config = AppConfig.parse(
      'https://api.quinch.sn/api/v1',
      allowInsecure: false,
    );
    final tokens = AuthTokenHolder();
    repo = NotificationRepository(
      ApiClient(
        dio: createDio(config: config, tokens: tokens, adapter: adapter),
        tokens: tokens,
      ),
    );
  }

  RequestOptions last() => adapter.requests.last;

  test('liste : onglet et page, enveloppe meta', () async {
    build(
      (o) async => jsonResponse(<String, dynamic>{
        'data': <Object?>[
          <String, dynamic>{
            'id': 'n1',
            'type': 'like',
            'title': 'T',
            'body': 'B',
            'is_read': false,
          },
        ],
        'meta': <String, dynamic>{
          'current_page': 1,
          'last_page': 3,
          'total': 70,
        },
        'counts': <String, dynamic>{'all': 4},
      }, 200),
    );
    final page = await repo.list(tab: NotificationTab.messages, page: 2);
    expect(last().uri.path, '/api/v1/notifications');
    expect(last().uri.queryParameters, <String, dynamic>{
      'tab': 'messages',
      'page': '2',
    });
    expect(page.items.single.title, 'T');
    expect(page.hasMore, isTrue);
  });

  test('valeurs d\'onglet : celles acceptées par le serveur', () {
    expect(NotificationTab.values.map((t) => t.value), <String>[
      'all',
      'interactions',
      'messages',
      'system',
    ]);
  });

  test('compteur de non lues', () async {
    build(
      (o) async => jsonResponse(<String, dynamic>{
        'count': 5,
        'tabs': <String, dynamic>{
          'interactions': 2,
          'messages': 1,
          'system': 2,
        },
      }, 200),
    );
    final counts = await repo.unreadCount();
    expect(last().uri.path, '/api/v1/notifications/unread-count');
    expect(counts.all, 5);
    expect(counts.messages, 1);
  });

  test('détail avec contestation possible et réponse de l\'équipe', () async {
    build(
      (o) async => jsonResponse(<String, dynamic>{
        'notification': <String, dynamic>{
          'id': 'n1',
          'title': 'T',
          'body': 'B',
        },
        'contest': <String, dynamic>{
          'type': 'message',
          'can_contest': true,
          'appeal': <String, dynamic>{
            'id': 'a1',
            'status': 'closed',
            'message': 'Ma réponse',
            'response': "Merci, c'est réglé.",
            'handled_at': '2026-10-19T10:00:00.000000Z',
          },
        },
      }, 200),
    );
    final detail = await repo.detail('n1');
    expect(last().uri.path, '/api/v1/notifications/n1');
    expect(detail.canContest, isTrue);
    expect(detail.isReply, isTrue);
    expect(detail.appeal?.isPending, isFalse);
    expect(detail.appeal?.response, "Merci, c'est réglé.");
    expect(detail.appeal?.handledAt, isNotNull);
  });

  test('détail sans contestation', () async {
    build(
      (o) async => jsonResponse(<String, dynamic>{
        'notification': <String, dynamic>{'id': 'n1'},
        'contest': null,
      }, 200),
    );
    final detail = await repo.detail('n1');
    expect(detail.hasContest, isFalse);
    expect(detail.appeal, isNull);
  });

  test('lire, tout lire, supprimer', () async {
    build((o) async => jsonResponse(<String, dynamic>{'message': 'ok'}, 200));
    await repo.markRead('n1');
    expect(last().method, 'POST');
    expect(last().uri.path, '/api/v1/notifications/n1/read');

    await repo.markAllRead(tab: NotificationTab.system);
    expect(last().method, 'POST');
    expect(last().uri.path, '/api/v1/notifications/read-all');
    expect(last().uri.queryParameters, <String, dynamic>{'tab': 'system'});

    await repo.delete('n1');
    expect(last().method, 'DELETE');
    expect(last().uri.path, '/api/v1/notifications/n1');
  });

  test('contestation : message nettoyé, réponse du serveur', () async {
    build(
      (o) async => jsonResponse(<String, dynamic>{
        'message': "Votre message a été envoyé à l'équipe.",
        'appeal': <String, dynamic>{'id': 'a1'},
      }, 201),
    );
    final message = await repo.contest(
      'n1',
      '  Je pense que c\'est une erreur  ',
    );
    expect(last().uri.path, '/api/v1/notifications/n1/contest');
    expect(last().data, <String, Object?>{
      'message': "Je pense que c'est une erreur",
    });
    expect(message, "Votre message a été envoyé à l'équipe.");
  });

  test(
    'préférences : lecture, puis envoi de la liste COMPLÈTE avec push inchangé',
    () async {
      build(
        (o) async => o.method == 'GET'
            ? jsonResponse(<String, dynamic>{
                'preferences': <Object?>[
                  <String, dynamic>{
                    'type': 'like',
                    'label': "Mentions « j'aime »",
                    'push_enabled': false,
                    'in_app_enabled': true,
                    'email_enabled': false,
                  },
                ],
              }, 200)
            : jsonResponse(<String, dynamic>{'message': 'ok'}, 200),
      );
      final prefs = await repo.preferences();
      expect(prefs.single.pushEnabled, isFalse);

      await repo.updatePreferences(<NotificationPreference>[
        prefs.single.copyWith(emailEnabled: true),
      ]);
      expect(last().method, 'PUT');
      expect(last().uri.path, '/api/v1/notifications/preferences');
      expect(last().data, <String, Object?>{
        'preferences': <Object?>[
          <String, dynamic>{
            'type': 'like',
            'push_enabled': false,
            'in_app_enabled': true,
            'email_enabled': true,
          },
        ],
      });
    },
  );

  test('modèles : copyWith d\'une notification', () {
    final n = sampleNotification(isRead: false);
    final read = n.copyWith(isRead: true);
    expect(read.isRead, isTrue);
    expect(read.title, n.title);
    expect(n.isRead, isFalse);
  });
}
