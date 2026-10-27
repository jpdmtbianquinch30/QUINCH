import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router.dart';
import '../../core/features/feature_availability.dart';
import '../../core/format/fcfa.dart';
import '../../core/json/json_utils.dart';
import '../../core/media/chat_attachment.dart';
import '../../core/network/api_error.dart';
import '../../core/platform/image_picker.dart';
import '../../core/platform/url_opener.dart';
import '../../core/providers.dart';
import '../../core/session/session_controller.dart';
import '../../core/session/session_state.dart';
import '../../data/models/chat.dart';
import '../../data/repositories/chat_repository.dart';
import '../../shared/widgets/product_widgets.dart';
import 'chat_format.dart';
import 'chat_providers.dart';

/// Un message en cours d'envoi, ou dont l'envoi a échoué (jamais perdu : il reste
/// visible avec « Réessayer » et « Supprimer »).
class _PendingMessage {
  _PendingMessage.text(this.text) : attachment = null;

  _PendingMessage.file(ChatAttachment file)
    : attachment = file,
      text = file.name;

  /// Texte du message, ou nom du fichier pour une pièce jointe.
  final String text;
  final ChatAttachment? attachment;
  bool sending = true;
  bool failed = false;
  String? error;

  /// Avancement de l'envoi d'un fichier (0 à 1).
  double progress = 0;
}

enum _Phase { loading, ready, failed }

/// Conversation (texte). Il n'existe pas de temps réel côté serveur : tant que
/// l'écran est visible et l'application au premier plan, les nouveaux messages
/// sont demandés à intervalle régulier (comme sur le web).
class ChatPage extends ConsumerStatefulWidget {
  const ChatPage({super.key, required this.conversationId});

  final String conversationId;

  /// Intervalle de consultation (8 s, comme le web).
  static const pollInterval = Duration(seconds: 8);

  @override
  ConsumerState<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends ConsumerState<ChatPage>
    with WidgetsBindingObserver {
  final _input = TextEditingController();

  _Phase _phase = _Phase.loading;
  ApiError? _loadError;
  ChatUser? _other;
  ChatProductRef? _product;
  List<ChatMessage> _messages = <ChatMessage>[];
  final List<_PendingMessage> _pending = <_PendingMessage>[];

  /// Horodatage du dernier message connu, renvoyé tel quel à `messages/since`.
  String? _after;
  Timer? _timer;
  bool _polling = false;
  bool _deleting = false;
  bool _connectionLost = false;
  bool _foreground = true;

  ChatRepository get _repo => ref.read(chatRepositoryProvider);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    _foreground = lifecycle == null || lifecycle == AppLifecycleState.resumed;
    _input.addListener(() => setState(() {}));
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _input.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final resumed = state == AppLifecycleState.resumed;
    _foreground = resumed;
    if (resumed) {
      if (_phase == _Phase.ready) {
        _poll();
        _startTimer();
      }
    } else {
      _timer?.cancel();
      _timer = null;
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(ChatPage.pollInterval, (_) => _poll());
  }

  Future<void> _load() async {
    setState(() {
      _phase = _Phase.loading;
      _loadError = null;
    });
    try {
      final detail = await _repo.conversation(widget.conversationId);
      if (!mounted) {
        return;
      }
      setState(() {
        _other = detail.conversation.otherUser;
        _product = detail.conversation.product;
        _messages = _sorted(detail.messages);
        _after = _messages.isEmpty ? null : _messages.last.createdAtRaw;
        _phase = _Phase.ready;
      });
      if (_foreground) {
        _startTimer();
      }
    } on ApiError catch (e) {
      if (mounted) {
        setState(() {
          _loadError = e;
          _phase = _Phase.failed;
        });
      }
    }
  }

  Future<void> _poll() async {
    // Pas de consultation si l'écran est recouvert (autre écran ouvert dessus),
    // si l'application est en arrière-plan ou si une consultation est en cours.
    if (!mounted ||
        _polling ||
        !_foreground ||
        _phase != _Phase.ready ||
        !TickerMode.of(context)) {
      return;
    }
    _polling = true;
    try {
      final result = await _repo.messagesSince(
        widget.conversationId,
        after: _after,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _merge(result.messages);
        if (result.messages.isNotEmpty) {
          _after = _messages.last.createdAtRaw ?? _after;
        }
        _other = result.otherUser ?? _other;
        _connectionLost = false;
      });
    } on ApiError {
      if (mounted) {
        setState(() => _connectionLost = true);
      }
    } finally {
      _polling = false;
    }
  }

