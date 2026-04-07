import 'package:flutter/foundation.dart';
import '../models/notification.dart';
import '../services/notification_service.dart';

class NotificationProvider extends ChangeNotifier {
  final NotificationApiService _notifService;

  List<AppNotification> _notifications = [];
  int _unreadCount = 0;
  Map<String, int> _tabCounts = {};
  bool _isLoading = false;
  String _activeTab = 'all';

  NotificationProvider(this._notifService);

  List<AppNotification> get notifications => _notifications;
  int get unreadCount => _unreadCount;
  Map<String, int> get tabCounts => _tabCounts;
  bool get isLoading => _isLoading;
  String get activeTab => _activeTab;

  Future<void> loadNotifications({String? tab}) async {
    _isLoading = true;
    if (tab != null) _activeTab = tab;
    notifyListeners();

    try {
      final data = await _notifService.getNotifications(tab: _activeTab);

      // Parse notifications from the 'data' field (backend returns { data: [...], meta: {...}, counts: {...} })
      final list = data['data'] ??
          data['notifications']?['data'] ??
          data['notifications'] ??
          [];
      _notifications =
          (list as List).map((e) => AppNotification.fromJson(e)).toList();

      // Parse tab counts if available
      if (data['counts'] != null) {
        final counts = data['counts'] as Map<String, dynamic>;
        _tabCounts = counts.map((k, v) => MapEntry(k, (v as num?)?.toInt() ?? 0));
      }
    } catch (_) {}

    _isLoading = false;
    notifyListeners();
  }

  Future<void> loadUnreadCount() async {
    try {
      final result = await _notifService.getUnreadCount();
      _unreadCount = result;
      notifyListeners();
    } catch (_) {}
  }

  Future<void> markAsRead(String id) async {
    try {
      await _notifService.markAsRead(id);
      final idx = _notifications.indexWhere((n) => n.id == id);
      if (idx >= 0) {
        final old = _notifications[idx];
        _notifications[idx] = AppNotification(
          id: old.id,
          type: old.type,
          title: old.title,
          body: old.body,
          icon: old.icon,
          isRead: true,
          createdAt: old.createdAt,
          actionUrl: old.actionUrl,
          imageUrl: old.imageUrl,
          data: old.data,
          groupCount: old.groupCount,
          groupKey: old.groupKey,
          sender: old.sender,
          priority: old.priority,
        );
        if (_unreadCount > 0) _unreadCount--;
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<void> markAllAsRead() async {
    try {
      await _notifService.markAllAsRead();
      _unreadCount = 0;
      _tabCounts = _tabCounts.map((k, v) => MapEntry(k, 0));
      await loadNotifications();
    } catch (_) {}
  }

  Future<void> deleteNotification(String id) async {
    try {
      await _notifService.deleteNotification(id);
      final wasUnread = _notifications.any((n) => n.id == id && !n.isRead);
      _notifications.removeWhere((n) => n.id == id);
      if (wasUnread && _unreadCount > 0) _unreadCount--;
      notifyListeners();
    } catch (_) {}
  }
}
