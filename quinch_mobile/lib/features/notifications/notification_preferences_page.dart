import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_error.dart';
import '../../data/models/notifications.dart';
import '../../shared/widgets/product_widgets.dart';
import 'notification_providers.dart';

/// Préférences de notification : dans l'application et par email. Il n'y a PAS de
/// réglage « push » : le serveur n'envoie aucune notification sur l'appareil.
class NotificationPreferencesPage extends ConsumerWidget {
  const NotificationPreferencesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(notificationPreferencesProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Préférences de notification')),
      body: prefs.when(
        loading: () => const Center(
          child: CircularProgressIndicator(semanticsLabel: 'Chargement'),
        ),
        error: (error, stackTrace) => ErrorRetry.fromError(
          error,
          onRetry: () => ref.invalidate(notificationPreferencesProvider),
        ),
        data: (list) => _Form(initial: list),
      ),
    );
  }
}

class _Form extends ConsumerStatefulWidget {
  const _Form({required this.initial});

  final List<NotificationPreference> initial;

  @override
  ConsumerState<_Form> createState() => _FormState();
}

class _FormState extends ConsumerState<_Form> {
  late List<NotificationPreference> _prefs = widget.initial;
  bool _saving = false;

  Future<void> _change(int index, NotificationPreference updated) async {
    if (_saving) {
      return;
    }
    final previous = _prefs;
    final next = <NotificationPreference>[...previous]..[index] = updated;
    setState(() {
      _prefs = next;
      _saving = true;
    });
    try {
      await ref.read(notificationRepositoryProvider).updatePreferences(next);
    } on ApiError catch (e) {
      if (mounted) {
        setState(() => _prefs = previous);
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(e.userMessage)));
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (_prefs.isEmpty) {
      return const EmptyState(
        icon: Icons.tune,
        message: 'Aucune préférence à régler.',
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _prefs.length + 1,
      separatorBuilder: (context, index) => const Divider(height: 24),
      itemBuilder: (context, index) {
        if (index == 0) {
          return Text(
            "Choisissez où recevoir chaque type de notification. Les notifications sur l'appareil ne sont pas disponibles pour le moment.",
            style: theme.textTheme.bodySmall,
          );
        }
        final pref = _prefs[index - 1];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(pref.label, style: theme.textTheme.titleSmall),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text("Dans l'application"),
              value: pref.inAppEnabled,
              onChanged: _saving
                  ? null
                  : (v) => _change(index - 1, pref.copyWith(inAppEnabled: v)),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Par email'),
              value: pref.emailEnabled,
              onChanged: _saving
                  ? null
                  : (v) => _change(index - 1, pref.copyWith(emailEnabled: v)),
            ),
          ],
        );
      },
    );
  }
}