  List<ChatMessage> _sorted(List<ChatMessage> messages) {
    final copy = List<ChatMessage>.of(messages);
    copy.sort((a, b) {
      final ta = a.createdAt;
      final tb = b.createdAt;
      if (ta == null || tb == null) {
        return 0;
      }
      return ta.compareTo(tb);
    });
    return copy;
  }

  /// Ajoute les messages inconnus (déduplication par identifiant : un message
  /// envoyé par nous revient aussi par la consultation périodique).
  void _merge(List<ChatMessage> incoming) {
    final known = _messages.map((m) => m.id).toSet();
    final fresh = incoming.where((m) => !known.contains(m.id)).toList();
    if (fresh.isNotEmpty) {
      _messages = _sorted(<ChatMessage>[..._messages, ...fresh]);
    }
  }

  bool get _canSend {
    final length = _input.text.trim().length;
    return length > 0 && length <= ChatRepository.maxMessageLength;
  }

  Future<void> _send() async {
    if (!_canSend) {
      return;
    }
    final pending = _PendingMessage.text(_input.text.trim());
    _input.clear();
    setState(() => _pending.add(pending));
    await _deliver(pending);
  }

  Future<void> _deliver(_PendingMessage pending) async {
    setState(() {
      pending.sending = true;
      pending.failed = false;
      pending.error = null;
    });
    try {
      final attachment = pending.attachment;
      final sent = attachment == null
          ? await _repo.sendMessage(widget.conversationId, pending.text)
          : await _repo.sendFile(
              widget.conversationId,
              attachment,
              onProgress: (value) {
                if (mounted) {
                  setState(() => pending.progress = value);
                }
              },
            );
      if (!mounted) {
        return;
      }
      setState(() {
        _pending.remove(pending);
        _merge(<ChatMessage>[sent]);
      });
    } on ApiError catch (e) {
      if (mounted) {
        if (pending.attachment?.kind == ChatAttachmentKind.video) {
          // Le serveur répond « bientôt disponible » quand l'envoi de fichiers
          // est coupé : on cesse de proposer la vidéo.
          ref
              .read(featureAvailabilityProvider.notifier)
              .report(AppFeature.chatFile, error: e);
        }
        setState(() {
          pending.sending = false;
          pending.failed = true;
          pending.error =
              e.firstFieldError('file') ??
              e.firstFieldError('body') ??
              e.userMessage;
        });
      }
    } on Exception {
      // Fichier disparu ou illisible avant l'envoi.
      if (mounted) {
        setState(() {
          pending.sending = false;
          pending.failed = true;
          pending.error = 'fichier illisible';
        });
      }
    }
  }

  void _discard(_PendingMessage pending) =>
      setState(() => _pending.remove(pending));

