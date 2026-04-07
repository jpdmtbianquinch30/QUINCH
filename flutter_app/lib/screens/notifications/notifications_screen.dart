import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../providers/notification_provider.dart';
import '../../models/notification.dart';
import '../../config/theme.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  String _activeTab = 'all';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadTab('all');
    });
  }

  void _loadTab(String tab) {
    setState(() => _activeTab = tab);
    context.read<NotificationProvider>().loadNotifications(tab: tab);
  }

  @override
  Widget build(BuildContext context) {
    final notif = context.watch<NotificationProvider>();
    final grouped = _getTimeSections(notif.notifications);

    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: AppBar(
        backgroundColor: AppColors.bgSecondary,
        title: Row(children: [
          const Text('Notifications',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 20)),
          if (notif.unreadCount > 0) ...[
            const SizedBox(width: 8),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(10)),
              child: Text('${notif.unreadCount}',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w700)),
            ),
          ],
        ]),
        actions: [
          if (notif.unreadCount > 0)
            TextButton.icon(
              onPressed: () {
                notif.markAllAsRead();
              },
              icon: const Icon(Icons.done_all, color: AppColors.accent, size: 18),
              label: const Text('Tout lire',
                  style:
                      TextStyle(color: AppColors.accent, fontSize: 13)),
            ),
        ],
      ),
      body: Column(
        children: [
          // ═══ TABS (matching frontend: Tout, Interactions, Messages, Système) ═══
          Container(
            padding:
                const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
            child: SizedBox(
              height: 38,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  _TabChip(
                    label: 'Tout',
                    active: _activeTab == 'all',
                    onTap: () => _loadTab('all'),
                  ),
                  _TabChip(
                    label: 'Interactions',
                    icon: Icons.favorite,
                    active: _activeTab == 'interactions',
                    onTap: () => _loadTab('interactions'),
                  ),
                  _TabChip(
                    label: 'Messages',
                    icon: Icons.chat,
                    active: _activeTab == 'messages',
                    onTap: () => _loadTab('messages'),
                  ),
                  _TabChip(
                    label: 'Système',
                    icon: Icons.info_outline,
                    active: _activeTab == 'system',
                    onTap: () => _loadTab('system'),
                  ),
                ],
              ),
            ),
          ),

          // ═══ LIST ═══
          Expanded(
            child: notif.isLoading && notif.notifications.isEmpty
                ? const Center(
                    child: CircularProgressIndicator(
                        color: AppColors.accent))
                : notif.notifications.isEmpty
                    ? _buildEmpty()
                    : RefreshIndicator(
                        color: AppColors.accent,
                        onRefresh: () =>
                            notif.loadNotifications(tab: _activeTab),
                        child: ListView.builder(
                          padding: const EdgeInsets.only(bottom: 100),
                          itemCount: grouped.length,
                          itemBuilder: (_, i) =>
                              _buildSection(grouped[i]),
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    IconData icon;
    switch (_activeTab) {
      case 'interactions':
        icon = Icons.favorite_border;
        break;
      case 'messages':
        icon = Icons.chat_bubble_outline;
        break;
      case 'system':
        icon = Icons.info_outline;
        break;
      default:
        icon = Icons.notifications_none;
    }
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
                color: AppColors.accentSubtle,
                borderRadius: BorderRadius.circular(20)),
            child: Icon(icon, size: 36, color: AppColors.accent),
          ),
          const SizedBox(height: 20),
          Text('Aucune notification',
              style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text(
              'Vous serez notifié des activités importantes ici',
              style:
                  TextStyle(color: AppColors.textMuted, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildSection(_TimeSection section) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding:
              const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(section.label,
              style: TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5)),
        ),
        ...section.notifications
            .map((n) => _NotifTile(
                  notification: n,
                  onDelete: () {
                    context
                        .read<NotificationProvider>()
                        .deleteNotification(n.id);
                  },
                )),
      ],
    );
  }

  List<_TimeSection> _getTimeSections(List<AppNotification> notifications) {
    final now = DateTime.now();
    final today = <AppNotification>[];
    final yesterday = <AppNotification>[];
    final thisWeek = <AppNotification>[];
    final older = <AppNotification>[];

    for (final n in notifications) {
      final d = DateTime.tryParse(n.createdAt) ?? now;
      final diff = now.difference(d);
      if (diff.inDays == 0 && d.day == now.day) {
        today.add(n);
      } else if (diff.inDays < 2) {
        yesterday.add(n);
      } else if (diff.inDays < 7) {
        thisWeek.add(n);
      } else {
        older.add(n);
      }
    }

    final sections = <_TimeSection>[];
    if (today.isNotEmpty) {
      sections.add(_TimeSection("Aujourd'hui", today));
    }
    if (yesterday.isNotEmpty) {
      sections.add(_TimeSection('Hier', yesterday));
    }
    if (thisWeek.isNotEmpty) {
      sections.add(_TimeSection('Cette semaine', thisWeek));
    }
    if (older.isNotEmpty) {
      sections.add(_TimeSection('Plus ancien', older));
    }
    return sections;
  }
}

