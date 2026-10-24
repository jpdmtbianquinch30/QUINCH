import '../../core/json/json_utils.dart';

class ChatUser {
  const ChatUser({
    required this.id,
    required this.fullName,
    this.username,
    this.avatarUrl,
    this.isPremium = false,
    this.isOnline,
    this.isFriend,
  });

  final String id;
  final String fullName;
  final String? username;
  final String? avatarUrl;
  final bool isPremium;
  final bool? isOnline;
  final bool? isFriend;

  factory ChatUser.fromJson(Json j) => ChatUser(
    id: asString(j['id']),
    fullName: asString(j['full_name']),
    username: asStringOrNull(j['username']),
    avatarUrl: asStringOrNull(j['avatar_url']),
    isPremium: asBool(j['is_premium']),
    isOnline: j['is_online'] == null ? null : asBool(j['is_online']),
    isFriend: j['is_friend'] == null ? null : asBool(j['is_friend']),
  );
}

/// Message. `type` observé dans le code : text, image, offer, audio, file, video,
/// et des messages d'étiquette produit ; le champ `metadata` dépend du type
/// (file_url, file_name, file_size, mime_type, audio_url, duration, availability, ...).
class Message {
  const Message({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.body,
    required this.type,
    required this.createdAtRaw,
    this.metadata = const {},
    this.isRead = false,
    this.sender,
  });

  final String id;
  final String conversationId;
  final String senderId;
  final String body;
  final String type;

  /// created_at tel que renvoyé par le serveur. À renvoyer TEL QUEL dans `after`
  /// pour `messages/since` (comportement d'Angular), sans le reformater.
  final String createdAtRaw;
  final Json metadata;
  final bool isRead;
  final ChatUser? sender;

  DateTime? get createdAt => DateTime.tryParse(createdAtRaw);

  factory Message.fromJson(Json j) {
    final senderMap = asMapOrNull(j['sender']);
    return Message(
      id: asString(j['id']),
      conversationId: asString(j['conversation_id']),
      senderId: asString(j['sender_id']),
      body: asString(j['body']),
      type: asString(j['type'], 'text'),
      createdAtRaw: asString(j['created_at']),
      metadata: asMap(j['metadata']),
      isRead: asBool(j['is_read']),
      sender: senderMap == null ? null : ChatUser.fromJson(senderMap),
    );
  }
}

class Conversation {
  const Conversation({
    required this.id,
    required this.buyerId,
    required this.sellerId,
    this.productId,
    this.status,
    this.lastMessageAt,
    this.unreadCount = 0,
    this.otherUser,
    this.lastMessage,
    this.product,
    this.messages = const [],
    this.productTags = const [],
  });

  final String id;
  final String buyerId;
  final String sellerId;
  final String? productId;
  final String? status;
  final DateTime? lastMessageAt;
  final int unreadCount;
  final ChatUser? otherUser;
  final Message? lastMessage;

  /// Liste : {id,title,slug,price}. Forme du détail non confirmée : gardé brut.
  final Json? product;

  /// Détail : les 50 derniers messages seulement (pas de pagination vers l'arrière).
  final List<Message> messages;

  /// Forme exacte de `productTags` non confirmée : gardé brut.
  final List<Json> productTags;

  factory Conversation.fromJson(Json j) {
    final other = asMapOrNull(j['other_user']);
    final last = asMapOrNull(j['last_message']);
    return Conversation(
      id: asString(j['id']),
      buyerId: asString(j['buyer_id']),
      sellerId: asString(j['seller_id']),
      productId: asStringOrNull(j['product_id']),
      status: asStringOrNull(j['status']),
      lastMessageAt: asDate(j['last_message_at']),
      unreadCount: asInt(j['unread_count']),
      otherUser: other == null ? null : ChatUser.fromJson(other),
      lastMessage: last == null ? null : Message.fromJson(last),
      product: asMapOrNull(j['product']),
      messages: asMapList(j['messages']).map(Message.fromJson).toList(),
      productTags: asMapList(j['product_tags']),
    );
  }
}

/// `GET conversations/{id}/messages/since?after=` : `{messages, other_user}`.
class NewMessages {
  const NewMessages({required this.messages, this.otherUser});

  final List<Message> messages;
  final ChatUser? otherUser;

  factory NewMessages.fromJson(Object? body) {
    final m = asMap(body);
    final other = asMapOrNull(m['other_user']);
    return NewMessages(
      messages: asMapList(m['messages']).map(Message.fromJson).toList(),
      otherUser: other == null ? null : ChatUser.fromJson(other),
    );
  }
}
