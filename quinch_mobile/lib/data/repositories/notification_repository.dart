import '../../core/json/json_utils.dart';
import '../../core/network/api_client.dart';
import '../api/endpoints.dart';
import '../models/notifications.dart';
import '../models/paginated.dart';

/// Onglets de notifications gérés par le serveur (`tab`).
enum NotificationTab {
  all('all', 'Toutes'),
  interactions('interactions', 'Interactions'),
  messages('messages', 'Messages'),
  system('system', 'Système');

  const NotificationTab(this.value, this.label);
  final String value;
  final String label;
}

/// Notifications consultables dans l'application. Aucune notification push :
/// le serveur n'a aucun mécanisme d'enregistrement d'appareil.
class NotificationRepository {
  NotificationRepository(this._api);

  final ApiClient _api;

  Future<Paginated<AppNotification>> list({
    NotificationTab tab = NotificationTab.all,
    int page = 1,
  }) async {
    final body = await _api.get(
      Endpoints.notifications,
      query: <String, Object?>{'tab': tab.value, 'page': page},
    );
    return Paginated<AppNotification>.fromJson(body, AppNotification.fromJson);
  }

  Future<NotificationCounts> unreadCount() async {
    final body = await _api.get(Endpoints.notificationsUnreadCount);
    return NotificationCounts.fromUnreadCount(body);
  }

  Future<NotificationDetail> detail(String id) async {
    final body = await _api.get(Endpoints.notification(id));
    return NotificationDetail.fromJson(body);
  }

  Future<void> markRead(String id) async {
    await _api.post(Endpoints.notificationRead(id));
  }

  /// Marque comme lues les notifications de l'onglet donné.
  Future<void> markAllRead({NotificationTab tab = NotificationTab.all}) async {
    await _api.post(
      Endpoints.notificationsReadAll,
      query: <String, Object?>{'tab': tab.value},
    );
  }

  Future<void> delete(String id) async {
    await _api.delete(Endpoints.notification(id));
  }

  /// Contestation ou réponse à l'équipe (10 à 2000 caractères). 409 si une
  /// contestation est déjà en cours, 422 si la décision n'est plus contestable.
  Future<String?> contest(String id, String message) async {
    final body = await _api.post(
      Endpoints.notificationContest(id),
      data: <String, Object?>{'message': message.trim()},
    );
    return asStringOrNull(asMap(body)['message']);
  }

  Future<List<NotificationPreference>> preferences() async {
    final body = await _api.get(Endpoints.notificationsPreferences);
    return asMapList(
      asMap(body)['preferences'],
    ).map(NotificationPreference.fromJson).toList();
  }

  /// Envoie la liste complète des préférences (valeurs absentes = défauts du serveur).
  Future<void> updatePreferences(
    List<NotificationPreference> preferences,
  ) async {
    await _api.put(
      Endpoints.notificationsPreferences,
      data: <String, Object?>{
        'preferences': preferences.map((p) => p.toPayload()).toList(),
      },
    );
  }
}