class _TimeSection {
  final String label;
  final List<AppNotification> notifications;
  _TimeSection(this.label, this.notifications);
}

// ═══ TAB CHIP ═══
class _TabChip extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool active;
  final VoidCallback onTap;

  const _TabChip({
    required this.label,
    this.icon,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: active ? AppColors.accentSubtle : AppColors.bgCard,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: active
                  ? AppColors.accent.withValues(alpha: 0.4)
                  : AppColors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon,
                  size: 15,
                  color:
                      active ? AppColors.accent : AppColors.textMuted),
              const SizedBox(width: 5),
            ],
            Text(label,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight:
                        active ? FontWeight.w600 : FontWeight.w500,
                    color: active
                        ? AppColors.accent
                        : AppColors.textSecondary)),
          ],
        ),
      ),
    );
  }
}

// ═══ NOTIFICATION TILE ═══
class _NotifTile extends StatelessWidget {
  final AppNotification notification;
  final VoidCallback onDelete;

  const _NotifTile({
    required this.notification,
    required this.onDelete,
  });

  // Icon mapping (matches frontend exactly)
  static const _icons = <String, IconData>{
    'message': Icons.chat,
    'purchase': Icons.shopping_cart,
    'like': Icons.favorite,
    'follow': Icons.person_add,
    'friend': Icons.people,
    'system': Icons.info,
    'negotiation': Icons.local_offer,
    'price_drop': Icons.trending_down,
    'welcome': Icons.waving_hand,
    'review': Icons.star,
    'order': Icons.local_shipping,
    'transaction': Icons.receipt_long,
    'badge': Icons.military_tech,
    'admin': Icons.admin_panel_settings,
    'account': Icons.manage_accounts,
    'kyc': Icons.verified_user,
    'admin_message': Icons.campaign,
    'comment': Icons.comment,
    'report': Icons.flag,
  };

  // Color mapping (matches frontend exactly)
  static const _colors = <String, Color>{
    'message': Color(0xFF3B82F6),
    'purchase': Color(0xFF22C55E),
    'like': Color(0xFFEF4444),
    'follow': Color(0xFF6366F1),
    'friend': Color(0xFF8B5CF6),
    'system': Color(0xFFF59E0B),
    'welcome': Color(0xFF10B981),
    'review': Color(0xFFF59E0B),
    'order': Color(0xFF3B82F6),
    'transaction': Color(0xFF22C55E),
    'badge': Color(0xFFA855F7),
    'admin': Color(0xFFEF4444),
    'account': Color(0xFFEF4444),
    'kyc': Color(0xFF3B82F6),
    'admin_message': Color(0xFFEF4444),
    'negotiation': Color(0xFFF97316),
    'comment': Color(0xFF6366F1),
  };

  // Action labels (matches frontend exactly)
  static const _actionLabels = <String, String>{
    'message': 'Voir les messages',
    'like': 'Voir le produit',
    'follow': 'Voir le profil',
    'friend': 'Envoyer un message',
    'purchase': 'Voir la commande',
    'order': 'Voir la commande',
    'transaction': 'Voir les transactions',
    'negotiation': 'Voir la négociation',
    'review': 'Voir mon profil',
    'welcome': 'Compléter mon profil',
    'system': 'En savoir plus',
    'admin': 'En savoir plus',
    'badge': 'Voir mon profil',
    'kyc': 'Voir les paramètres',
    'account': 'Voir les paramètres',
    'comment': 'Voir le produit',
    'price_drop': 'Voir le produit',
  };

