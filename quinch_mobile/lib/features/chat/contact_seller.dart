import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router.dart';
import '../../core/network/api_error.dart';
import '../../data/repositories/chat_repository.dart';
import 'chat_providers.dart';

/// « Contacter le vendeur » : demande un premier message (1000 caractères au
/// plus, comme le serveur), ouvre ou retrouve la conversation avec le vendeur,
/// liée à l'annonce si elle est donnée, puis affiche la conversation.
class ContactSellerButton extends ConsumerWidget {
  const ContactSellerButton({
    super.key,
    required this.sellerId,
    this.productId,
    this.productTitle,
    this.label = 'Contacter le vendeur',
    this.filled = true,
  });

  final String sellerId;
  final String? productId;
  final String? productTitle;
  final String label;
  final bool filled;

  Future<void> _contact(BuildContext context) async {
    final conversationId = await showDialog<String>(
      context: context,
      builder: (dialogContext) => _ContactDialog(
        sellerId: sellerId,
        productId: productId,
        productTitle: productTitle,
      ),
    );
    if (conversationId != null && context.mounted) {
      await context.push(chatPath(conversationId));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const icon = Icon(Icons.chat_bubble_outline);
    final text = Text(label);
    return filled
        ? FilledButton.icon(
            onPressed: () => _contact(context),
            icon: icon,
            label: text,
          )
        : OutlinedButton.icon(
            onPressed: () => _contact(context),
            icon: icon,
            label: text,
          );
  }
}

class _ContactDialog extends ConsumerStatefulWidget {
  const _ContactDialog({
    required this.sellerId,
    this.productId,
    this.productTitle,
  });

  final String sellerId;
  final String? productId;
  final String? productTitle;

  @override
  ConsumerState<_ContactDialog> createState() => _ContactDialogState();
}

class _ContactDialogState extends ConsumerState<_ContactDialog> {
  late final TextEditingController _message = TextEditingController(
    text: widget.productTitle == null
        ? 'Bonjour !'
        : 'Bonjour, votre annonce « ${widget.productTitle} » est-elle '
              'toujours disponible ?',
  );
  bool _sending = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _message.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  bool get _valid {
    final length = _message.text.trim().length;
    return length > 0 && length <= ChatRepository.maxFirstMessageLength;
  }

  Future<void> _send() async {
    if (!_valid || _sending) {
      return;
    }
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      final id = await ref
          .read(chatRepositoryProvider)
          .start(
            sellerId: widget.sellerId,
            productId: widget.productId,
            message: _message.text.trim(),
          );
      if (mounted) {
        Navigator.of(context).pop(id);
      }
    } on ApiError catch (e) {
      if (mounted) {
        setState(() {
          _sending = false;
          _error = e.firstFieldError('message') ?? e.userMessage;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Contacter le vendeur'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _message,
            enabled: !_sending,
            minLines: 3,
            maxLines: 6,
            maxLength: ChatRepository.maxFirstMessageLength,
            decoration: const InputDecoration(
              labelText: 'Votre message',
              border: OutlineInputBorder(),
            ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _sending ? null : () => Navigator.of(context).pop(),
          child: const Text('Annuler'),
        ),
        FilledButton(
          onPressed: _valid && !_sending ? _send : null,
          child: _sending
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    semanticsLabel: 'Envoi',
                  ),
                )
              : const Text('Envoyer'),
        ),
      ],
    );
  }
}