  Future<bool> _confirm({
    required String title,
    required String message,
    String confirmLabel = 'Supprimer',
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  /// Appui long sur un message : copier son texte et, pour mes propres messages,
  /// le supprimer. (Le texte n'est pas sélectionnable à la main : un appui long
  /// sur du texte sélectionnable empêcherait ce menu.)
  Future<void> _showMessageActions(
    ChatMessage message, {
    required bool mine,
  }) async {
    final canCopy =
        (message.isText || message.isProductTag) && message.body.isNotEmpty;
    if (!canCopy && !mine) {
      return;
    }
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (canCopy)
              ListTile(
                leading: const Icon(Icons.copy_outlined),
                title: const Text('Copier le texte'),
                onTap: () => Navigator.of(sheetContext).pop('copy'),
              ),
            if (mine)
              ListTile(
                leading: const Icon(Icons.delete_outline),
                title: const Text('Supprimer le message'),
                onTap: () => Navigator.of(sheetContext).pop('delete'),
              ),
          ],
        ),
      ),
    );
    if (!mounted) {
      return;
    }
    if (action == 'copy') {
      await Clipboard.setData(ClipboardData(text: message.body));
      if (mounted) {
        _toast('Message copié.');
      }
    } else if (action == 'delete') {
      await _confirmDeleteMessage(message);
    }
  }

  /// Supprime un de mes messages, pour tous les participants. Le message ne
  /// disparaît de l'écran qu'une fois la suppression confirmée par le serveur.
  Future<void> _confirmDeleteMessage(ChatMessage message) async {
    if (_deleting) {
      return;
    }
    final ok = await _confirm(
      title: 'Supprimer ce message ?',
      message: deleteMessageWarning,
    );
    if (!ok || !mounted) {
      return;
    }
    setState(() => _deleting = true);
    try {
      await _repo.deleteMessage(widget.conversationId, message.id);
      if (mounted) {
        setState(() {
          _messages = _messages.where((m) => m.id != message.id).toList();
        });
      }
    } on ApiError catch (e) {
      if (mounted) {
        _toast(e.userMessage);
      }
    } finally {
      if (mounted) {
        setState(() => _deleting = false);
      }
    }
  }

  /// Supprime toute la conversation, pour les deux participants, puis revient à
  /// la boîte de réception (qui se recharge).
  Future<void> _confirmDeleteConversation() async {
    if (_deleting) {
      return;
    }
    final ok = await _confirm(
      title: 'Supprimer cette conversation ?',
      message: deleteConversationWarning,
    );
    if (!ok || !mounted) {
      return;
    }
    setState(() => _deleting = true);
    try {
      await _repo.deleteConversation(widget.conversationId);
      if (mounted) {
        _toast('Conversation supprimée.');
        context.pop();
      }
    } on ApiError catch (e) {
      if (mounted) {
        _toast(e.userMessage);
        setState(() => _deleting = false);
      }
    }
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  /// Joindre une photo (toujours) ou une vidéo (seulement si le serveur ne l'a
  /// pas signalée indisponible), depuis la galerie.
  Future<void> _attach() async {
    final videoAllowed = ref.read(featureEnabledProvider(AppFeature.chatFile));
    ChatAttachmentKind? kind = ChatAttachmentKind.image;
    if (videoAllowed) {
      kind = await showModalBottomSheet<ChatAttachmentKind>(
        context: context,
        builder: (sheetContext) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_outlined),
                title: const Text('Photo'),
                onTap: () =>
                    Navigator.of(sheetContext).pop(ChatAttachmentKind.image),
              ),
              ListTile(
                leading: const Icon(Icons.videocam_outlined),
                title: const Text('Vidéo'),
                onTap: () =>
                    Navigator.of(sheetContext).pop(ChatAttachmentKind.video),
              ),
            ],
          ),
        ),
      );
    }
    if (kind == null || !mounted) {
      return;
    }
    ChatAttachment? picked;
    try {
      if (kind == ChatAttachmentKind.image) {
        final image = await ref.read(imagePickProvider)();
        picked = image == null
            ? null
            : ChatAttachment(
                path: image.path,
                name: image.name,
                sizeBytes: image.sizeBytes,
                kind: kind,
              );
      } else {
        final video = await ref.read(videoPickProvider)();
        picked = video == null
            ? null
            : ChatAttachment(
                path: video.path,
                name: video.name,
                sizeBytes: video.sizeBytes,
                kind: kind,
              );
      }
    } on Exception {
      if (mounted) {
        _toast("Impossible d'ouvrir la galerie.");
      }
      return;
    }
    if (picked == null || !mounted) {
      return;
    }
    final problem = validateChatAttachment(picked);
    if (problem != null) {
      _toast(problem);
      return;
    }
    final pending = _PendingMessage.file(picked);
    setState(() => _pending.add(pending));
    await _deliver(pending);
  }

  /// Ouvre une pièce jointe reçue avec l'application du téléphone. Adresse
  /// acceptée si elle est en https, ou en http vers notre propre serveur (debug).
  Future<void> _openFile(ChatMessage message) async {
    final resolved = ref.read(mediaUrlProvider).resolve(message.fileUrl);
    final uri = resolved == null ? null : Uri.tryParse(resolved);
    final apiHost = ref.read(appConfigProvider).apiHost;
    final allowed =
        uri != null &&
        (uri.scheme == 'https' ||
            (uri.scheme == 'http' && uri.host == apiHost));
    if (!allowed) {
      _toast('Ce fichier ne peut pas être ouvert.');
      return;
    }
    final opened = await ref.read(urlOpenerProvider)(uri);
    if (!opened && mounted) {
      _toast("Impossible d'ouvrir ce fichier.");
    }
  }

  void _openImage(ChatMessage message) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog.fullscreen(
        child: Stack(
          children: [
            Positioned.fill(
              child: InteractiveViewer(
                child: QuinchImage(
                  url: message.fileUrl,
                  fit: BoxFit.contain,
                  semanticLabel: 'Photo',
                ),
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: IconButton.filled(
                tooltip: 'Fermer',
                onPressed: () => Navigator.of(dialogContext).pop(),
                icon: const Icon(Icons.close),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final other = _other;
    return Scaffold(
      appBar: AppBar(
        title: GestureDetector(
          onTap: other?.username == null
              ? null
              : () => context.push(sellerPath(other!.username!)),
          child: Text(other?.fullName ?? 'Conversation'),
        ),
        actions: [
          if (_phase == _Phase.ready)
            PopupMenuButton<String>(
              tooltip: "Options de la conversation",
              enabled: !_deleting,
              onSelected: (_) => _confirmDeleteConversation(),
              itemBuilder: (context) => const [
                PopupMenuItem<String>(
                  value: 'delete',
                  child: Text('Supprimer la conversation'),
                ),
              ],
            ),
        ],
      ),
      body: switch (_phase) {
        _Phase.loading => const Center(
          child: CircularProgressIndicator(
            semanticsLabel: 'Chargement de la conversation',
          ),
        ),
        _Phase.failed => _buildFailure(),
        _Phase.ready => _buildConversation(),
      },
    );
  }

  Widget _buildFailure() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _loadError?.userMessage ??
                  "Impossible d'ouvrir cette conversation.",
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton(onPressed: _load, child: const Text('Réessayer')),
          ],
        ),
      ),
    );
  }

  Widget _buildConversation() {
    final session = ref.watch(sessionControllerProvider);
    final myId = session is SessionAuthenticated ? session.user.id : '';
    final now = DateTime.now();

    // Liste inversée : le plus récent en bas, sans gestion de défilement.
    final entries = <Widget>[
      for (final pending in _pending.reversed)
        _PendingBubble(
          pending: pending,
          onRetry: () => _deliver(pending),
          onDiscard: () => _discard(pending),
        ),
      for (final message in _messages.reversed)
        _MessageBubble(
          message: message,
          mine: message.senderId == myId,
          time: formatMessageTime(message.createdAt, now: now),
          onOpenImage: () => _openImage(message),
          onOpenFile: () => _openFile(message),
          onLongPress: () =>
              _showMessageActions(message, mine: message.senderId == myId),
        ),
    ];

    return Column(
      children: [
        if (_connectionLost)
          const _Banner(
            'Connexion perdue. Nouvelle tentative automatique…',
            icon: Icons.wifi_off,
          ),
        if (_product != null) _ProductHeader(product: _product!),
        Expanded(
          child: entries.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'Aucun message pour le moment. Écrivez le premier !',
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : ListView(
                  reverse: true,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  children: entries,
                ),
        ),
        _Composer(
          controller: _input,
          canSend: _canSend,
          onSend: _send,
          onAttach: _attach,
        ),
      ],
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner(this.text, {required this.icon});

  final String text;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      color: scheme.errorContainer,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 18, color: scheme.onErrorContainer),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, style: TextStyle(color: scheme.onErrorContainer)),
          ),
        ],
      ),
    );
  }
}

