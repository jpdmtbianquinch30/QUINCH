import 'package:flutter_test/flutter_test.dart';
import 'package:quinch_mobile/core/config/app_config.dart';
import 'package:quinch_mobile/core/network/api_client.dart';
import 'package:quinch_mobile/core/network/api_error.dart';
import 'package:quinch_mobile/core/network/auth_token_holder.dart';
import 'package:quinch_mobile/core/network/dio_factory.dart';
import 'package:quinch_mobile/data/models/chat.dart';
import 'package:quinch_mobile/data/repositories/chat_repository.dart';
import 'package:quinch_mobile/features/chat/chat_format.dart';

import '../support/fakes.dart';

// Réponses simulées d'après `ConversationController` du backend : elles ne
// prouvent pas le comportement d'un vrai serveur.

void main() {
  group('Modèles', () {
    test(
      'Conversation : autre personne, annonce, dernier message, non lus',
      () {
        final c = Conversation.fromJson(<String, dynamic>{
          'id': 'c1',
          'unread_count': 3,
          'last_message_at': '2026-10-25T10:00:00.000000Z',
          'other_user': <String, dynamic>{
            'id': 'u2',
            'full_name': 'Fatou Sow',
            'username': 'fatou',
            'avatar_url': '/storage/a.jpg',
            'is_premium': true,
          },
          'product': <String, dynamic>{
            'id': 'p1',
            'title': 'Robe wax',
            'slug': 'robe-wax',
            'price': '15000.00',
          },
          'last_message': <String, dynamic>{
            'id': 'm9',
            'sender_id': 'u2',
            'body': 'Oui, disponible',
            'type': 'text',
            'created_at': '2026-10-25T10:00:00.000000Z',
          },
        });

        expect(c.id, 'c1');
        expect(c.unreadCount, 3);
        expect(c.otherUser?.fullName, 'Fatou Sow');
        expect(c.otherUser?.isPremium, isTrue);
        expect(c.product?.title, 'Robe wax');
        expect(c.product?.price, 15000);
        expect(c.lastMessage?.body, 'Oui, disponible');
        expect(c.lastMessageAt, isNotNull);
      },
    );

    test('Conversation sans annonce ni message : aucune exception', () {
      final c = Conversation.fromJson(<String, dynamic>{'id': 'c2'});
      expect(c.otherUser, isNull);
      expect(c.product, isNull);
      expect(c.lastMessage, isNull);
      expect(c.unreadCount, 0);
    });

    test('ChatMessage : type par défaut « text », horodatage conservé', () {
      final m = ChatMessage.fromJson(<String, dynamic>{
        'id': 'm1',
        'sender_id': 'u1',
        'body': 'Salut',
        'created_at': '2026-10-25T10:00:00.123456Z',
      });
      expect(m.isText, isTrue);
      expect(m.createdAtRaw, '2026-10-25T10:00:00.123456Z');
      expect(m.createdAt, isNotNull);
      expect(m.metadata, isEmpty);
    });

    test('message lié à une annonce : métadonnées lues', () {
      final m = ChatMessage.fromJson(<String, dynamic>{
        'id': 'm2',
        'sender_id': 'u1',
        'body': 'Toujours disponible ?',
        'type': 'product_tag',
        'metadata': <String, dynamic>{
          'product_title': 'Robe wax',
          'product_slug': 'robe-wax',
        },
      });
      expect(m.isProductTag, isTrue);
      expect(m.metadata['product_title'], 'Robe wax');
    });

    test('ConversationDetail et NewMessages', () {
      final detail = ConversationDetail.fromJson(<String, dynamic>{
        'conversation': <String, dynamic>{
          'id': 'c1',
          'other_user': <String, dynamic>{'id': 'u2', 'full_name': 'Fatou'},
          'messages': <Map<String, dynamic>>[
            <String, dynamic>{'id': 'a', 'body': '1'},
            <String, dynamic>{'id': 'b', 'body': '2'},
          ],
        },
      });
      expect(detail.messages.map((m) => m.id), <String>['a', 'b']);
      expect(detail.conversation.otherUser?.fullName, 'Fatou');

      final news = NewMessages.fromJson(<String, dynamic>{
        'messages': <Map<String, dynamic>>[
          <String, dynamic>{'id': 'c'},
        ],
        'other_user': <String, dynamic>{'id': 'u2', 'full_name': 'Fatou S.'},
      });
      expect(news.messages.single.id, 'c');
      expect(news.otherUser?.fullName, 'Fatou S.');
      expect(NewMessages.fromJson(null).messages, isEmpty);
    });
  });

  group('ChatRepository', () {
    late FakeAdapter adapter;

    ChatRepository build(Map<String, dynamic> body, [int status = 200]) {
      adapter = FakeAdapter((o) async => jsonResponse(body, status));
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

    test(
      'conversations : GET conversations?page=2, pagination Laravel',
      () async {
        final repo = build(<String, dynamic>{
          'data': <Map<String, dynamic>>[
            <String, dynamic>{'id': 'c1', 'unread_count': 1},
          ],
          'current_page': 2,
          'last_page': 3,
          'total': 41,
          'per_page': 20,
        });

        final page = await repo.conversations(page: 2);

        final request = adapter.requests.single;
        expect(request.method, 'GET');
        expect(request.uri.path, '/api/v1/conversations');
        expect(request.uri.queryParameters['page'], '2');
        expect(page.items.single.unreadCount, 1);
        expect(page.hasMore, isTrue);
      },
    );

    test('conversation : GET conversations/{id}', () async {
      final repo = build(<String, dynamic>{
        'conversation': <String, dynamic>{
          'id': 'c1',
          'messages': <Map<String, dynamic>>[
            <String, dynamic>{'id': 'm1', 'body': 'Salut'},
          ],
        },
      });

      final detail = await repo.conversation('c1');

      expect(adapter.requests.single.uri.path, '/api/v1/conversations/c1');
      expect(detail.messages.single.body, 'Salut');
    });

    test(
      'messagesSince : paramètre after transmis tel quel, ou absent',
      () async {
        final repo = build(<String, dynamic>{'messages': <Object>[]});

        await repo.messagesSince('c1', after: '2026-10-25T10:00:00.123456Z');
        await repo.messagesSince('c1');

        expect(
          adapter.requests.first.uri.path,
          '/api/v1/conversations/c1/messages/since',
        );
        expect(
          adapter.requests.first.uri.queryParameters['after'],
          '2026-10-25T10:00:00.123456Z',
        );
        expect(adapter.requests.last.uri.queryParameters, isEmpty);
      },
    );

    test(
      'sendMessage : POST messages avec « body », renvoie le message',
      () async {
        final repo = build(<String, dynamic>{
          'message': <String, dynamic>{
            'id': 'm5',
            'sender_id': 'u1',
            'body': 'Bonjour',
          },
        });

        final sent = await repo.sendMessage('c1', 'Bonjour');

        final request = adapter.requests.single;
        expect(request.method, 'POST');
        expect(request.uri.path, '/api/v1/conversations/c1/messages');
        expect(request.data, <String, Object>{'body': 'Bonjour'});
        expect(sent.id, 'm5');
      },
    );

    test(
      'start : POST conversations/start, annonce liée et identifiant',
      () async {
        final repo = build(<String, dynamic>{
          'conversation': <String, dynamic>{'id': 'c7'},
          'message': <String, dynamic>{'id': 'm1'},
        }, 201);

        final id = await repo.start(
          sellerId: 's1',
          productId: 'p1',
          message: 'Bonjour',
        );

        final request = adapter.requests.single;
        expect(request.method, 'POST');
        expect(request.uri.path, '/api/v1/conversations/start');
        expect(request.data, <String, Object>{
          'seller_id': 's1',
          'message': 'Bonjour',
          'product_id': 'p1',
        });
        expect(id, 'c7');
      },
    );

    test('start sans annonce : pas de product_id', () async {
      final repo = build(<String, dynamic>{
        'conversation': <String, dynamic>{'id': 'c7'},
      }, 201);

      await repo.start(sellerId: 's1', message: 'Bonjour');

      expect(
        (adapter.requests.single.data as Map).containsKey('product_id'),
        isFalse,
      );
    });

    test('start : réponse sans identifiant de conversation → erreur', () async {
      final repo = build(<String, dynamic>{}, 201);

      await expectLater(
        repo.start(sellerId: 's1', message: 'Bonjour'),
        throwsA(isA<ApiError>()),
      );
    });

    test('utilisateur bloqué : 403 avec le message du serveur', () async {
      final repo = build(<String, dynamic>{
        'message': "Cet utilisateur n'est pas joignable.",
      }, 403);

      await expectLater(
        repo.sendMessage('c1', 'Salut'),
        throwsA(
          isA<ApiError>()
              .having((e) => e.statusCode, 'statusCode', 403)
              .having(
                (e) => e.userMessage,
                'userMessage',
                "Cet utilisateur n'est pas joignable.",
              ),
        ),
      );
    });

    test('limites de longueur : 2000 et 1000 caractères', () {
      expect(ChatRepository.maxMessageLength, 2000);
      expect(ChatRepository.maxFirstMessageLength, 1000);
    });
  });

  group('Formatage', () {
    final now = DateTime(2026, 10, 25, 15, 30);

    test('heure du message : aujourd\'hui, hier, plus ancien', () {
      expect(
        formatMessageTime(DateTime(2026, 10, 25, 9, 5), now: now),
        '09:05',
      );
      expect(
        formatMessageTime(DateTime(2026, 10, 24, 23, 59), now: now),
        'Hier 23:59',
      );
      expect(
        formatMessageTime(DateTime(2026, 10, 1, 8, 0), now: now),
        '01/10/2026',
      );
      expect(formatMessageTime(null, now: now), '');
    });

    test('boîte de réception : heure, « Hier » ou date', () {
      expect(formatInboxTime(DateTime(2026, 10, 25, 7, 3), now: now), '07:03');
      expect(formatInboxTime(DateTime(2026, 10, 24, 20, 0), now: now), 'Hier');
      expect(formatInboxTime(DateTime(2026, 9, 3), now: now), '03/09/2026');
    });

    test('aperçu selon le type de message', () {
      expect(messagePreview(null), 'Aucun message');
      expect(messagePreview(sampleMessage(body: 'Salut')), 'Salut');
      expect(messagePreview(sampleMessage(type: 'image', body: '')), 'Photo');
      expect(messagePreview(sampleMessage(type: 'video', body: '')), 'Vidéo');
      expect(messagePreview(sampleMessage(type: 'file', body: '')), 'Fichier');
      expect(
        messagePreview(sampleMessage(type: 'audio', body: '')),
        unsupportedMessageText,
      );
    });
  });
}
