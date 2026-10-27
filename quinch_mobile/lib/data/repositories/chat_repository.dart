import 'package:dio/dio.dart';

import '../../core/json/json_utils.dart';
import '../../core/media/chat_attachment.dart';
import '../../core/network/api_client.dart';
import '../../core/network/api_error.dart';
import '../api/endpoints.dart';
import '../models/chat.dart';
import '../models/paginated.dart';

/// Messagerie (texte). Aucune route de temps réel n'existe côté serveur : les
/// nouveaux messages s'obtiennent par `messages/since`.
class ChatRepository {
  ChatRepository(this._api);

  final ApiClient _api;

  /// Longueur maximale d'un message envoyé (`max:2000` côté serveur).
  static const maxMessageLength = 2000;

  /// Longueur maximale du message de premier contact (`max:1000`).
  static const maxFirstMessageLength = 1000;

  /// `GET conversations` : 20 par page, de la plus récente à la plus ancienne.
  Future<Paginated<Conversation>> conversations({int page = 1}) async =>
      Paginated<Conversation>.fromJson(
        await _api.get(Endpoints.conversations, query: {'page': page}),
        Conversation.fromJson,
      );

  /// `GET conversations/{id}` : derniers messages ; le serveur marque comme lus
  /// les messages reçus.
  Future<ConversationDetail> conversation(String id) async =>
      ConversationDetail.fromJson(await _api.get(Endpoints.conversation(id)));

  /// `GET conversations/{id}/messages/since?after=` : messages créés après
  /// l'horodatage donné (sans `after`, les 50 derniers).
  Future<NewMessages> messagesSince(String id, {String? after}) async =>
      NewMessages.fromJson(
        await _api.get(
          Endpoints.conversationSince(id),
          query: {if (after != null) 'after': after},
        ),
      );

  /// `POST conversations/{id}/messages` : envoie un message texte.
  /// 403 « Cet utilisateur n'est pas joignable. » si l'un a bloqué l'autre.
  Future<ChatMessage> sendMessage(String id, String body) async {
    final response = await _api.post(
      Endpoints.conversationMessages(id),
      data: <String, Object>{'body': body},
    );
    return ChatMessage.fromJson(asMap(response)['message']);
  }

  /// `POST conversations/{id}/file` (multipart, champ `file`, 20 Mo maximum).
  /// Les images sont toujours acceptées ; une vidéo exige `chat_file` (403
  /// « sera bientôt disponible » sinon).
  Future<ChatMessage> sendFile(
    String id,
    ChatAttachment file, {
    void Function(double progress)? onProgress,
  }) async {
    final form = FormData();
    form.files.add(
      MapEntry<String, MultipartFile>(
        'file',
        await MultipartFile.fromFile(file.path, filename: file.name),
      ),
    );
    final response = await _api.post(
      Endpoints.conversationFile(id),
      data: form,
      options: Options(
        sendTimeout: const Duration(minutes: 5),
        receiveTimeout: const Duration(minutes: 2),
      ),
      onSendProgress: (sent, total) {
        if (total > 0) {
          onProgress?.call(sent / total);
        }
      },
    );
    return ChatMessage.fromJson(asMap(response)['message']);
  }

  /// `DELETE conversations/{id}/messages/{messageId}` : supprime un de SES
  /// messages, pour tous les participants (403 « Vous ne pouvez supprimer que
  /// vos propres messages. » sinon).
  Future<void> deleteMessage(String conversationId, String messageId) async {
    await _api.delete(Endpoints.conversationMessage(conversationId, messageId));
  }

  /// `DELETE conversations/{id}` : supprime la conversation et tous ses messages,
  /// pour les deux participants (le serveur n'a pas de « supprimer pour moi »).
  Future<void> deleteConversation(String id) async {
    await _api.delete(Endpoints.conversation(id));
  }

  /// `POST conversations/bulk-delete` (`conversation_ids`) : supprime plusieurs
  /// conversations, pour tous leurs participants. Renvoie les identifiants
  /// réellement supprimés (le serveur ignore celles dont on n'est pas
  /// participant).
  Future<List<String>> deleteConversations(List<String> ids) async {
    final response = await _api.post(
      Endpoints.conversationsBulkDelete,
      data: <String, Object>{'conversation_ids': ids},
    );
    return asStringList(asMap(response)['deleted']);
  }

  /// `POST conversations/start` : ouvre (ou retrouve) la conversation avec un
  /// vendeur et y poste le premier message, lié à l'annonce si elle est donnée.
  /// Renvoie l'identifiant de la conversation.
  Future<String> start({
    required String sellerId,
    required String message,
    String? productId,
  }) async {
    final response = await _api.post(
      Endpoints.conversationStart,
      data: <String, Object>{
        'seller_id': sellerId,
        'message': message,
        if (productId != null) 'product_id': productId,
      },
    );
    final id = asString(asMap(asMap(response)['conversation'])['id']);
    if (id.isEmpty) {
      throw const ApiError(kind: ApiErrorKind.unknown);
    }
    return id;
  }
}
