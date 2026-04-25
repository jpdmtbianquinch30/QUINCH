import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/message.dart';
import '../../providers/auth_provider.dart';
import '../../providers/chat_provider.dart';
import '../../config/theme.dart';
import '../../config/api_config.dart';
import '../../widgets/cached_avatar.dart';

class ChatScreen extends StatefulWidget {
  final String conversationId;
  const ChatScreen({super.key, required this.conversationId});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  Timer? _pollTimer;
  bool _showAttach = false;
  bool _fileSending = false;
  late String _myUserId;

  @override
  void initState() {
    super.initState();

    // Get current user ID ONCE and pass it to the provider
    _myUserId = context.read<AuthProvider>().user?.id ?? '';
    debugPrint('[ChatScreen] My user ID: $_myUserId');

    // Set user ID on ChatProvider so it can compute isMe
    final chat = context.read<ChatProvider>();
    chat.setCurrentUserId(_myUserId);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      chat.loadMessages(widget.conversationId);
      chat.markConversationRead(widget.conversationId);
      // Scroll to bottom after first load
      Future.delayed(const Duration(milliseconds: 600), () {
        if (mounted) _scrollToBottom();
      });
    });

    // Poll for new messages every 5 seconds
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (mounted) {
        context.read<ChatProvider>().loadMessages(widget.conversationId);
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    _controller.clear();
    final ok = await context.read<ChatProvider>().sendMessage(
      widget.conversationId, text,
    );
    if (ok && mounted) _scrollToBottom();
  }

  Future<void> _sendImage() async {
    setState(() { _showAttach = false; _fileSending = true; });
    try {
      final picker = ImagePicker();
      final file = await picker.pickImage(source: ImageSource.gallery, maxWidth: 1200);
      if (file == null || !mounted) { setState(() => _fileSending = false); return; }
      final ok = await context.read<ChatProvider>().sendImage(widget.conversationId, file.path);
      if (ok) { _scrollToBottom(); _showMsg('Image envoyée !'); }
    } catch (_) {
      _showMsg('Erreur lors de l\'envoi', error: true);
    }
    if (mounted) setState(() => _fileSending = false);
  }

  Future<void> _sendCamera() async {
    setState(() { _showAttach = false; _fileSending = true; });
    try {
      final picker = ImagePicker();
      final photo = await picker.pickImage(source: ImageSource.camera, maxWidth: 1200);
      if (photo == null || !mounted) { setState(() => _fileSending = false); return; }
      final ok = await context.read<ChatProvider>().sendImage(widget.conversationId, photo.path);
      if (ok) { _scrollToBottom(); _showMsg('Photo envoyée !'); }
    } catch (_) {
      _showMsg('Erreur lors de l\'envoi', error: true);
    }
    if (mounted) setState(() => _fileSending = false);
  }

  Future<void> _sendVideo() async {
    setState(() { _showAttach = false; _fileSending = true; });
    try {
      final picker = ImagePicker();
      final video = await picker.pickVideo(source: ImageSource.gallery);
      if (video == null || !mounted) { setState(() => _fileSending = false); return; }
      final ok = await context.read<ChatProvider>().sendImage(widget.conversationId, video.path);
      if (ok) { _scrollToBottom(); _showMsg('Vidéo envoyée !'); }
    } catch (_) {
      _showMsg('Erreur lors de l\'envoi', error: true);
    }
    if (mounted) setState(() => _fileSending = false);
  }

  Future<void> _sendDocument() async {
    setState(() { _showAttach = false; _fileSending = true; });
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx', 'xls', 'xlsx', 'ppt', 'pptx', 'txt', 'csv'],
      );
      if (result == null || result.files.isEmpty || !mounted) { setState(() => _fileSending = false); return; }
      final path = result.files.single.path;
      if (path == null) { setState(() => _fileSending = false); return; }
      final ok = await context.read<ChatProvider>().sendImage(widget.conversationId, path);
      if (ok) { _scrollToBottom(); _showMsg('Document envoyé !'); }
    } catch (_) {
      _showMsg('Erreur lors de l\'envoi', error: true);
    }
    if (mounted) setState(() => _fileSending = false);
  }

  Future<void> _sendAnyFile() async {
    setState(() { _showAttach = false; _fileSending = true; });
    try {
      final result = await FilePicker.platform.pickFiles();
      if (result == null || result.files.isEmpty || !mounted) { setState(() => _fileSending = false); return; }
      final path = result.files.single.path;
      if (path == null) { setState(() => _fileSending = false); return; }

      // Check size (20 MB max)
      final size = result.files.single.size;
      if (size > 20 * 1024 * 1024) {
        _showMsg('Le fichier ne doit pas dépasser 20 Mo.', error: true);
        setState(() => _fileSending = false);
        return;
      }

      final ok = await context.read<ChatProvider>().sendImage(widget.conversationId, path);
      if (ok) { _scrollToBottom(); _showMsg('Fichier envoyé !'); }
    } catch (_) {
      _showMsg('Erreur lors de l\'envoi', error: true);
    }
    if (mounted) setState(() => _fileSending = false);
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _showMsg(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(color: Colors.white, fontSize: 13)),
      backgroundColor: error ? AppColors.danger : const Color(0xFF1E293B),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  void _showDropdownMenu() {
    final chat = context.read<ChatProvider>();
    final conv = chat.currentConversation;
    final other = conv?.getOtherUser(_myUserId);
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.bgCard,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(height: 8),
          Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 16),
          if (other?.username != null)
            _MenuOption(icon: Icons.person, label: 'Voir le profil', onTap: () {
              Navigator.pop(ctx);
              context.push('/seller/${other!.username}');
            }),
          _MenuOption(icon: Icons.done_all, label: 'Marquer comme lu', onTap: () {
            Navigator.pop(ctx);
            chat.markConversationRead(widget.conversationId);
            _showMsg('Conversation marquée comme lue');
          }),
          _MenuOption(icon: Icons.notifications_off, label: 'Désactiver les notifs', onTap: () {
            Navigator.pop(ctx);
            _showMsg('Notifications de cette conversation désactivées.');
          }),
          Divider(color: AppColors.border, height: 1),
          _MenuOption(icon: Icons.delete, label: 'Supprimer', color: AppColors.danger, onTap: () {
            Navigator.pop(ctx);
            _confirmDelete();
          }),
          const SizedBox(height: 16),
        ]),
      ),
    );
  }

  void _confirmDelete() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bgCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Supprimer', style: TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w700)),
        content: Text('Supprimer cette conversation ? Cette action est irréversible.',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Annuler', style: TextStyle(color: AppColors.textMuted))),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.read<ChatProvider>().deleteConversation(widget.conversationId);
              context.pop();
              _showMsg('Conversation supprimée');
            },
            child: Text('Supprimer', style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final chat = context.watch<ChatProvider>();
    final convId = widget.conversationId;
    final conversation = chat.currentConversation;
    // Use getOtherUser with our ID to correctly determine the other participant
    final otherUser = conversation?.getOtherUser(_myUserId);
    final messages = chat.messages[convId] ?? [];

    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: AppBar(
        backgroundColor: AppColors.bgSecondary,
        leading: const BackButton(),
        titleSpacing: 0,
        title: GestureDetector(
          onTap: () {
            if (otherUser?.username != null) context.push('/seller/${otherUser!.username}');
          },
          child: Row(children: [
            if (otherUser != null) ...[
              Stack(children: [
                CachedAvatar(url: otherUser.avatarUrl, size: 36, name: otherUser.fullName ?? 'U'),
                if (otherUser.isOnline)
                  Positioned(right: 0, bottom: 0,
                    child: Container(width: 10, height: 10,
                      decoration: BoxDecoration(color: AppColors.online, shape: BoxShape.circle,
                        border: Border.all(color: AppColors.bgSecondary, width: 2)))),
              ]),
              const SizedBox(width: 10),
            ],
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(otherUser?.fullName ?? 'Chat',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                if (otherUser?.isOnline == true)
                  Text('En ligne', style: TextStyle(fontSize: 11, color: AppColors.online))
                else
                  Text('Hors ligne', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
                if (conversation?.product != null)
                  Text(conversation!.product!.title, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 10, color: AppColors.accent)),
              ]),
            ),
          ]),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.more_vert, color: AppColors.textSecondary, size: 20),
            onPressed: _showDropdownMenu,
          ),
        ],
      ),

      body: Column(
        children: [
          // ═══ PRODUCT CONTEXT CARD ═══
          if (conversation?.product != null)
            GestureDetector( 
              onTap: () => context.push('/product/${conversation!.product!.slug}'),
              child: Container(
                margin: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.bgCard,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.accent.withValues(alpha: 0.3)),
                ),
                child: Row(children: [
                  Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.accentSubtle,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      conversation!.product!.isService ? Icons.handyman : Icons.shopping_bag,
                      color: AppColors.accent, size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Conversation à propos de',
                      style: TextStyle(color: AppColors.textMuted, fontSize: 10)),
                    Text(conversation.product!.title, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
                    Text(conversation.product!.displayPrice,
                      style: TextStyle(color: AppColors.accent, fontSize: 12, fontWeight: FontWeight.w600)),
                  ])),
                  Icon(Icons.chevron_right, color: AppColors.textMuted, size: 20),
                ]),
              ),
            ),

          // ═══ MESSAGES LIST ═══
          Expanded(
            child: chat.isLoading && messages.isEmpty
                ? Center(child: CircularProgressIndicator(color: AppColors.accent))
                : messages.isEmpty
                    ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.chat_bubble_outline, size: 48, color: AppColors.textMuted.withValues(alpha: 0.5)),
                        const SizedBox(height: 12),
                        Text('Aucun message', style: TextStyle(color: AppColors.textMuted, fontSize: 14)),
                        const SizedBox(height: 4),
                        Text('Envoyez le premier message !', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                      ]))
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(12),
                        itemCount: messages.length,
                        itemBuilder: (_, i) {
                          final msg = messages[i];
                          final showDate = i == 0 || !_sameDay(messages[i - 1].createdAt, msg.createdAt);
                          return Column(children: [
                            if (showDate) _DateSeparator(date: msg.createdAt),
                            if (msg.type == 'system')
                              _SystemMessage(message: msg)
                            else
                              _MessageBubble(message: msg, myUserId: _myUserId),
                          ]);
                        },
                      ),
          ),

          // ═══ ATTACHMENT MENU ═══
          if (_showAttach)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.bgSecondary,
                border: Border(top: BorderSide(color: AppColors.border)),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text('Envoyer un fichier', style: TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w600)),
                  GestureDetector(
                    onTap: () => setState(() => _showAttach = false),
                    child: Icon(Icons.close, size: 18, color: AppColors.textMuted),
                  ),
                ]),
                const SizedBox(height: 14),
                Row(children: [
                  _AttachOption(icon: Icons.image, label: 'Photos', color: AppColors.accent, onTap: _sendImage),
                  const SizedBox(width: 14),
                  _AttachOption(icon: Icons.camera_alt, label: 'Caméra', color: const Color(0xFF8B5CF6), onTap: _sendCamera),
                  const SizedBox(width: 14),
                  _AttachOption(icon: Icons.description, label: 'Documents', color: AppColors.warning, onTap: _sendDocument),
                  const SizedBox(width: 14),
                  _AttachOption(icon: Icons.videocam, label: 'Vidéos', color: AppColors.danger, onTap: _sendVideo),
                  const SizedBox(width: 14),
                  _AttachOption(icon: Icons.folder, label: 'Autres', color: const Color(0xFF8B5CF6), onTap: _sendAnyFile),
                ]),
                const SizedBox(height: 8),
                Row(children: [
                  Icon(Icons.info_outline, size: 12, color: AppColors.textMuted),
                  const SizedBox(width: 4),
                  Text('Taille max : 20 Mo', style: TextStyle(color: AppColors.textMuted, fontSize: 10)),
                ]),
              ]),
            ),

          // ═══ INPUT BAR ═══
          Container(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
            decoration: BoxDecoration(
              color: AppColors.bgSecondary,
              border: Border(top: BorderSide(color: AppColors.border)),
            ),
            child: SafeArea(
              top: false,
              child: Row(children: [
                // Attach button
                GestureDetector(
                  onTap: _fileSending ? null : () => setState(() => _showAttach = !_showAttach),
                  child: Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(
                      color: _showAttach ? AppColors.accentSubtle : AppColors.bgInput,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: _fileSending
                        ? const Padding(
                            padding: EdgeInsets.all(10),
                            child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accent),
                          )
                        : Icon(Icons.attach_file, size: 20,
                            color: _showAttach ? AppColors.accent : AppColors.textMuted),
                  ),
                ),
                const SizedBox(width: 8),

                // Text input
                Expanded(
                  child: TextField(
                    controller: _controller,
                    style: TextStyle(color: AppColors.textPrimary, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Écrire un message...',
                      hintStyle: TextStyle(color: AppColors.textMuted, fontSize: 13),
                      filled: true, fillColor: AppColors.bgInput,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    ),
                    maxLines: 4, minLines: 1,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _send(),
                  ),
                ),
                const SizedBox(width: 8),

                // Send button
                GestureDetector(
                  onTap: _send,
                  child: Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(
                      gradient: AppColors.primaryGradient,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [BoxShadow(color: AppColors.accent.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 2))],
                    ),
                    child: const Icon(Icons.send, color: Colors.white, size: 18),
                  ),
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  bool _sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;
}

// ═══════════════════════════════════════════════════════════════
// MESSAGE BUBBLE
// ═══════════════════════════════════════════════════════════════
class _MessageBubble extends StatelessWidget {
  final Message message;
  final String myUserId;
  const _MessageBubble({required this.message, required this.myUserId});

  @override
  Widget build(BuildContext context) {
    // Determine isMe: compare sender_id with current user ID
    // This is the same logic as the Angular frontend: msg.sender_id === this.auth.user()?.id
    final isMe = message.isMe || message.senderId == myUserId;

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Flexible(
            child: Container(
              constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
              padding: _isImage ? EdgeInsets.zero : const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isMe ? AppColors.accent : AppColors.bgCard,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isMe ? 16 : 4),
                  bottomRight: Radius.circular(isMe ? 4 : 16),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // ── Quote tag ──
                  if (_isQuote)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      margin: const EdgeInsets.only(bottom: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.request_quote, size: 14, color: isMe ? Colors.white70 : AppColors.accent),
                        const SizedBox(width: 4),
                        Text('Demande de devis', style: TextStyle(color: isMe ? Colors.white70 : AppColors.accent, fontSize: 11, fontWeight: FontWeight.w600)),
                      ]),
                    ),

                  // ── Image ──
                  if (_isImage && _resolvedMediaUrl.isNotEmpty)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: CachedNetworkImage(
                        imageUrl: _resolvedMediaUrl,
                        width: 220, fit: BoxFit.cover,
                        placeholder: (_, __) => Container(
                          width: 220, height: 160,
                          color: AppColors.bgInput,
                          child: const Center(child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accent)),
                        ),
                        errorWidget: (_, __, ___) => Container(
                          width: 220, height: 100, color: AppColors.bgInput,
                          child: Icon(Icons.broken_image, color: AppColors.textMuted),
                        ),
                      ),
                    ),

                  // ── File attachment ──
                  if (_isFile)
                    GestureDetector(
                      onTap: () => _openFile(context),
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: isMe ? 0.15 : 0.05),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Container(
                            width: 40, height: 40,
                            decoration: BoxDecoration(
                              color: (isMe ? Colors.white : AppColors.accent).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                              Icon(Icons.description, size: 18, color: isMe ? Colors.white : AppColors.accent),
                              if (_fileExtension.isNotEmpty)
                                Text(_fileExtension, style: TextStyle(color: isMe ? Colors.white70 : AppColors.accent, fontSize: 7, fontWeight: FontWeight.w700)),
                            ]),
                          ),
                          const SizedBox(width: 10),
                          Flexible(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(message.fileName ?? 'Fichier', maxLines: 1, overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: isMe ? Colors.white : AppColors.textPrimary, fontSize: 12, fontWeight: FontWeight.w600)),
                            if (_fileSize.isNotEmpty)
                              Text(_fileSize, style: TextStyle(color: isMe ? Colors.white60 : AppColors.textMuted, fontSize: 10)),
                          ])),
                          const SizedBox(width: 8),
                          Icon(Icons.download, size: 18, color: isMe ? Colors.white70 : AppColors.textMuted),
                        ]),
                      ),
                    ),

                  // ── Audio ──
                  if (message.isAudio)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.play_arrow, size: 28, color: isMe ? Colors.white : AppColors.accent),
                        const SizedBox(width: 6),
                        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Container(
                            width: 120, height: 4,
                            decoration: BoxDecoration(
                              color: (isMe ? Colors.white : AppColors.accent).withValues(alpha: 0.3),
                              borderRadius: BorderRadius.circular(2)),
                          ),
                          const SizedBox(height: 4),
                          Text(_audioDuration, style: TextStyle(color: isMe ? Colors.white60 : AppColors.textMuted, fontSize: 10)),
                        ]),
                      ]),
                    ),

                  // ── Text ──
                  if (message.content != null && message.content!.isNotEmpty && !_isImage && !_isFile)
                    Padding(
                      padding: _isImage ? const EdgeInsets.fromLTRB(14, 6, 14, 0) : EdgeInsets.zero,
                      child: Text(
                        _isQuote ? _quoteBody : message.content!,
                        style: TextStyle(color: isMe ? Colors.white : AppColors.textPrimary, fontSize: 14, height: 1.4),
                      ),
                    ),

                  const SizedBox(height: 2),
                  // ── Footer: time + read status ──
                  Padding(
                    padding: _isImage ? const EdgeInsets.fromLTRB(14, 0, 14, 8) : EdgeInsets.zero,
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Text(_formatTime(message.createdAt),
                        style: TextStyle(color: isMe ? Colors.white60 : AppColors.textMuted, fontSize: 10)),
                      if (isMe) ...[
                        const SizedBox(width: 3),
                        Icon(message.isRead ? Icons.done_all : Icons.done,
                          size: 13, color: message.isRead ? Colors.white : (isMe ? Colors.white60 : AppColors.textMuted)),
                      ],
                    ]),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  bool get _isImage => message.isImage || (message.metadata?['mime_type']?.toString().startsWith('image/') ?? false);
  bool get _isFile => message.isFile;
  bool get _isQuote => message.body?.startsWith('[Demande de devis]') ?? false;

  String get _quoteBody => (message.body ?? '').replaceAll('[Demande de devis] ', '').replaceAll('[Demande de devis]', '');

  String get _fileExtension => (message.metadata?['extension'] ?? '').toString().toUpperCase();

  /// Resolve media URL for images
  String get _resolvedMediaUrl {
    final url = message.mediaUrl;
    if (url == null || url.isEmpty) return '';
    return ApiConfig.resolveUrl(url);
  }

  String get _fileSize {
    final bytes = message.metadata?['file_size'];
    if (bytes == null) return '';
    final b = bytes is int ? bytes : int.tryParse(bytes.toString()) ?? 0;
    if (b < 1024) return '$b o';
    if (b < 1024 * 1024) return '${(b / 1024).toStringAsFixed(1)} Ko';
    return '${(b / (1024 * 1024)).toStringAsFixed(1)} Mo';
  }

  String get _audioDuration {
    final secs = message.audioDuration ?? 0;
    final s = secs.round();
    final m = s ~/ 60;
    final sec = s % 60;
    return '$m:${sec.toString().padLeft(2, '0')}';
  }

  void _openFile(BuildContext context) async {
    final url = message.fileUrl ?? message.mediaUrl;
    if (url == null) return;
    final uri = Uri.tryParse(ApiConfig.resolveUrl(url));
    if (uri != null) {
      try {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } catch (_) {}
    }
  }

  String _formatTime(DateTime dt) => '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
}

