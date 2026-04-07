import 'package:dio/dio.dart';
import '../models/conversation.dart';
import '../models/message.dart';
import 'api_service.dart';

class ChatService {
  final ApiService _api;

  ChatService(this._api);

  Future<List<Conversation>> getConversations() async {
    final response = await _api.get('/conversations');
    final data = response.data;
    // Backend returns paginated data: { data: [...], current_page: ..., ... }
    final list = data['data'] ?? data['conversations'] ?? [];
    return (list as List).map((e) {
      try {
        return Conversation.fromJson(e is Map<String, dynamic> ? e : {});
      } catch (_) {
        return null;
      }
    }).whereType<Conversation>().toList();
  }

  Future<Map<String, dynamic>> startConversation({
    required String sellerId,
    String? productId,
    String? message,
  }) async {
    final data = <String, dynamic>{
      'seller_id': sellerId,
    };
    if (message != null && message.isNotEmpty) {
      data['message'] = message;
    }
    // Only include product_id if it's a valid value
    if (productId != null && productId.isNotEmpty) {
      data['product_id'] = productId;
    }
    final response = await _api.post('/conversations/start', data: data);
    return response.data;
  }

  Future<Map<String, dynamic>> getConversation(String id) async {
    final response = await _api.get('/conversations/$id');
    return response.data;
  }

  Future<Message> sendMessage(String conversationId, String body) async {
    final response =
        await _api.post('/conversations/$conversationId/messages', data: {
      'body': body,
    });
    return Message.fromJson(response.data['message'] ?? response.data);
  }

  Future<Message> sendAudio(String conversationId, FormData data) async {
    final response = await _api.upload(
      '/conversations/$conversationId/audio',
      data: data,
    );
    return Message.fromJson(response.data['message'] ?? response.data);
  }

  Future<Message> sendFile(String conversationId, FormData data) async {
    final response = await _api.upload(
      '/conversations/$conversationId/file',
      data: data,
    );
    return Message.fromJson(response.data['message'] ?? response.data);
  }

  // Note: marking as read is done by the GET /conversations/{id} endpoint automatically
  // No separate endpoint needed

  Future<Message> sendMedia(String conversationId, String filePath, {String type = 'image'}) async {
    final data = FormData.fromMap({
      'file': await MultipartFile.fromFile(filePath),
      'type': type,
    });
    final response = await _api.upload(
      '/conversations/$conversationId/file',
      data: data,
    );
    return Message.fromJson(response.data['message'] ?? response.data);
  }

  Future<void> deleteConversation(String id) async {
    await _api.delete('/conversations/$id');
  }
}
