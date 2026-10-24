import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format/time_ago.dart';
import '../../core/network/api_error.dart';
import '../../data/models/notifications.dart';
import '../../shared/widgets/product_widgets.dart';
import 'notification_providers.dart';

class NotificationDetailPage extends ConsumerWidget {
  const NotificationDetailPage({super.key, required this.id});

  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(notificationDetailProvider(id));
    return Scaffold(
      appBar: AppBar(title: const Text('Notification')),
      body: detail.when(
        loading: () => const Center(
          child: CircularProgressIndicator(semanticsLabel: 'Chargement'),
        ),
        error: (error, stackTrace) => ErrorRetry.fromError(
          error,
          onRetry: () => ref.invalidate(notificationDetailProvider(id)),
        ),
        data: (data) => _Body(detail: data, id: id),
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.detail, required this.id});

  final NotificationDetail detail;
  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final n = detail.notification;
    final target = appPathForNotification(n.actionUrl);
    final created = n.createdAt;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(n.title, style: theme.textTheme.titleLarge),
        if (created != null) ...[
          const SizedBox(height: 4),
          Text(formatDateTimeFr(created), style: theme.textTheme.bodySmall),
        ],
        if (n.body.isNotEmpty) ...[
          const SizedBox(height: 16),
          SelectableText(n.body),
        ],
        if (target != null) ...[
          const SizedBox(height: 16),
          FilledButton.tonal(
            onPressed: () => context.push(target),
            child: const Text('Voir'),
          ),
        ],
        if (detail.appeal != null) ...[
          const SizedBox(height: 24),
          _AppealCard(appeal: detail.appeal!, isReply: detail.isReply),
        ],
        if (detail.canContest) ...[
          const SizedBox(height: 24),
          OutlinedButton(
            onPressed: () async {
              final sent = await showDialog<bool>(
                context: context,
                builder: (dialogContext) =>
                    _ContestDialog(id: id, isReply: detail.isReply),
              );
              if (sent == true) {
                ref.invalidate(notificationDetailProvider(id));
              }
            },
            child: Text(
              detail.isReply ? 'Répondre' : 'Contester cette décision',
            ),
          ),
        ],
      ],
    );
  }
}

class _AppealCard extends StatelessWidget {
  const _AppealCard({required this.appeal, required this.isReply});

  final NotificationAppeal appeal;
  final bool isReply;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final status = appeal.isPending ? "En cours d'examen" : 'Traitée';
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isReply ? 'Votre réponse' : 'Votre contestation',
              style: theme.textTheme.titleSmall,
            ),
            const SizedBox(height: 4),
            Text(appeal.message),
            const SizedBox(height: 8),
            Text('Statut : $status', style: theme.textTheme.bodySmall),
            if (appeal.response != null && appeal.response!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text("Réponse de l'équipe", style: theme.textTheme.titleSmall),
              const SizedBox(height: 4),
              SelectableText(appeal.response!),
            ],
          ],
        ),
      ),
    );
  }
}

class _ContestDialog extends ConsumerStatefulWidget {
  const _ContestDialog({required this.id, required this.isReply});

  final String id;
  final bool isReply;

  @override
  ConsumerState<_ContestDialog> createState() => _ContestDialogState();
}

class _ContestDialogState extends ConsumerState<_ContestDialog> {
  final _message = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _message.text.trim();
    if (text.length < 10) {
      setState(
        () => _error = 'Expliquez votre démarche en au moins 10 caractères.',
      );
      return;
    }
    if (text.length > 2000) {
      setState(() => _error = '2000 caractères maximum.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final message = await ref
          .read(notificationRepositoryProvider)
          .contest(widget.id, text);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(message ?? 'Votre message a été envoyé à l\'équipe.'),
          ),
        );
      Navigator.of(context).pop(true);
    } on ApiError catch (e) {
      if (mounted) {
        setState(() {
          _error = e.firstFieldError('message') ?? e.userMessage;
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.isReply ? 'Répondre à l\'équipe' : 'Contester cette décision',
      ),
      content: TextField(
        controller: _message,
        enabled: !_loading,
        minLines: 3,
        maxLines: 6,
        maxLength: 2000,
        decoration: InputDecoration(
          labelText: 'Votre message',
          alignLabelWithHint: true,
          border: const OutlineInputBorder(),
          errorText: _error,
        ),
      ),
      actions: [
        TextButton(
          onPressed: _loading ? null : () => Navigator.of(context).pop(false),
          child: const Text('Annuler'),
        ),
        FilledButton(
          onPressed: _loading ? null : _send,
          child: const Text('Envoyer'),
        ),
      ],
    );
  }
}
