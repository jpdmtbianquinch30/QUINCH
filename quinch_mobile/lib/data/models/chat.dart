import '../../core/json/json_utils.dart';

/// L'autre personne d'une conversation (`other_user` du serveur).
class ChatUser {
  const ChatUser({
    required this.id,
    required this.fullName,
    this.username,
    this.avatarUrl,
    this.lastSeenAt,
    this.isPremium = false,
  });

  factory ChatUser.fromJson(Object? json) {
    final m = asMap(json);
    return ChatUser(
      id: asString(m['id']),
      fullName: asString(m['full_name']),
      username: asStringOrNull(m['username']),
      avatarUrl: asStringOrNull(m['avatar_url']),
      lastSeenAt: asDate(m['last_seen_at']),
      isPremium: asBool(m['is_premium']),
    );
  }

  final String id;
  final String fullName;
  final String? username;
  final String? avatarUrl;
  final DateTime? lastSeenAt;
  final bool isPremium;
}

/// Annonce liée à une conversation (`product` : id, titre, slug, prix).
class ChatProductRef {
  const ChatProductRef({
    required this.id,
    required this.title,
    this.slug,
    this.price,
  });

  factory ChatProductRef.fromJson(Object? json) {
    final m = asMap(json);
    return ChatProductRef(
      id: asString(m['id']),
      title: asString(m['title']),
      slug: asStringOrNull(m['slug']),
      price: m['price'] == null ? null : asDouble(m['price']),
    );
  }

  final String id;
  final String title;
  final String? slug;
  final double? price;
}

/// Types de messages connus du serveur (`type`). Seul `text` s'envoie depuis le
/// lot 6d-1 ; les autres sont affichés ou signalés comme non pris en charge.
class ChatMessageType {
  static const text = 'text';
  static const productTag = 'product_tag';
  static const image = 'image';
  static const file = 'file';
  static const video = 'video';
}

class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.body,
    required this.type,
    this.metadata = const <String, dynamic>{},
    this.isRead = false,
    this.createdAtRaw,
    this.createdAt,
  });

  factory ChatMessage.fromJson(Object? json) {
    final m = asMap(json);
    final created = asStringOrNull(m['created_at']);
    return ChatMessage(
      id: asString(m['id']),
      conversationId: asString(m['conversation_id']),
      senderId: asString(m['sender_id']),
      body: asString(m['body']),
      type: asString(m['type'], ChatMessageType.text),
      metadata: asMap(m['metadata']),
      isRead: asBool(m['is_read']),
      createdAtRaw: created,
      createdAt: asDate(created),
    );
  }

  final String id;
  final String conversationId;
  final String senderId;
  final String body;
  final String type;
  final Map<String, dynamic> metadata;
  final bool isRead;

  /// Horodatage tel que renvoyé par le serveur : on le renvoie tel quel dans
  /// `messages/since?after=` pour ne pas perdre de précision.
  final String? createdAtRaw;
  final DateTime? createdAt;

  bool get isText => type == ChatMessageType.text;
  bool get isProductTag => type == ChatMessageType.productTag;
  bool get isImage => type == ChatMessageType.image;
  bool get isVideo => type == ChatMessageType.video;
  bool get isFile => type == ChatMessageType.file;
  bool get isAttachment => isImage || isVideo || isFile;

  /// Pièce jointe : `metadata` du serveur (`file_url`, `file_name`, `file_size`).
  String? get fileUrl => asStringOrNull(metadata['file_url']);
  String? get fileName => asStringOrNull(metadata['file_name']);
  int? get fileSize =>
      metadata['file_size'] == null ? null : asInt(metadata['file_size']);
}

/// Une conversation de la boîte de réception.
class Conversation {
  const Conversation({
    required this.id,
    this.otherUser,
    this.product,
    this.lastMessage,
    this.unreadCount = 0,
    this.lastMessageAt,
  });

  factory Conversation.fromJson(Object? json) {
    final m = asMap(json);
    final other = asMapOrNull(m['other_user']);
    final product = asMapOrNull(m['product']);
    final last = asMapOrNull(m['last_message']);
    return Conversation(
      id: asString(m['id']),
      otherUser: other == null ? null : ChatUser.fromJson(other),
      product: product == null ? null : ChatProductRef.fromJson(product),
      lastMessage: last == null ? null : ChatMessage.fromJson(last),
      unreadCount: asInt(m['unread_count']),
      lastMessageAt: asDate(m['last_message_at']),
    );
  }

  final String id;
  final ChatUser? otherUser;
  final ChatProductRef? product;
  final ChatMessage? lastMessage;
  final int unreadCount;
  final DateTime? lastMessageAt;
}

/// Réponse de `GET conversations/{id}` : la conversation et ses derniers messages
/// (50 au plus, du plus ancien au plus récent).
class ConversationDetail {
  const ConversationDetail({
    required this.conversation,
    required this.messages,
  });

  factory ConversationDetail.fromJson(Object? body) {
    final conversation = asMap(asMap(body)['conversation']);
    return ConversationDetail(
      conversation: Conversation.fromJson(conversation),
      messages: asMapList(
        conversation['messages'],
      ).map(ChatMessage.fromJson).toList(),
    );
  }

  final Conversation conversation;
  final List<ChatMessage> messages;
}

/// Réponse de `GET conversations/{id}/messages/since`.
class NewMessages {
  const NewMessages({required this.messages, this.otherUser});

  factory NewMessages.fromJson(Object? body) {
    final m = asMap(body);
    final other = asMapOrNull(m['other_user']);
    return NewMessages(
      messages: asMapList(m['messages']).map(ChatMessage.fromJson).toList(),
      otherUser: other == null ? null : ChatUser.fromJson(other),
    );
  }

  final List<ChatMessage> messages;
  final ChatUser? otherUser;
}
