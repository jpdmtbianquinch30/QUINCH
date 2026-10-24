import '../../core/json/json_utils.dart';
import 'messaging.dart';

class AppNotification {
  const AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    this.icon,
    this.actionUrl,
    this.data = const {},
    this.isRead = false,
    this.priority,
    this.imageUrl,
    this.createdAt,
    this.sender,
  });

  final String id;

  /// Onglets du serveur : interactions = like, follow, comment, review ;
  /// messages = message ; système = system, admin, transaction, welcome.
  final String type;
  final String title;
  final String body;
  final String? icon;

  /// Adresse d'une page du SITE WEB (ex. /messages). Elle n'est pas une route
  /// de l'app : à convertir en écran Flutter par une table explicite (étape 6),
  /// jamais à ouvrir telle quelle.
  final String? actionUrl;

  /// Peut contenir `contest` (décision contestable) et `guide_anchor`.
  final Json data;
  final bool isRead;
  final String? priority;
  final String? imageUrl;
  final DateTime? createdAt;
  final ChatUser? sender;

  AppNotification copyWith({bool? isRead}) => AppNotification(
    id: id,
    type: type,
    title: title,
    body: body,
    icon: icon,
    actionUrl: actionUrl,
    data: data,
    isRead: isRead ?? this.isRead,
    priority: priority,
    imageUrl: imageUrl,
    createdAt: createdAt,
    sender: sender,
  );

  factory AppNotification.fromJson(Json j) {
    final senderMap = asMapOrNull(j['sender']);
    return AppNotification(
      id: asString(j['id']),
      type: asString(j['type']),
      title: asString(j['title']),
      body: asString(j['body']),
      icon: asStringOrNull(j['icon']),
      actionUrl: asStringOrNull(j['action_url']),
      data: asMap(j['data']),
      isRead: asBool(j['is_read']),
      priority: asStringOrNull(j['priority']),
      imageUrl: asStringOrNull(j['image_url']),
      createdAt: asDate(j['created_at']),
      sender: senderMap == null ? null : ChatUser.fromJson(senderMap),
    );
  }
}

/// Compteurs non lus par onglet (`GET notifications` → `counts`, tous les onglets ;
/// `GET notifications/unread-count` → `count` + `tabs` : interactions, messages, system).
class NotificationCounts {
  const NotificationCounts({
    this.all = 0,
    this.interactions = 0,
    this.messages = 0,
    this.system = 0,
  });

  final int all;
  final int interactions;
  final int messages;
  final int system;

  factory NotificationCounts.fromListCounts(Json counts) => NotificationCounts(
    all: asInt(counts['all']),
    interactions: asInt(counts['interactions']),
    messages: asInt(counts['messages']),
    system: asInt(counts['system']),
  );

  factory NotificationCounts.fromUnreadCount(Object? body) {
    final m = asMap(body);
    final tabs = asMap(m['tabs']);
    return NotificationCounts(
      all: asInt(m['count']),
      interactions: asInt(tabs['interactions']),
      messages: asInt(tabs['messages']),
      system: asInt(tabs['system']),
    );
  }
}

class NotificationPreference {
  const NotificationPreference({
    required this.type,
    required this.label,
    required this.inAppEnabled,
    required this.emailEnabled,
    required this.pushEnabled,
  });

  final String type;
  final String label;
  final bool inAppEnabled;
  final bool emailEnabled;

  /// Préférence enregistrée côté serveur uniquement : AUCUN push n'existe.
  /// L'écran mobile ne doit pas présenter ce réglage comme actif.
  final bool pushEnabled;

  NotificationPreference copyWith({bool? inAppEnabled, bool? emailEnabled}) =>
      NotificationPreference(
        type: type,
        label: label,
        inAppEnabled: inAppEnabled ?? this.inAppEnabled,
        emailEnabled: emailEnabled ?? this.emailEnabled,
        pushEnabled: pushEnabled,
      );

  /// Corps attendu par `PUT notifications/preferences`. Les trois booléens sont
  /// TOUJOURS envoyés : le serveur remplace une valeur absente par sa valeur par
  /// défaut (push et in-app à vrai, email à faux). `push_enabled` est renvoyé tel
  /// que reçu : l'application n'a aucun moyen de le modifier.
  Json toPayload() => <String, dynamic>{
    'type': type,
    'push_enabled': pushEnabled,
    'in_app_enabled': inAppEnabled,
    'email_enabled': emailEnabled,
  };

  factory NotificationPreference.fromJson(Json j) => NotificationPreference(
    type: asString(j['type']),
    label: asString(j['label'], asString(j['type'])),
    inAppEnabled: asBool(j['in_app_enabled'], true),
    emailEnabled: asBool(j['email_enabled']),
    pushEnabled: asBool(j['push_enabled']),
  );
}

/// Contestation (ou réponse) liée à une notification.
/// Seul le statut `pending` est certain ; tout autre statut avec `handled_at`
/// signifie « traitée ».
class NotificationAppeal {
  const NotificationAppeal({
    required this.id,
    required this.status,
    required this.message,
    this.response,
    this.createdAt,
    this.handledAt,
  });

  final String id;
  final String status;
  final String message;
  final String? response;
  final DateTime? createdAt;
  final DateTime? handledAt;

  bool get isPending => status == 'pending';

  factory NotificationAppeal.fromJson(Json j) => NotificationAppeal(
    id: asString(j['id']),
    status: asString(j['status']),
    message: asString(j['message']),
    response: asStringOrNull(j['response']),
    createdAt: asDate(j['created_at']),
    handledAt: asDate(j['handled_at']),
  );
}

/// `GET notifications/{id}` : détail + état de la contestation éventuelle.
/// `contest.type` vaut `message` quand l'équipe a écrit à l'utilisateur : le bouton
/// est alors une réponse plutôt qu'une contestation.
class NotificationDetail {
  const NotificationDetail({
    required this.notification,
    this.hasContest = false,
    this.canContest = false,
    this.contestType,
    this.appeal,
  });

  final AppNotification notification;
  final bool hasContest;
  final bool canContest;
  final String? contestType;
  final NotificationAppeal? appeal;

  bool get isReply => contestType == 'message';

  factory NotificationDetail.fromJson(Object? body) {
    final m = asMap(body);
    final contest = asMapOrNull(m['contest']);
    final appeal = asMapOrNull(contest?['appeal']);
    return NotificationDetail(
      notification: AppNotification.fromJson(asMap(m['notification'])),
      hasContest: contest != null,
      canContest: contest != null && asBool(contest['can_contest']),
      contestType: asStringOrNull(contest?['type']),
      appeal: appeal == null ? null : NotificationAppeal.fromJson(appeal),
    );
  }
}
