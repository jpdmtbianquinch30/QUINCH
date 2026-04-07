import 'package:flutter/foundation.dart' show ChangeNotifier, debugPrint;
import '../models/conversation.dart';
import '../models/message.dart';
import '../services/chat_service.dart';

class ChatProvider extends ChangeNotifier {
  final ChatService _chatService;

  List<Conversation> _conversations = [];
  final Map<String, List<Message>> _messages = {};
  Conversation? _currentConversation;
  bool _isLoading = false;
  bool _isSending = false;

  /// Store the current user ID so we can compute isMe on messages.
  String _currentUserId = '';

  ChatProvider(this._chatService);

  List<Conversation> get conversations => _conversations;
  Map<String, List<Message>> get messages => _messages;
  Conversation? get currentConversation => _currentConversation;
  bool get isLoading => _isLoading;
  bool get isSending => _isSending;

  int get unreadTotal =>
      _conversations.fold(0, (sum, c) => sum + c.unreadCount);

  /// Set the current user ID (call after login / on app start).
  void setCurrentUserId(String userId) {
    _currentUserId = userId;
    debugPrint('[ChatProvider] currentUserId set to: $_currentUserId');
  }

  Future<void> loadConversations() async {
    _isLoading = true;
    notifyListeners();

    try {
      _conversations = await _chatService.getConversations();
      debugPrint('[ChatProvider] Loaded ${_conversations.length} conversations');
    } catch (e) {
      debugPrint('[ChatProvider] Error loading conversations: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Load messages for a conversation.
  Future<void> loadMessages(dynamic conversationId) async {
    final key = conversationId.toString();
    // Only show loading indicator on first load (no messages yet)
    final isFirstLoad = _messages[key] == null || _messages[key]!.isEmpty;
    if (isFirstLoad) {
      _isLoading = true;
      notifyListeners();
    }

    try {
      final data = await _chatService.getConversation(key);
      debugPrint('[ChatProvider] Raw response keys: ${data.keys}');

      // The backend returns { conversation: { ..., messages: [...] } }
      final convData = data['conversation'] ?? data;
      debugPrint('[ChatProvider] convData type: ${convData.runtimeType}');

      if (convData is Map<String, dynamic>) {
        debugPrint('[ChatProvider] convData keys: ${convData.keys}');
        debugPrint('[ChatProvider] buyer_id=${convData['buyer_id']}, seller_id=${convData['seller_id']}');
        debugPrint('[ChatProvider] buyer=${convData['buyer']?.runtimeType}, seller=${convData['seller']?.runtimeType}');
        debugPrint('[ChatProvider] messages type=${convData['messages']?.runtimeType}, length=${(convData['messages'] is List) ? (convData['messages'] as List).length : 'N/A'}');

        _currentConversation = Conversation.fromJson(convData);
        debugPrint('[ChatProvider] Parsed conversation: id=${_currentConversation?.id}, buyerId=${_currentConversation?.buyerId}, sellerId=${_currentConversation?.sellerId}');
        debugPrint('[ChatProvider] buyer name=${_currentConversation?.buyer?.fullName}, seller name=${_currentConversation?.seller?.fullName}');
        debugPrint('[ChatProvider] otherUser (for $_currentUserId) = ${_currentConversation?.getOtherUser(_currentUserId)?.fullName}');
      }

      // Extract messages from the response
      List<dynamic> msgList = [];
      if (convData is Map<String, dynamic> && convData['messages'] is List) {
        msgList = convData['messages'];
      } else if (data['messages'] is List) {
        msgList = data['messages'];
      } else if (data['messages'] is Map && data['messages']['data'] is List) {
        msgList = data['messages']['data'];
      }
      debugPrint('[ChatProvider] msgList length: ${msgList.length}');

      _messages[key] = msgList
          .map((e) {
            try {
              if (e is! Map<String, dynamic>) return null;
              final msg = Message.fromJson(e);
              // CRITICAL: compute isMe from sender_id vs current user ID
              msg.isMe = _isMessageMine(msg.senderId);
              return msg;
            } catch (err) {
              debugPrint('[ChatProvider] Error parsing message: $err');
              return null;
            }
          })
          .whereType<Message>()
          .toList();

      debugPrint('[ChatProvider] Loaded ${_messages[key]?.length ?? 0} messages for conv $key (userId=$_currentUserId)');
    } catch (e) {
      debugPrint('[ChatProvider] Error loading messages: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Determine if a message was sent by the current user.
  /// The frontend does: msg.sender_id === this.auth.user()?.id
  bool _isMessageMine(String senderId) {
    if (_currentUserId.isEmpty) return false;
    // Compare as strings (both are toString()'d from JSON)
    return senderId == _currentUserId;
  }

  /// Mark as read is done automatically by the show() endpoint on the backend
  /// when we load messages. Just reload conversations to update unread counts.
  Future<void> markConversationRead(dynamic conversationId) async {
    await loadConversations();
  }

  Future<String?> startConversation({
    required String sellerId,
    String? productId,
    String? message,
  }) async {
    try {
      debugPrint('[ChatProvider] startConversation: sellerId=$sellerId, productId=$productId, userId=$_currentUserId');
      final data = await _chatService.startConversation(
        sellerId: sellerId,
        productId: productId,
        message: message,
      );
      debugPrint('[ChatProvider] startConversation response keys: ${data.keys}');

      final conv = data['conversation'];
      if (conv != null && conv is Map<String, dynamic>) {
        final id = conv['id']?.toString();
        debugPrint('[ChatProvider] Conversation started: id=$id');
        // Reload conversations list
        await loadConversations();
        return id;
      }
      debugPrint('[ChatProvider] No conversation in response. Full response: $data');
      return null;
    } catch (e) {
      debugPrint('[ChatProvider] Error starting conversation: $e');
      return null;
    }
  }

  Future<bool> sendMessage(String conversationId, String body) async {
    _isSending = true;
    notifyListeners();

    try {
      final message = await _chatService.sendMessage(conversationId, body);
      // Messages we send are ALWAYS ours
      message.isMe = true;
      final key = conversationId;
      _messages[key] ??= [];
      _messages[key]!.add(message);
      debugPrint('[ChatProvider] Message sent: id=${message.id}, body=$body');
      _isSending = false;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('[ChatProvider] Error sending message: $e');
      _isSending = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> sendImage(dynamic conversationId, String filePath) async {
    _isSending = true;
    notifyListeners();
    try {
      final message = await _chatService.sendMedia(
        conversationId.toString(),
        filePath,
        type: 'image',
      );
      // Messages we send are ALWAYS ours
      message.isMe = true;
      final key = conversationId.toString();
      _messages[key] ??= [];
      _messages[key]!.add(message);
      _isSending = false;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('[ChatProvider] Error sending image: $e');
      _isSending = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> deleteConversation(String id) async {
    try {
      await _chatService.deleteConversation(id);
      _conversations.removeWhere((c) => c.id == id);
      notifyListeners();
    } catch (e) {
      debugPrint('[ChatProvider] Error deleting conversation: $e');
    }
  }

  void clearCurrentConversation() {
    _currentConversation = null;
    notifyListeners();
  }
}
