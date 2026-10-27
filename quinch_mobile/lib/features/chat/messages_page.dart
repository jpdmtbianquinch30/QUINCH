import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router.dart';
import '../../core/network/api_error.dart';
import '../../data/models/chat.dart';
import '../../shared/paging/paged_scroll.dart';
import '../../shared/widgets/product_widgets.dart';
import 'chat_format.dart';
import 'chat_providers.dart';

/// Boîte de réception : conversations, dernier message, annonce liée et nombre
/// de messages non lus.
class MessagesPage extends ConsumerStatefulWidget {
  const MessagesPage({super.key});

  @override
  ConsumerState<MessagesPage> createState() => _MessagesPageState();
}

class _MessagesPageState extends ConsumerState<MessagesPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(conversationsProvider.notifier).refresh();
      }
    });
  }

  /// Conversations cochées (mode sélection, pour supprimer plusieurs à la fois).
  final Set<String> _selected = <String>{};
  bool _busy = false;

  bool get _selecting => _selected.isNotEmpty;

  void _toggle(Conversation conversation) {
    setState(() {
      if (!_selected.remove(conversation.id)) {
        _selected.add(conversation.id);
      }
    });
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  /// Supprime les conversations cochées, pour tous leurs participants. Elles ne
  /// disparaissent de la liste qu'une fois la suppression confirmée par le
  /// serveur (la liste est alors rechargée).
  Future<void> _deleteSelected() async {
    if (_busy || _selected.isEmpty) {
      return;
    }
    final ids = _selected.toList();
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          ids.length > 1
              ? 'Supprimer ${ids.length} conversations ?'
              : 'Supprimer cette conversation ?',
        ),
        content: Text(deleteConversationsWarning(ids.length)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) {
      return;
    }
    setState(() => _busy = true);
    try {
      final deleted = await ref
          .read(chatRepositoryProvider)
          .deleteConversations(ids);
      if (!mounted) {
        return;
      }
      _toast(
        deleted.length < ids.length
            ? "Certaines conversations n'ont pas pu être supprimées."
            : (ids.length > 1
                  ? 'Conversations supprimées.'
                  : 'Conversation supprimée.'),
      );
      setState(_selected.clear);
      await ref.read(conversationsProvider.notifier).refresh();
      ref.invalidate(unreadMessagesProvider);
    } on ApiError catch (e) {
      if (mounted) {
        _toast(e.userMessage);
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _open(Conversation conversation) async {
    await context.push(chatPath(conversation.id));
    if (!mounted) {
      return;
    }
    // Les messages ont été lus : on actualise la liste et le compteur.
    ref.read(conversationsProvider.notifier).refresh();
    ref.invalidate(unreadMessagesProvider);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(conversationsProvider);
    final count = _selected.length;
    return PopScope(
      // En sélection, « retour » annule la sélection au lieu de quitter l'écran.
      canPop: !_selecting,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          setState(_selected.clear);
        }
      },
      child: Scaffold(
        appBar: _selecting
            ? AppBar(
                leading: IconButton(
                  tooltip: 'Annuler la sélection',
                  icon: const Icon(Icons.close),
                  onPressed: () => setState(_selected.clear),
                ),
                title: Text('$count sélectionnée${count > 1 ? 's' : ''}'),
                actions: [
                  IconButton(
                    tooltip: 'Supprimer les conversations sélectionnées',
                    icon: const Icon(Icons.delete_outline),
                    onPressed: _busy ? null : _deleteSelected,
                  ),
                ],
              )
            : AppBar(title: const Text('Messages')),
        body: PagedScroll<Conversation>(
          state: state,
          onRefresh: () async {
            await ref.read(conversationsProvider.notifier).refresh();
            ref.invalidate(unreadMessagesProvider);
          },
          onLoadMore: () => ref.read(conversationsProvider.notifier).loadMore(),
          itemBuilder: (context, conversation) => _ConversationTile(
            conversation: conversation,
            selecting: _selecting,
            selected: _selected.contains(conversation.id),
            onTap: () {
              if (_selecting) {
                _toggle(conversation);
              } else {
                _open(conversation);
              }
            },
            onLongPress: () => _toggle(conversation),
          ),
          emptyIcon: Icons.chat_bubble_outline,
          emptyMessage:
              'Aucune conversation pour le moment. Contactez un vendeur depuis '
              'une annonce pour commencer.',
        ),
      ),
    );
  }
}

class _ConversationTile extends StatelessWidget {
  const _ConversationTile({
    required this.conversation,
    required this.selecting,
    required this.selected,
    required this.onTap,
    required this.onLongPress,
  });

  final Conversation conversation;

  /// Vrai si au moins une conversation est cochée (mode sélection).
  final bool selecting;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final other = conversation.otherUser;
    final name = other?.fullName ?? 'Utilisateur';
    final initial = name.isEmpty ? '?' : name.characters.first.toUpperCase();
    final unread = conversation.unreadCount;
    final time = formatInboxTime(
      conversation.lastMessage?.createdAt ?? conversation.lastMessageAt,
      now: DateTime.now(),
    );
    final product = conversation.product;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        onTap: onTap,
        onLongPress: onLongPress,
        selected: selected,
        leading: selecting
            ? Checkbox(value: selected, onChanged: (_) => onTap())
            : CircleAvatar(
                child: other?.avatarUrl == null
                    ? Text(initial)
                    : ClipOval(
                        child: SizedBox(
                          width: 40,
                          height: 40,
                          child: QuinchImage(
                            url: other!.avatarUrl,
                            semanticLabel: name,
                          ),
                        ),
                      ),
              ),
        title: Text(
          name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: unread > 0
              ? theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                )
              : theme.textTheme.titleSmall,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (product != null)
              Text(
                'À propos de : ${product.title}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelSmall,
              ),
            Text(
              messagePreview(conversation.lastMessage),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (time.isNotEmpty) Text(time, style: theme.textTheme.labelSmall),
            if (unread > 0)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Semantics(
                  label: '$unread non lu${unread > 1 ? 's' : ''}',
                  child: Badge(label: Text(unread > 99 ? '99+' : '$unread')),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Enveloppe de l'Accueil avec le nombre de messages non lus (somme des
/// conversations les plus récentes : le serveur ne fournit pas de total).
class MessagesButton extends ConsumerStatefulWidget {
  const MessagesButton({super.key});

  @override
  ConsumerState<MessagesButton> createState() => _MessagesButtonState();
}

class _MessagesButtonState extends ConsumerState<MessagesButton>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.invalidate(unreadMessagesProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    final count = ref.watch(unreadMessagesProvider).valueOrNull ?? 0;
    return IconButton(
      tooltip: count > 0 ? 'Messages ($count non lus)' : 'Messages',
      icon: Badge(
        isLabelVisible: count > 0,
        label: Text(count > 99 ? '99+' : '$count'),
        child: const Icon(Icons.mail_outline),
      ),
      onPressed: () async {
        await context.push(messagesPath);
        ref.invalidate(unreadMessagesProvider);
      },
    );
  }
}
