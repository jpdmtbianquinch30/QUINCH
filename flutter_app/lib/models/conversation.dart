import 'package:flutter/foundation.dart' show debugPrint;
import 'message.dart';
import 'product.dart';

class Conversation {
  final String id;
  final String buyerId;
  final String sellerId;
  final String? productId;
  final String status;
  final String? lastMessageAt;
  final ConversationParticipant? buyer;
  final ConversationParticipant? seller;
  final ConversationParticipant? otherUserData;
  final Product? product;
  final Message? lastMessage;
  final List<Message> messages;
  final int unreadCount;

  Conversation({
    required this.id,
    required this.buyerId,
    required this.sellerId,
    this.productId,
    this.status = 'active',
    this.lastMessageAt,
    this.buyer,
    this.seller,
    this.otherUserData,
    this.product,
    this.lastMessage,
    this.messages = const [],
    this.unreadCount = 0,
  });

  /// Returns the other user — prefers backend-computed other_user,
  /// then falls back to seller or buyer.
  ConversationParticipant? get otherUser => otherUserData ?? seller ?? buyer;

  /// Returns the other user based on the current user's ID.
  /// This is the correct way: if I am the buyer, the other user is the seller, and vice versa.
  /// Same logic as Angular frontend: conv.buyer_id === userId ? conv.seller : conv.buyer
  ConversationParticipant? getOtherUser(String myUserId) {
    // If backend already computed other_user (from list endpoint), use it
    if (otherUserData != null) return otherUserData;
    // Otherwise compute it like the Angular frontend does
    if (buyerId == myUserId) return seller;
    if (sellerId == myUserId) return buyer;
    // Fallback
    return seller ?? buyer;
  }

  factory Conversation.fromJson(Map<String, dynamic> json) {
    // Parse messages list if embedded in conversation
    List<Message> msgList = [];
    if (json['messages'] != null && json['messages'] is List) {
      msgList = (json['messages'] as List)
          .map((e) {
            try {
              if (e is! Map<String, dynamic>) return null;
              return Message.fromJson(e);
            } catch (err) {
              debugPrint('[Conversation] Error parsing message: $err');
              return null;
            }
          })
          .whereType<Message>()
          .toList();
    }

    // Parse product safely
    Product? product;
    if (json['product'] != null && json['product'] is Map<String, dynamic>) {
      try {
        product = Product.fromJson(json['product']);
      } catch (err) {
        debugPrint('[Conversation] Error parsing product: $err');
      }
    }

    // Parse last_message safely
    Message? lastMessage;
    if (json['last_message'] != null && json['last_message'] is Map<String, dynamic>) {
      try {
        lastMessage = Message.fromJson(json['last_message']);
      } catch (_) {}
    }

    return Conversation(
      id: json['id']?.toString() ?? '',
      buyerId: json['buyer_id']?.toString() ?? '',
      sellerId: json['seller_id']?.toString() ?? '',
      productId: json['product_id']?.toString(),
      status: json['status'] ?? 'active',
      lastMessageAt: json['last_message_at']?.toString(),
      buyer: _parseParticipant(json['buyer']),
      seller: _parseParticipant(json['seller']),
      otherUserData: _parseParticipant(json['other_user']),
      product: product,
      lastMessage: lastMessage,
      messages: msgList,
      unreadCount: json['unread_count'] ?? 0,
    );
  }

  static ConversationParticipant? _parseParticipant(dynamic data) {
    if (data == null || data is! Map<String, dynamic>) return null;
    try {
      return ConversationParticipant.fromJson(data);
    } catch (_) {
      return null;
    }
  }
}

class ConversationParticipant {
  final String id;
  final String? fullName;
  final String? username;
  final String? avatarUrl;
  final bool isOnline;

  ConversationParticipant({
    required this.id,
    this.fullName,
    this.username,
    this.avatarUrl,
    this.isOnline = false,
  });

  factory ConversationParticipant.fromJson(Map<String, dynamic> json) {
    return ConversationParticipant(
      id: json['id']?.toString() ?? '',
      fullName: json['full_name'],
      username: json['username'],
      avatarUrl: json['avatar_url'],
      isOnline: json['is_online'] ?? false,
    );
  }
}
