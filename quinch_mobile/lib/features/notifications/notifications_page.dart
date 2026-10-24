import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router.dart';
import '../../core/format/time_ago.dart';
import '../../core/network/api_error.dart';
import '../../core/providers.dart';
import '../../data/models/notifications.dart';
import '../../data/repositories/notification_repository.dart';
import '../../shared/paging/paged_notifier.dart';
import '../../shared/paging/paged_scroll.dart';
import 'notification_providers.dart';

/// Icône d'une notification selon son type. Types vus dans le backend : like,
/// follow, comment, review (interactions) ; message ; system, admin, transaction,
/// welcome (système). Un type inconnu reçoit l'icône générique.
IconData notificationIcon(String type) => switch (type) {
  'like' => Icons.favorite_outline,
  'follow' => Icons.person_add_alt_outlined,
  'comment' => Icons.chat_bubble_outline,
  'review' => Icons.star_outline,
  'message' => Icons.mail_outline,
  'welcome' => Icons.celebration_outlined,
  'admin' => Icons.shield_outlined,
  'transaction' => Icons.receipt_long_outlined,
  _ => Icons.notifications_none,
};

class NotificationsPage extends ConsumerStatefulWidget {
  const NotificationsPage({super.key});

  @override
  ConsumerState<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends ConsumerState<NotificationsPage> {
  NotificationTab _tab = NotificationTab.all;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _ensureLoaded());
  }

  void _ensureLoaded() {
    if (!mounted) {
      return;
    }
    if (ref.read(notificationsProvider(_tab)).status == PagedStatus.idle) {
      ref.read(notificationsProvider(_tab).notifier).refresh();
    }
  }

  void _select(NotificationTab tab) {
    if (tab == _tab) {
      return;
    }
    setState(() => _tab = tab);
    // Le chargement se fait au prochain affichage : le provider de l'onglet est
    // écouté par `build`, il existe donc déjà quand ce rappel s'exécute.
    WidgetsBinding.instance.addPostFrameCallback((_) => _ensureLoaded());
  }

  Future<void> _markAllRead() async {
    try {
      await ref.read(notificationsProvider(_tab).notifier).markAllRead();
    } on ApiError catch (e) {
      _toast(e.userMessage);
    }
  }

  void _toast(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(notificationsProvider(_tab));
    final notifier = ref.read(notificationsProvider(_tab).notifier);
    final counts = ref.watch(unreadCountProvider).valueOrNull;

    int unreadFor(NotificationTab tab) => switch (tab) {
      NotificationTab.all => counts?.all ?? 0,
      NotificationTab.interactions => counts?.interactions ?? 0,
      NotificationTab.messages => counts?.messages ?? 0,
      NotificationTab.system => counts?.system ?? 0,
    };

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          IconButton(
            tooltip: 'Tout marquer comme lu',
            icon: const Icon(Icons.done_all),
            onPressed: _markAllRead,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  for (final tab in NotificationTab.values)
                    ChoiceChip(
                      label: Text(
                        unreadFor(tab) > 0
                            ? '${tab.label} (${unreadFor(tab)})'
                            : tab.label,
                      ),
                      selected: _tab == tab,
                      onSelected: (_) => _select(tab),
                    ),
                ],
              ),
            ),
          ),
          Expanded(
            child: PagedScroll<AppNotification>(
              state: state,
              onRefresh: () async {
                await notifier.refresh();
                ref.invalidate(unreadCountProvider);
              },
              onLoadMore: notifier.loadMore,
              itemBuilder: (context, notification) => _Tile(
                notification: notification,
                onOpen: () async {
                  if (!notification.isRead) {
                    try {
                      await notifier.markRead(notification.id);
                    } on ApiError {
                      // La lecture est un confort : on ouvre quand même le détail.
                    }
                  }
                  if (context.mounted) {
                    await context.push(notificationPath(notification.id));
                  }
                },
                onDelete: () async {
                  try {
                    await notifier.delete(notification.id);
                  } on ApiError catch (e) {
                    _toast(e.userMessage);
                  }
                },
              ),
              emptyIcon: Icons.notifications_none,
              emptyMessage: 'Aucune notification pour le moment.',
            ),
          ),
        ],
      ),
    );
  }
}

class _Tile extends ConsumerWidget {
  const _Tile({
    required this.notification,
    required this.onOpen,
    required this.onDelete,
  });

  final AppNotification notification;
  final VoidCallback onOpen;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final unread = !notification.isRead;
    final created = notification.createdAt;
    final when = created == null
        ? ''
        : timeAgoFr(created, now: ref.watch(clockProvider)());
    return Card(
      margin: EdgeInsets.zero,
      color: unread
          ? theme.colorScheme.primaryContainer.withValues(alpha: 0.35)
          : null,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 4, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                notificationIcon(notification.type),
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      notification.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: unread
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                    if (notification.body.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        notification.body,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    if (when.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(when, style: theme.textTheme.bodySmall),
                    ],
                  ],
                ),
              ),
              if (unread)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Semantics(
                    label: 'Non lue',
                    child: Icon(
                      Icons.circle,
                      size: 10,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
              IconButton(
                tooltip: 'Supprimer la notification',
                icon: const Icon(Icons.close, size: 20),
                onPressed: onDelete,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Cloche avec pastille du nombre de notifications non lues.
class NotificationBell extends ConsumerWidget {
  const NotificationBell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(unreadCountProvider).valueOrNull?.all ?? 0;
    return IconButton(
      tooltip: count > 0 ? 'Notifications ($count non lues)' : 'Notifications',
      icon: Badge(
        isLabelVisible: count > 0,
        label: Text(count > 99 ? '99+' : '$count'),
        child: const Icon(Icons.notifications_outlined),
      ),
      onPressed: () async {
        await context.push(notificationsPath);
        ref.invalidate(unreadCountProvider);
      },
    );
  }
}