/// Annonce liée à la conversation (titre et prix), ouvrable.
class _ProductHeader extends StatelessWidget {
  const _ProductHeader({required this.product});

  final ChatProductRef product;

  @override
  Widget build(BuildContext context) {
    final price = formatLinkedPrice(product.price);
    final slug = product.slug;
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: ListTile(
        dense: true,
        leading: const Icon(Icons.sell_outlined),
        title: Text(
          product.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: price == null ? null : Text(price),
        trailing: slug == null ? null : const Icon(Icons.chevron_right),
        onTap: slug == null ? null : () => context.push(productPath(slug)),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.message,
    required this.mine,
    required this.time,
    required this.onOpenImage,
    required this.onOpenFile,
    required this.onLongPress,
  });

  final ChatMessage message;
  final bool mine;
  final String time;
  final VoidCallback onOpenImage;
  final VoidCallback onOpenFile;

  /// Appui long : copier le texte, ou supprimer (mes propres messages).
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final supported =
        message.isText || message.isProductTag || message.isAttachment;
    final slug = message.metadata['product_slug'];
    final productTitle = message.metadata['product_title'];
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.78,
        ),
        child: GestureDetector(
          onLongPress: onLongPress,
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 3),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: mine
                  ? scheme.primaryContainer
                  : scheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (message.isProductTag && productTitle is String)
                  _ProductTagCard(
                    metadata: message.metadata,
                    onTap: slug is String
                        ? () => context.push(productPath(slug))
                        : null,
                  ),
                if (message.isImage)
                  GestureDetector(
                    onTap: onOpenImage,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: SizedBox(
                        width: 220,
                        height: 180,
                        child: QuinchImage(
                          url: message.fileUrl,
                          semanticLabel: 'Photo envoyée',
                        ),
                      ),
                    ),
                  )
                else if (message.isVideo || message.isFile)
                  InkWell(
                    onTap: onOpenFile,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          message.isVideo
                              ? Icons.videocam_outlined
                              : Icons.insert_drive_file_outlined,
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                message.fileName ??
                                    (message.isVideo ? 'Vidéo' : 'Fichier'),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (message.fileSize != null)
                                Text(
                                  formatFileSize(message.fileSize!),
                                  style: theme.textTheme.labelSmall,
                                ),
                              Text(
                                'Ouvrir',
                                style: theme.textTheme.labelMedium?.copyWith(
                                  color: scheme.primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  )
                else if (supported)
                  Text(message.body)
                else
                  Text(
                    unsupportedMessageText,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                if (time.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(time, style: theme.textTheme.labelSmall),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PendingBubble extends StatelessWidget {
  const _PendingBubble({
    required this.pending,
    required this.onRetry,
    required this.onDiscard,
  });

  final _PendingMessage pending;
  final VoidCallback onRetry;
  final VoidCallback onDiscard;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Align(
      alignment: Alignment.centerRight,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.78,
        ),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 3),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: pending.failed
                ? scheme.errorContainer
                : scheme.primaryContainer.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (pending.attachment != null)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      pending.attachment!.kind == ChatAttachmentKind.video
                          ? Icons.videocam_outlined
                          : Icons.photo_outlined,
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        pending.text,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                )
              else
                Text(pending.text),
              const SizedBox(height: 4),
              if (pending.sending && pending.attachment != null) ...[
                LinearProgressIndicator(
                  value: pending.progress,
                  semanticsLabel: 'Envoi du fichier',
                ),
                Text(
                  'Envoi… ${(pending.progress * 100).round()} %',
                  style: theme.textTheme.labelSmall,
                ),
              ] else if (pending.sending)
                Text('Envoi…', style: theme.textTheme.labelSmall)
              else if (pending.failed) ...[
                Text(
                  'Non envoyé : ${pending.error ?? 'erreur inconnue'}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: scheme.onErrorContainer,
                  ),
                ),
                // Wrap et non Row : sur un écran étroit, les deux boutons passent
                // à la ligne au lieu de déborder.
                Wrap(
                  alignment: WrapAlignment.end,
                  children: [
                    TextButton(
                      onPressed: onRetry,
                      child: const Text('Réessayer'),
                    ),
                    TextButton(
                      onPressed: onDiscard,
                      child: const Text('Supprimer'),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.canSend,
    required this.onSend,
    required this.onAttach,
  });

  final TextEditingController controller;
  final bool canSend;
  final VoidCallback onSend;
  final VoidCallback onAttach;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            IconButton(
              tooltip: 'Joindre un fichier',
              onPressed: onAttach,
              icon: const Icon(Icons.attach_file),
            ),
            Expanded(
              child: TextField(
                controller: controller,
                minLines: 1,
                maxLines: 5,
                maxLength: ChatRepository.maxMessageLength,
                textInputAction: TextInputAction.newline,
                keyboardType: TextInputType.multiline,
                decoration: const InputDecoration(
                  hintText: 'Votre message',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ),
            IconButton.filled(
              tooltip: 'Envoyer',
              onPressed: canSend ? onSend : null,
              icon: const Icon(Icons.send),
            ),
          ],
        ),
      ),
    );
  }
}

/// Carte de l'annonce liée à un message de contact : image, titre et prix, tels
/// que renvoyés par le serveur dans `metadata`. Un champ absent n'est pas
/// affiché.
class _ProductTagCard extends StatelessWidget {
  const _ProductTagCard({required this.metadata, required this.onTap});

  final Map<String, dynamic> metadata;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final title = asString(metadata['product_title']);
    final image = asStringOrNull(metadata['product_image']);
    final rawPrice = metadata['product_price'];
    final price = rawPrice == null ? null : formatFcfa(asDouble(rawPrice));
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            border: Border.all(color: theme.colorScheme.outlineVariant),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (image != null) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: SizedBox(
                    width: 56,
                    height: 56,
                    child: QuinchImage(url: image, semanticLabel: title),
                  ),
                ),
                const SizedBox(width: 10),
              ],
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelLarge,
                    ),
                    if (price != null)
                      Text(price, style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
