import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router.dart';
import '../../core/session/session_controller.dart';
import '../../core/session/session_state.dart';

/// Écran « Compte » : identité et accès au profil, aux annonces, au support
/// et aux paramètres.
class AccountPage extends ConsumerWidget {
  const AccountPage({super.key});

  Future<void> _confirmLogout(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Se déconnecter ?'),
        content: const Text(
          'Vous devrez vous reconnecter pour utiliser QUINCH.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Se déconnecter'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(sessionControllerProvider.notifier).logout();
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionControllerProvider);
    final user = session is SessionAuthenticated ? session.user : null;
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Compte')),
      body: ListView(
        children: [
          if (user != null)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(user.fullName, style: theme.textTheme.headlineSmall),
                  if (user.username.isNotEmpty) Text('@${user.username}'),
                  const SizedBox(height: 4),
                  Text(user.email),
                ],
              ),
            ),
          ListTile(
            leading: const Icon(Icons.notifications_outlined),
            title: const Text('Notifications'),
            onTap: () => context.push(notificationsPath),
          ),
          ListTile(
            leading: const Icon(Icons.workspace_premium_outlined),
            title: const Text('Premium'),
            onTap: () => context.push(premiumPath),
          ),
          ListTile(
            leading: const Icon(Icons.emoji_events_outlined),
            title: const Text('Classements'),
            onTap: () => context.push(rankingsPath),
          ),
          ListTile(
            leading: const Icon(Icons.edit_outlined),
            title: const Text('Modifier mon profil'),
            onTap: () => context.push(editProfilePath),
          ),
          ListTile(
            leading: const Icon(Icons.add_circle_outline),
            title: const Text('Publier une annonce'),
            onTap: () => context.push(sellPath),
          ),
          ListTile(
            leading: const Icon(Icons.storefront_outlined),
            title: const Text('Mes annonces'),
            onTap: () => context.push(myProductsPath),
          ),
          ListTile(
            leading: const Icon(Icons.block),
            title: const Text('Utilisateurs bloqués'),
            onTap: () => context.push(blockedUsersPath),
          ),
          ListTile(
            leading: const Icon(Icons.support_agent_outlined),
            title: const Text('Signaler un problème'),
            onTap: () => context.push(supportPath),
          ),
          ListTile(
            leading: const Icon(Icons.settings_outlined),
            title: const Text('Paramètres'),
            onTap: () => context.push(settingsPath),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Se déconnecter'),
            onTap: () => _confirmLogout(context, ref),
          ),
        ],
      ),
    );
  }
}
