import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/router.dart';
import '../../core/providers.dart';
import '../../data/models/notifications.dart';
import '../../data/models/paginated.dart';
import '../../data/repositories/notification_repository.dart';
import '../../shared/paging/paged_notifier.dart';

final notificationRepositoryProvider = Provider<NotificationRepository>(
  (ref) => NotificationRepository(ref.watch(apiClientProvider)),
);

/// Nombre de notifications non lues (pastille de la cloche). À invalider après
/// toute lecture, suppression ou « tout marquer comme lu ».
final unreadCountProvider = FutureProvider.autoDispose<NotificationCounts>(
  (ref) => ref.watch(notificationRepositoryProvider).unreadCount(),
);

class NotificationsController
    extends PagedFamilyNotifier<AppNotification, NotificationTab> {
  @override
  Future<Paginated<AppNotification>> fetchPage(int page) =>
      ref.read(notificationRepositoryProvider).list(tab: arg, page: page);

  Future<void> markRead(String id) async {
    await ref.read(notificationRepositoryProvider).markRead(id);
    updateWhere((n) => n.id == id, (n) => n.copyWith(isRead: true));
    ref.invalidate(unreadCountProvider);
  }

  Future<void> markAllRead() async {
    await ref.read(notificationRepositoryProvider).markAllRead(tab: arg);
    await refresh();
    ref.invalidate(unreadCountProvider);
  }

  Future<void> delete(String id) async {
    await ref.read(notificationRepositoryProvider).delete(id);
    removeWhere((n) => n.id == id);
    ref.invalidate(unreadCountProvider);
  }
}

final notificationsProvider = NotifierProvider.autoDispose
    .family<
      NotificationsController,
      PagedState<AppNotification>,
      NotificationTab
    >(NotificationsController.new);

final notificationDetailProvider = FutureProvider.autoDispose
    .family<NotificationDetail, String>(
      (ref, id) => ref.watch(notificationRepositoryProvider).detail(id),
    );

final notificationPreferencesProvider =
    FutureProvider.autoDispose<List<NotificationPreference>>(
      (ref) => ref.watch(notificationRepositoryProvider).preferences(),
    );

/// Écran de l'application correspondant à l'adresse de page web d'une
/// notification, ou null si elle n'a pas d'équivalent dans l'application.
/// Les adresses viennent du serveur : seules celles d'une liste connue sont
/// ouvertes, jamais une adresse arbitraire.
String? appPathForNotification(String? actionUrl) {
  if (actionUrl == null || actionUrl.isEmpty || !actionUrl.startsWith('/')) {
    return null;
  }
  final uri = Uri.tryParse(actionUrl);
  if (uri == null || uri.pathSegments.isEmpty) {
    return null;
  }
  final segments = uri.pathSegments;
  switch (segments.first) {
    case 'product':
      return segments.length == 2 && segments[1].isNotEmpty
          ? productPath(segments[1])
          : null;
    case 'seller':
      return segments.length == 2 && segments[1].isNotEmpty
          ? sellerPath(segments[1])
          : null;
    case 'profile':
      if (segments.length == 1) {
        return accountPath;
      }
      return segments.length == 2 && segments[1] == 'edit'
          ? editProfilePath
          : null;
    default:
      // /messages (messagerie : étape 6), /admin/*, /guide/*, etc.
      return null;
  }
}
