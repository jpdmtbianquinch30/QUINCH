class Message {
  final String id;
  final String conversationId;
  final String senderId;
  final String? body;
  final String type; // text, image, offer, audio, file
  final Map<String, dynamic>? metadata;
  final bool isRead;
  final String? readAt;
  final MessageSender? sender;
  final String createdAtStr;
  bool isMe;

  Message({
    required this.id,
    required this.conversationId,
    required this.senderId,
    this.body,
    this.type = 'text',
    this.metadata,
    this.isRead = false,
    this.readAt,
    this.sender,
    required this.createdAtStr,
    this.isMe = false,
  });

  /// Alias for body
  String? get content => body;

  DateTime get createdAt => DateTime.tryParse(createdAtStr) ?? DateTime.now();

  bool get isAudio => type == 'audio';
  bool get isImage => type == 'image';
  bool get isFile => type == 'file';
  bool get isOffer => type == 'offer';
  bool get isText => type == 'text';

  String? get audioUrl => metadata?['audio_url'] ?? metadata?['url'];
  String? get imageUrl => metadata?['image_url'] ?? metadata?['url'];
  String? get mediaUrl => imageUrl ?? audioUrl ?? metadata?['url'];
  String? get fileUrl => metadata?['file_url'] ?? metadata?['url'];
  String? get fileName => metadata?['file_name'] ?? metadata?['original_name'];
  double? get audioDuration => metadata?['duration']?.toDouble();

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      id: json['id']?.toString() ?? '',
      conversationId: json['conversation_id']?.toString() ?? '',
      senderId: json['sender_id']?.toString() ?? '',
      body: json['body'],
      type: json['type'] ?? 'text',
      metadata: json['metadata'],
      isRead: json['is_read'] ?? false,
      readAt: json['read_at'],
      sender: json['sender'] != null
          ? MessageSender.fromJson(json['sender'])
          : null,
      createdAtStr: json['created_at'] ?? '',
      isMe: json['is_me'] ?? false,
    );
  }
}

class MessageSender {
  final String id;
  final String? fullName;
  final String? avatarUrl;

  MessageSender({
    required this.id,
    this.fullName,
    this.avatarUrl,
  });

  factory MessageSender.fromJson(Map<String, dynamic> json) {
    return MessageSender(
      id: json['id']?.toString() ?? '',
      fullName: json['full_name'],
      avatarUrl: json['avatar_url'],
    );
  }
}
