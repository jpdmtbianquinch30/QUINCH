import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_error.dart';
import '../../data/models/user.dart';
import '../../shared/widgets/product_widgets.dart';
import 'profile_providers.dart';

class BlockedUsersPage extends ConsumerWidget {
  const BlockedUsersPage({super.key});

  Future<void> _unblock(
    BuildContext context,
    WidgetRef ref,
    BlockedUser user,
  ) async {
    try {
      final message = await ref
          .read(safetyRepositoryProvider)
          .unblockUser(user.id);
      ref.invalidate(blockedUsersProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(content: Text(message ?? 'Utilisateur débloqué.')),
          );
      }
    } on ApiError catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(e.userMessage)));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final blocked = ref.watch(blockedUsersProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Utilisateurs bloqués')),
      body: blocked.when(
        loading: () => const Center(
          child: CircularProgressIndicator(semanticsLabel: 'Chargement'),
        ),
        error: (error, stackTrace) => ErrorRetry.fromError(
          error,
          onRetry: () => ref.invalidate(blockedUsersProvider),
        ),
        data: (users) {
          if (users.isEmpty) {
            return const EmptyState(
              icon: Icons.block,
              message: "Vous n'avez bloqué personne.",
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: users.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final user = users[index];
              return ListTile(
                leading: CircleAvatar(
                  child: ClipOval(
                    child: SizedBox(
                      width: 40,
                      height: 40,
                      child: user.avatarUrl == null
                          ? Center(
                              child: Text(
                                user.fullName.isEmpty
                                    ? '?'
                                    : user.fullName.characters.first
                                          .toUpperCase(),
                              ),
                            )
                          : QuinchImage(
                              url: user.avatarUrl,
                              semanticLabel: user.fullName,
                            ),
                    ),
                  ),
                ),
                title: Text(user.fullName),
                trailing: TextButton(
                  onPressed: () => _unblock(context, ref, user),
                  child: const Text('Débloquer'),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
