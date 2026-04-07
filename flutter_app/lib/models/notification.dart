class AppNotification {
  final String id;
  final String type;
  final String title;
  final String body;
  final String? icon;
  final String? actionUrl;
  final String? imageUrl;
  final String priority;
  final bool isRead;
  final String? readAt;
  final Map<String, dynamic>? data;
  final int? groupCount;
  final String? groupKey;
  final NotificationSender? sender;
  final String createdAt;

  AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    this.icon,
    this.actionUrl,
    this.imageUrl,
    this.priority = 'normal',
    this.isRead = false,
    this.readAt,
    this.data,
    this.groupCount,
    this.groupKey,
    this.sender,
    required this.createdAt,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['id']?.toString() ?? '',
      type: json['type'] ?? '',
      title: json['title'] ?? '',
      body: json['body'] ?? '',
      icon: json['icon'],
      actionUrl: json['action_url'],
      imageUrl: json['image_url'],
      priority: json['priority'] ?? 'normal',
      isRead: json['is_read'] ?? false,
      readAt: json['read_at'],
      data: json['data'] is Map<String, dynamic> ? json['data'] : null,
      groupCount: json['group_count'],
      groupKey: json['group_key'],
      sender: json['sender'] != null
          ? NotificationSender.fromJson(json['sender'])
          : null,
      createdAt: json['created_at'] ?? '',
    );
  }
}

class NotificationSender {
  final String id;
  final String? fullName;
  final String? username;
  final String? avatarUrl;

  NotificationSender({
    required this.id,
    this.fullName,
    this.username,
    this.avatarUrl,
  });

  factory NotificationSender.fromJson(Map<String, dynamic> json) {
    return NotificationSender(
      id: json['id']?.toString() ?? '',
      fullName: json['full_name'],
      username: json['username'],
      avatarUrl: json['avatar_url'],
    );
  }
}

class NotificationPreference {
  final String type;
  final bool push;
  final bool inApp;
  final bool email;

  NotificationPreference({
    required this.type,
    this.push = true,
    this.inApp = true,
    this.email = false,
  });

  factory NotificationPreference.fromJson(Map<String, dynamic> json) {
    return NotificationPreference(
      type: json['type'] ?? '',
      push: json['push'] ?? true,
      inApp: json['in_app'] ?? true,
      email: json['email'] ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
    'type': type,
    'push': push,
    'in_app': inApp,
    'email': email,
  };
}
