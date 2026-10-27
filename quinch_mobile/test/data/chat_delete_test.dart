import 'package:flutter_test/flutter_test.dart';
import 'package:quinch_mobile/core/config/app_config.dart';
import 'package:quinch_mobile/core/network/api_client.dart';
import 'package:quinch_mobile/core/network/api_error.dart';
import 'package:quinch_mobile/core/network/auth_token_holder.dart';
import 'package:quinch_mobile/core/network/dio_factory.dart';
import 'package:quinch_mobile/data/repositories/chat_repository.dart';
import 'package:quinch_mobile/features/chat/chat_format.dart';

import '../support/fakes.dart';

// Réponses simulées d'après `ConversationController` (deleteMessage, destroy,
// bulkDestroy) : elles ne prouvent pas le comportement d'un vrai serveur.

void main() {
  group('ChatRepository — suppressions', () {
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
      'deleteMessage : DELETE conversations/{id}/messages/{messageId}',
      () async {
        final repo = build(<String, dynamic>{'message': 'Message supprimé.'});

        await repo.deleteMessage('c1', 'm7');

        final request = adapter.requests.single;
        expect(request.method, 'DELETE');
        expect(request.uri.path, '/api/v1/conversations/c1/messages/m7');
      },
    );

    test('deleteMessage : message d\'un autre → 403 du serveur', () async {
      final repo = build(<String, dynamic>{
        'message': 'Vous ne pouvez supprimer que vos propres messages.',
      }, 403);

      await expectLater(
        repo.deleteMessage('c1', 'm7'),
        throwsA(
          isA<ApiError>()
              .having((e) => e.statusCode, 'statusCode', 403)
              .having(
                (e) => e.userMessage,
                'userMessage',
                'Vous ne pouvez supprimer que vos propres messages.',
              ),
        ),
      );
    });

    test('deleteConversation : DELETE conversations/{id}', () async {
      final repo = build(<String, dynamic>{
        'message': 'Conversation supprimée.',
      });

      await repo.deleteConversation('c1');

      final request = adapter.requests.single;
      expect(request.method, 'DELETE');
      expect(request.uri.path, '/api/v1/conversations/c1');
    });

    test(
      'deleteConversations : POST bulk-delete, identifiants réellement supprimés',
      () async {
        final repo = build(<String, dynamic>{
          'deleted': <String>['c1', 'c3'],
        });

        final deleted = await repo.deleteConversations(['c1', 'c2', 'c3']);

        final request = adapter.requests.single;
        expect(request.method, 'POST');
        expect(request.uri.path, '/api/v1/conversations/bulk-delete');
        expect(request.data, <String, Object>{
          'conversation_ids': <String>['c1', 'c2', 'c3'],
        });
        expect(deleted, ['c1', 'c3']);
      },
    );

    test(
      'deleteConversations : réponse sans liste → aucune suppression confirmée',
      () async {
        final repo = build(<String, dynamic>{});

        expect(await repo.deleteConversations(['c1']), isEmpty);
      },
    );
  });

  group('Avertissements de suppression', () {
    test('le texte dit que l\'autre personne perd aussi le contenu', () {
      expect(deleteMessageWarning, contains("pour l'autre personne"));
      expect(deleteConversationWarning, contains("pour l'autre personne"));
      expect(
        deleteConversationsWarning(1),
        contains('cette conversation seront supprimés'),
      );
      expect(deleteConversationsWarning(3), contains('ces 3 conversations'));
      expect(deleteConversationsWarning(3), contains('autres participants'));
    });
  });
}
