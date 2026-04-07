import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/chat_provider.dart';
import '../providers/notification_provider.dart';
import '../config/theme.dart';

class ShellScreen extends StatefulWidget {
  final Widget child;
  const ShellScreen({super.key, required this.child});

  @override
  State<ShellScreen> createState() => _ShellScreenState();
}

class _ShellScreenState extends State<ShellScreen> {
  int _currentIndex = 0;
  bool _notifLoaded = false;

  static const _routes = ['/feed', '/marketplace', '/sell', '/messages', '/profile'];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final location = GoRouterState.of(context).matchedLocation;
    final idx = _routes.indexOf(location);
    if (idx >= 0 && idx != _currentIndex) setState(() => _currentIndex = idx);

    // Load unread count once when authenticated
    if (!_notifLoaded) {
      final auth = context.read<AuthProvider>();
      if (auth.isAuthenticated) {
        _notifLoaded = true;
        context.read<NotificationProvider>().loadUnreadCount();
      }
    }
  }

  void _onTap(int index) {
    if (index == _currentIndex) return;
    final auth = context.read<AuthProvider>();
    if (!auth.isAuthenticated && [2, 3, 4].contains(index)) {
      context.push('/auth/login');
      return;
    }
    setState(() => _currentIndex = index);
    context.go(_routes[index]);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: widget.child,
      extendBody: true,
      bottomNavigationBar: ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Container(
            decoration: BoxDecoration(
              color: isDark
                  ? AppColors.bgSecondary.withValues(alpha: 0.85)
                  : Colors.white.withValues(alpha: 0.9),
              border: Border(
                top: BorderSide(
                  color: isDark ? AppColors.border : AppColors.borderLightMode,
                ),
              ),
            ),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _NavItem(
                      icon: Icons.home,
                      label: 'Accueil',
                      active: _currentIndex == 0,
                      onTap: () => _onTap(0),
                    ),
                    _NavItem(
                      icon: Icons.explore,
                      label: 'Explorer',
                      active: _currentIndex == 1,
                      onTap: () => _onTap(1),
                    ),
                    // ═══ PUBLISH BUTTON (special) ═══
                    GestureDetector(
                      onTap: () => _onTap(2),
                      child: Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          gradient: AppColors.publishGradient,
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.accent.withValues(alpha: 0.4),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Icon(Icons.add, color: Colors.white, size: 26),
                      ),
                    ),
                    _NavItem(
                      icon: Icons.chat,
                      label: 'Messages',
                      active: _currentIndex == 3,
                      badge: auth.isAuthenticated
                          ? context.watch<ChatProvider>().unreadTotal
                          : 0,
                      onTap: () => _onTap(3),
                    ),
                    _NavItem(
                      icon: Icons.person,
                      label: 'Profil',
                      active: _currentIndex == 4,
                      onTap: () => _onTap(4),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final int badge;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.active,
    this.badge = 0,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 56,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: active
                        ? AppColors.accentSubtle
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    icon,
                    size: 22,
                    color: active ? AppColors.accent : AppColors.textMuted,
                  ),
                ),
                if (badge > 0)
                  Positioned(
                    right: -4,
                    top: -4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        gradient: AppColors.primaryGradient,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      constraints: const BoxConstraints(minWidth: 18),
                      child: Text(
                        badge > 99 ? '99+' : '$badge',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                color: active ? AppColors.accent : AppColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