// ═══════════════════════════════════════════════════════════════
// SYSTEM MESSAGE
// ═══════════════════════════════════════════════════════════════
class _SystemMessage extends StatelessWidget {
  final Message message;
  const _SystemMessage({required this.message});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.bgCard,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.people, size: 14, color: AppColors.textMuted),
            const SizedBox(width: 6),
            Flexible(child: Text(message.body ?? '', style: TextStyle(color: AppColors.textMuted, fontSize: 12))),
          ]),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// DATE SEPARATOR
// ═══════════════════════════════════════════════════════════════
class _DateSeparator extends StatelessWidget {
  final DateTime date;
  const _DateSeparator({required this.date});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    String label;
    if (_sameDay(date, now)) {
      label = "Aujourd'hui";
    } else if (_sameDay(date, now.subtract(const Duration(days: 1)))) {
      label = 'Hier';
    } else {
      label = '${date.day}/${date.month}/${date.year}';
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(color: AppColors.bgCard, borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.border)),
          child: Text(label, style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
        ),
      ),
    );
  }

  bool _sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;
}

// ═══════════════════════════════════════════════════════════════
// ATTACHMENT OPTION
// ═══════════════════════════════════════════════════════════════
class _AttachOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _AttachOption({required this.icon, required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 48, height: 48,
          decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(14)),
          child: Icon(icon, color: color, size: 22),
        ),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(color: AppColors.textSecondary, fontSize: 10)),
      ]),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// MENU OPTION
// ═══════════════════════════════════════════════════════════════
class _MenuOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;
  final VoidCallback onTap;
  _MenuOption({required this.icon, required this.label, this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final effectiveColor = color ?? AppColors.textPrimary;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(children: [
          Icon(icon, size: 20, color: effectiveColor),
          const SizedBox(width: 14),
          Text(label, style: TextStyle(color: effectiveColor, fontSize: 15)),
        ]),
      ),
    );
  }
}
