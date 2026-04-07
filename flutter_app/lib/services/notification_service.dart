import '../models/notification.dart';
import 'api_service.dart';

class NotificationApiService {
  final ApiService _api;

  NotificationApiService(this._api);

  Future<Map<String, dynamic>> getNotifications({
    String? tab,
    int page = 1,
  }) async {
    final params = <String, dynamic>{'page': page};
    if (tab != null) params['tab'] = tab;
    final response =
        await _api.get('/notifications', queryParameters: params);
    return response.data;
  }

  Future<int> getUnreadCount() async {
    final response = await _api.get('/notifications/unread-count');
    return response.data['count'] ?? 0;
  }

  Future<void> markAsRead(String id) async {
    await _api.post('/notifications/$id/read');
  }

  Future<void> markAllAsRead() async {
    await _api.post('/notifications/read-all');
  }

  Future<void> deleteNotification(String id) async {
    await _api.delete('/notifications/$id');
  }

  Future<List<NotificationPreference>> getPreferences() async {
    final response = await _api.get('/notifications/preferences');
    final list =
        response.data['preferences'] ?? response.data['data'] ?? [];
    return (list as List)
        .map((e) => NotificationPreference.fromJson(e))
        .toList();
  }

  Future<void> updatePreferences(
      List<NotificationPreference> preferences) async {
    await _api.put('/notifications/preferences', data: {
      'preferences': preferences.map((e) => e.toJson()).toList(),
    });
  }
}