  IconData get _icon => _icons[notification.type] ?? Icons.notifications;
  Color get _color => _colors[notification.type] ?? const Color(0xFF6366F1);
  String? get _actionLabel => _actionLabels[notification.type];

  String _resolveUrl() {
    if (notification.actionUrl != null && notification.actionUrl!.isNotEmpty) {
      return notification.actionUrl!;
    }
    switch (notification.type) {
      case 'message':
        return '/messages';
      case 'like':
      case 'comment':
      case 'price_drop':
        return '/feed';
      case 'follow':
        return '/profile';
      case 'friend':
        return '/messages';
      case 'purchase':
      case 'order':
      case 'transaction':
      case 'negotiation':
        return '/transactions';
      case 'review':
      case 'badge':
      case 'report':
        return '/profile';
      case 'welcome':
        return '/profile';
      case 'kyc':
      case 'account':
        return '/settings';
      default:
        return '/feed';
    }
  }

  String _formatTime(String dateStr) {
    final d = DateTime.tryParse(dateStr);
    if (d == null) return '';
    final now = DateTime.now();
    final diff = now.difference(d);
    if (diff.inMinutes < 1) return "À l'instant";
    if (diff.inMinutes < 60) return '${diff.inMinutes} min';
    if (diff.inHours < 24) return '${diff.inHours} h';
    if (diff.inDays < 7) {
      const days = ['dim', 'lun', 'mar', 'mer', 'jeu', 'ven', 'sam'];
      return days[d.weekday % 7];
    }
    return '${d.day}/${d.month}';
  }

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: Key(notification.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: AppColors.danger.withValues(alpha: 0.15),
        child: const Icon(Icons.delete_outline, color: AppColors.danger),
      ),
      onDismissed: (_) => onDelete(),
      child: InkWell(
        onTap: () {
          final notifProv = context.read<NotificationProvider>();
          if (!notification.isRead) notifProv.markAsRead(notification.id);
          
          final url = _resolveUrl();
          // Shell routes (main tabs) must be visited with go(), not push()
          // to avoid duplicate GlobalKey assertion errors in Navigator
          const shellRoutes = ['/feed', '/marketplace', '/sell', '/messages', '/profile'];
          
          if (shellRoutes.contains(url)) {
            context.go(url);
          } else {
            context.push(url);
          }
        },
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: notification.isRead
                ? Colors.transparent
                : AppColors.accentSubtle,
            border: Border(
                bottom: BorderSide(color: AppColors.border, width: 0.5)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ═══ ICON ═══
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: _color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(_icon, color: _color, size: 22),
              ),
              const SizedBox(width: 12),

              // ═══ CONTENT ═══
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      notification.title.isNotEmpty
                          ? notification.title
                          : 'Notification',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 14,
                        fontWeight: notification.isRead
                            ? FontWeight.w500
                            : FontWeight.w600,
                      ),
                    ),
                    if (notification.body.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(notification.body,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 12,
                              height: 1.3)),
                    ],
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Text(_formatTime(notification.createdAt),
                            style: TextStyle(
                                color: AppColors.textMuted,
                                fontSize: 11)),
                        if (_actionLabel != null) ...[
                          const SizedBox(width: 12),
                          Text(_actionLabel!,
                              style: TextStyle(
                                  color: _color,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600)),
                          Icon(Icons.chevron_right,
                              color: _color, size: 14),
                        ],
                      ],
                    ),
                  ],
                ),
              ),

              // ═══ RIGHT SIDE ═══
              Column(
                children: [
                  if (!notification.isRead)
                    Container(
                      width: 8,
                      height: 8,
                      margin: const EdgeInsets.only(top: 6, left: 8),
                      decoration: BoxDecoration(
                        color: _color,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: _color.withValues(alpha: 0.4),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: onDelete,
                    child: Icon(Icons.close,
                        color: AppColors.textMuted.withValues(alpha: 0.4),
                        size: 16),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
