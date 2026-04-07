import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../models/conversation.dart';
import '../../providers/chat_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/cart_provider.dart';
import '../../services/api_service.dart';
import '../../config/theme.dart';
import '../../widgets/cached_avatar.dart';

class ConversationsScreen extends StatefulWidget {
  const ConversationsScreen({super.key});

  @override
  State<ConversationsScreen> createState() => _ConversationsScreenState();
}

class _ConversationsScreenState extends State<ConversationsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  final _searchCtrl = TextEditingController();
  String _searchQuery = '';
  bool _showSearch = false;

  // Transactions state
  List<dynamic> _purchases = [];
  List<dynamic> _sales = [];
  Map<String, dynamic> _stats = {};
  bool _loadingTx = true;
  String _txTab = 'purchases';
  String _statusFilter = 'all';
  String? _expandedTxId;
  String? _actionLoading;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ChatProvider>().loadConversations();
      _loadTransactions();
    });
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  // ═══════════════════════════════════════════════════
  // MESSAGES HELPERS
  // ═══════════════════════════════════════════════════

  List<Conversation> _filteredConversations(List<Conversation> all) {
    if (_searchQuery.isEmpty) return all;
    final q = _searchQuery.toLowerCase();
    return all.where((c) {
      final name = (c.otherUser?.fullName ?? '').toLowerCase();
      final username = (c.otherUser?.username ?? '').toLowerCase();
      final product = (c.product?.title ?? '').toLowerCase();
      final lastMsg = (c.lastMessage?.body ?? '').toLowerCase();
      return name.contains(q) || username.contains(q) || product.contains(q) || lastMsg.contains(q);
    }).toList();
  }

  String _formatTime(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return '';
    final d = DateTime.tryParse(dateStr);
    if (d == null) return '';
    final diff = DateTime.now().difference(d);
    if (diff.inMinutes < 1) return "À l'instant";
    if (diff.inMinutes < 60) return '${diff.inMinutes} min';
    if (diff.inHours < 24) return '${diff.inHours} h';
    if (diff.inDays < 7) {
      const days = ['Dim', 'Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam'];
      return days[d.weekday % 7];
    }
    if (diff.inDays < 365) {
      const months = ['jan', 'fév', 'mar', 'avr', 'mai', 'juin', 'juil', 'août', 'sep', 'oct', 'nov', 'déc'];
      return '${d.day} ${months[d.month - 1]}';
    }
    return '${d.day}/${d.month}/${d.year}';
  }

  String _getPreview(Conversation conv) {
    final msg = conv.lastMessage;
    if (msg == null) return 'Aucun message';
    switch (msg.type) {
      case 'image': return 'Image';
      case 'file': return msg.fileName ?? 'Fichier';
      case 'audio': return 'Message vocal';
      case 'offer': return 'Offre';
      case 'system': return (msg.body ?? '').length > 40 ? msg.body!.substring(0, 40) : msg.body ?? '';
      default:
        final body = msg.body ?? '';
        return body.length > 50 ? '${body.substring(0, 50)}…' : body;
    }
  }

  bool _isLastMessageMine(Conversation conv) {
    final myId = context.read<AuthProvider>().user?.id;
    return conv.lastMessage?.senderId == myId?.toString();
  }

  void _deleteConversation(Conversation conv) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bgCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Supprimer la conversation', style: TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w700)),
        content: Text('Cette action est irréversible. Supprimer ?', style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Annuler', style: TextStyle(color: AppColors.textMuted))),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.read<ChatProvider>().deleteConversation(conv.id);
              _showMsg('Conversation supprimée');
            },
            child: const Text('Supprimer', style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════
  // TRANSACTIONS HELPERS
  // ═══════════════════════════════════════════════════

  Future<void> _loadTransactions() async {
    try {
      final api = context.read<ApiService>();
      final res = await api.get('/products/transactions/history');
      final data = res.data;
      if (mounted) {
        setState(() {
          _purchases = (data['purchases']?['data'] ?? data['purchases'] ?? []) as List;
          _sales = (data['sales']?['data'] ?? data['sales'] ?? []) as List;
          _stats = data['stats'] ?? {};
          _loadingTx = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingTx = false);
    }
  }

  List<dynamic> get _filteredTx {
    List<dynamic> items = _txTab == 'purchases' ? _purchases : _sales;
    if (_statusFilter != 'all') {
      items = items.where((tx) => tx['payment_status'] == _statusFilter).toList();
    }
    return items;
  }

  Future<void> _updateTxStatus(dynamic tx, String status) async {
    setState(() => _actionLoading = tx['id']?.toString());
    try {
      final api = context.read<ApiService>();
      await api.put('/products/transactions/${tx['id']}/status', data: {'status': status});
      const msgs = {
        'processing': 'Commande acceptée !', 'shipped': 'Commande expédiée !',
        'delivered': 'Commande livrée !', 'completed': 'Réception confirmée !', 'cancelled': 'Commande annulée.',
      };
      _showMsg(msgs[status] ?? 'Statut mis à jour !');
      await _loadTransactions();
    } catch (_) {
      _showMsg('Erreur lors de la mise à jour.', error: true);
    }
    if (mounted) setState(() => _actionLoading = null);
  }

  String _formatPrice(dynamic amount) {
    if (amount == null) return '0 F';
    final n = amount is num ? amount : num.tryParse(amount.toString()) ?? 0;
    return '${NumberFormat('#,###', 'fr').format(n)} F';
  }

  String _txTimeAgo(String? dateStr) {
    if (dateStr == null) return '';
    final d = DateTime.tryParse(dateStr);
    if (d == null) return '';
    final diff = DateTime.now().difference(d);
    if (diff.inMinutes < 1) return "à l'instant";
    if (diff.inMinutes < 60) return 'il y a ${diff.inMinutes}min';
    if (diff.inHours < 24) return 'il y a ${diff.inHours}h';
    if (diff.inDays < 7) return 'il y a ${diff.inDays}j';
    return DateFormat('dd MMM', 'fr').format(d);
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

  // ═══════════════════════════════════════════════════
  // BUILD
  // ═══════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final chat = context.watch<ChatProvider>();
    final cart = context.watch<CartProvider>();

    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: AppBar(
        backgroundColor: AppColors.bgSecondary,
        title: _showSearch
            ? TextField(
                controller: _searchCtrl, autofocus: true,
                style: TextStyle(color: AppColors.textPrimary, fontSize: 15),
                decoration: InputDecoration(
                  hintText: 'Rechercher...', hintStyle: TextStyle(color: AppColors.textMuted, fontSize: 14),
                  border: InputBorder.none,
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(icon: Icon(Icons.close, size: 18, color: AppColors.textMuted),
                          onPressed: () => setState(() { _searchCtrl.clear(); _searchQuery = ''; }))
                      : null,
                ),
                onChanged: (v) => setState(() => _searchQuery = v),
              )
            : const Text('Messages', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 20)),
        actions: [
          // Cart icon
          Stack(children: [
            IconButton(
              icon: Icon(Icons.shopping_cart_outlined, size: 22, color: AppColors.textSecondary),
              onPressed: () => context.push('/cart'),
            ),
            if (cart.count > 0)
              Positioned(right: 4, top: 4,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(gradient: AppColors.primaryGradient, borderRadius: BorderRadius.circular(10)),
                  constraints: const BoxConstraints(minWidth: 16),
                  child: Text('${cart.count}', style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700), textAlign: TextAlign.center),
                ),
              ),
          ]),
          // Search
          IconButton(
            icon: Icon(_showSearch ? Icons.close : Icons.search, size: 22, color: AppColors.textSecondary),
            onPressed: () => setState(() { _showSearch = !_showSearch; if (!_showSearch) { _searchCtrl.clear(); _searchQuery = ''; } }),
          ),
        ],
        bottom: TabBar(
          controller: _tabCtrl,
          labelColor: AppColors.accent,
          unselectedLabelColor: AppColors.textMuted,
          indicatorColor: AppColors.accent,
          indicatorWeight: 3,
          labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
          tabs: [
            Tab(child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.chat, size: 18),
              const SizedBox(width: 6),
              const Text('Messages'),
              if (chat.unreadTotal > 0) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(gradient: AppColors.primaryGradient, borderRadius: BorderRadius.circular(10)),
                  child: Text('${chat.unreadTotal}', style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700)),
                ),
              ],
            ])),
            Tab(child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.receipt_long, size: 18),
              const SizedBox(width: 6),
              const Text('Transactions'),
              if ((_stats['pending_purchases'] ?? 0) + (_stats['pending_sales'] ?? 0) > 0) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(color: AppColors.warning, borderRadius: BorderRadius.circular(10)),
                  child: Text('${(_stats['pending_purchases'] ?? 0) + (_stats['pending_sales'] ?? 0)}',
                    style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700)),
                ),
              ],
            ])),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabCtrl,
        children: [
          // ═══ TAB 1: MESSAGES ═══
          _buildMessagesTab(chat),
          // ═══ TAB 2: TRANSACTIONS ═══
          _buildTransactionsTab(),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════
  // TAB 1: MESSAGES
  // ═══════════════════════════════════════════════════
  Widget _buildMessagesTab(ChatProvider chat) {
    final conversations = _filteredConversations(chat.conversations);

    if (chat.isLoading && chat.conversations.isEmpty) {
      return const Center(child: CircularProgressIndicator(color: AppColors.accent));
    }
    if (conversations.isEmpty) return _buildEmptyMessages();

    return RefreshIndicator(
      color: AppColors.accent,
      onRefresh: () => chat.loadConversations(),
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 4),
        itemCount: conversations.length,
        itemBuilder: (_, i) => _buildConversationTile(conversations[i]),
      ),
    );
  }

  Widget _buildConversationTile(Conversation conv) {
    final hasUnread = conv.unreadCount > 0;

    return Dismissible(
      key: Key('conv_${conv.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight, padding: const EdgeInsets.only(right: 24),
        color: AppColors.danger, child: const Icon(Icons.delete, color: Colors.white, size: 24),
      ),
      confirmDismiss: (_) async { _deleteConversation(conv); return false; },
      child: InkWell(
        onTap: () => context.push('/messages/${conv.id}'),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: hasUnread ? AppColors.accentSubtle : Colors.transparent,
            border: Border(bottom: BorderSide(color: AppColors.border)),
          ),
          child: Row(children: [
            Stack(children: [
              CachedAvatar(url: conv.otherUser?.avatarUrl, size: 48, name: conv.otherUser?.fullName ?? '?'),
              if (conv.otherUser?.isOnline == true)
                Positioned(right: 0, bottom: 0,
                  child: Container(width: 14, height: 14,
                    decoration: BoxDecoration(color: AppColors.online, shape: BoxShape.circle,
                      border: Border.all(color: AppColors.bgPrimary, width: 2)))),
            ]),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text(conv.otherUser?.fullName ?? 'Utilisateur', maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: AppColors.textPrimary, fontSize: 15, fontWeight: hasUnread ? FontWeight.w700 : FontWeight.w500))),
                Text(_formatTime(conv.lastMessageAt ?? conv.lastMessage?.createdAtStr),
                  style: TextStyle(color: hasUnread ? AppColors.accent : AppColors.textMuted, fontSize: 11)),
              ]),
              const SizedBox(height: 3),
              if (conv.product != null)
                Padding(padding: const EdgeInsets.only(bottom: 2),
                  child: Text('${conv.product!.title}', maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: AppColors.accent, fontSize: 11))),
              Row(children: [
                if (_isLastMessageMine(conv))
                  Padding(padding: const EdgeInsets.only(right: 4),
                    child: Icon(Icons.done_all, size: 14,
                      color: conv.lastMessage?.isRead == true ? AppColors.accent : AppColors.textMuted)),
                Expanded(child: Text(_getPreview(conv), maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: hasUnread ? AppColors.textPrimary : AppColors.textMuted,
                    fontSize: 13, fontWeight: hasUnread ? FontWeight.w500 : FontWeight.w400))),
                if (hasUnread)
                  Container(margin: const EdgeInsets.only(left: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(gradient: AppColors.primaryGradient, borderRadius: BorderRadius.circular(10)),
                    child: Text('${conv.unreadCount}', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700))),
              ]),
            ])),
          ]),
        ),
      ),
    );
  }

  Widget _buildEmptyMessages() {
    return Center(child: Padding(padding: const EdgeInsets.all(32),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(width: 80, height: 80,
          decoration: BoxDecoration(color: AppColors.accentSubtle, borderRadius: BorderRadius.circular(20)),
          child: const Icon(Icons.forum, size: 36, color: AppColors.accent)),
        const SizedBox(height: 20),
        Text(_searchQuery.isNotEmpty ? 'Aucun résultat pour "$_searchQuery"' : 'Aucune conversation',
          style: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Text(_searchQuery.isNotEmpty ? 'Essayez un autre terme' : 'Contactez un vendeur pour démarrer',
          textAlign: TextAlign.center, style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
      ]),
    ));
  }

  // ═══════════════════════════════════════════════════
  // TAB 2: TRANSACTIONS (redesigned for clarity)
  // ═══════════════════════════════════════════════════
  Widget _buildTransactionsTab() {
    return RefreshIndicator(
      color: AppColors.accent,
      onRefresh: _loadTransactions,
      child: _loadingTx
          ? const Center(child: CircularProgressIndicator(color: AppColors.accent))
          : ListView(padding: const EdgeInsets.all(14), children: [

              // ── Achats / Ventes Toggle ──
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(color: AppColors.bgCard, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
                child: Row(children: [
                  _buildTabBtn('Mes achats', Icons.shopping_bag_outlined, _purchases.length, _txTab == 'purchases', () => setState(() => _txTab = 'purchases')),
                  const SizedBox(width: 4),
                  _buildTabBtn('Mes ventes', Icons.storefront_outlined, _sales.length, _txTab == 'sales', () => setState(() => _txTab = 'sales')),
                ]),
              ),
              const SizedBox(height: 14),

              // ── Summary card ──
              _buildSummaryCard(),
              const SizedBox(height: 14),

              // ── Status filters (simple, readable) ──
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(children: [
                  for (final e in [
                    ['all', 'Tout', Icons.list, AppColors.textSecondary],
                    ['pending', 'En attente', Icons.schedule, AppColors.warning],
                    ['processing', 'En cours', Icons.autorenew, const Color(0xFF3B82F6)],
                    ['completed', 'Terminé', Icons.check_circle, AppColors.success],
                    ['cancelled', 'Annulé', Icons.cancel, AppColors.danger],
                  ])
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: GestureDetector(
                        onTap: () => setState(() => _statusFilter = e[0] as String),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: _statusFilter == e[0] ? (e[3] as Color).withValues(alpha: 0.15) : AppColors.bgCard,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: _statusFilter == e[0] ? (e[3] as Color).withValues(alpha: 0.5) : AppColors.border),
                          ),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            Icon(e[2] as IconData, size: 14, color: _statusFilter == e[0] ? e[3] as Color : AppColors.textMuted),
                            const SizedBox(width: 6),
                            Text(e[1] as String, style: TextStyle(
                              color: _statusFilter == e[0] ? e[3] as Color : AppColors.textMuted,
                              fontSize: 12, fontWeight: _statusFilter == e[0] ? FontWeight.w600 : FontWeight.w500)),
                          ]),
                        ),
                      ),
                    ),
                ]),
              ),
              const SizedBox(height: 14),

              // ── Transactions list ──
              if (_filteredTx.isEmpty)
                _buildEmptyTx()
              else
                for (final tx in _filteredTx) _buildTxCard(tx),

              const SizedBox(height: 80),
            ]),
    );
  }

  Widget _buildTabBtn(String label, IconData icon, int count, bool active, VoidCallback onTap) {
    return Expanded(child: GestureDetector(onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: active ? AppColors.accent : Colors.transparent,
          borderRadius: BorderRadius.circular(10)),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, size: 18, color: active ? Colors.white : AppColors.textMuted),
          const SizedBox(width: 8),
          Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
            color: active ? Colors.white : AppColors.textMuted)),
          if (count > 0) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: active ? Colors.white.withValues(alpha: 0.25) : AppColors.bgInput,
                borderRadius: BorderRadius.circular(8)),
              child: Text('$count', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
                color: active ? Colors.white : AppColors.textMuted)),
            ),
          ],
        ]),
      ),
    ));
  }

  Widget _buildSummaryCard() {
    final isBuying = _txTab == 'purchases';
    final total = isBuying ? _stats['total_spent'] : _stats['total_earned'];
    final completed = _stats[isBuying ? 'completed_purchases' : 'completed_sales'] ?? 0;
    final pending = _stats[isBuying ? 'pending_purchases' : 'pending_sales'] ?? 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: isBuying
            ? [const Color(0xFF1E1B4B), const Color(0xFF312E81)]
            : [const Color(0xFF064E3B), const Color(0xFF065F46)]),
        borderRadius: BorderRadius.circular(16)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(isBuying ? Icons.shopping_bag : Icons.storefront, color: Colors.white.withValues(alpha: 0.8), size: 20),
          const SizedBox(width: 8),
          Text(isBuying ? 'Total dépensé' : 'Total gagné',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 13)),
        ]),
        const SizedBox(height: 8),
        Text(_formatPrice(total),
          style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w800)),
        const SizedBox(height: 12),
        Row(children: [
          _buildMiniStat(Icons.check_circle, '$completed', 'Terminées', AppColors.success),
          const SizedBox(width: 16),
          _buildMiniStat(Icons.schedule, '$pending', 'En attente', AppColors.warning),
          const SizedBox(width: 16),
          _buildMiniStat(Icons.receipt_long, '${(isBuying ? _purchases : _sales).length}', 'Total', Colors.white),
        ]),
      ]),
    );
  }

  Widget _buildMiniStat(IconData icon, String value, String label, Color color) {
    return Row(children: [
      Icon(icon, size: 14, color: color.withValues(alpha: 0.8)),
      const SizedBox(width: 4),
      Text('$value ', style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w700)),
      Text(label, style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 11)),
    ]);
  }

  Widget _buildEmptyTx() {
    final isBuying = _txTab == 'purchases';
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 50),
      child: Column(children: [
        Container(
          width: 70, height: 70,
          decoration: BoxDecoration(color: AppColors.bgCard, borderRadius: BorderRadius.circular(20)),
          child: Icon(isBuying ? Icons.shopping_bag_outlined : Icons.storefront_outlined, size: 32, color: AppColors.textMuted),
        ),
        const SizedBox(height: 16),
        Text(isBuying ? 'Aucun achat pour le moment' : 'Aucune vente pour le moment',
          style: TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Text(
          isBuying
              ? 'Quand vous achetez un produit,\nil apparaîtra ici.'
              : 'Quand quelqu\'un achète votre produit,\nil apparaîtra ici.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.textMuted, fontSize: 13, height: 1.5)),
      ]),
    );
  }

  Widget _buildTxCard(dynamic tx) {
    final id = tx['id']?.toString() ?? '';
    final expanded = _expandedTxId == id;
    final status = tx['payment_status'] ?? 'pending';
    final isSale = _txTab == 'sales';
    final amount = tx['amount'];
    final product = tx['product'];
    final otherUser = isSale ? tx['buyer'] : tx['seller'];

    // Status info
    final si = _statusInfo(status);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.bgCard, borderRadius: BorderRadius.circular(16),
        border: Border.all(color: expanded ? (si['color'] as Color).withValues(alpha: 0.4) : AppColors.border)),
      child: Column(children: [
        // ── Main row (always visible) ──
        InkWell(
          onTap: () => setState(() => _expandedTxId = expanded ? null : id),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(children: [
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                // Status icon
                Container(width: 44, height: 44,
                  decoration: BoxDecoration(
                    color: (si['color'] as Color).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12)),
                  child: Icon(si['icon'] as IconData, color: si['color'] as Color, size: 22)),
                const SizedBox(width: 12),
                // Product + person
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(product?['title'] ?? 'Produit', maxLines: 2, overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Row(children: [
                    Icon(isSale ? Icons.person_outline : Icons.store_outlined, size: 13, color: AppColors.textMuted),
                    const SizedBox(width: 4),
                    Expanded(child: Text(
                      '${isSale ? "Acheteur" : "Vendeur"}: ${otherUser?['full_name'] ?? otherUser?['username'] ?? 'Inconnu'}',
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 12))),
                  ]),
                ])),
              ]),

              const SizedBox(height: 10),

              // Amount + status + time
              Row(children: [
                // Amount
                Text('${isSale ? '+' : ''}${_formatPrice(amount)} CFA',
                  style: TextStyle(color: isSale ? AppColors.success : AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w800)),
                const Spacer(),
                // Status badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: (si['color'] as Color).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(si['icon'] as IconData, size: 12, color: si['color'] as Color),
                    const SizedBox(width: 4),
                    Text(si['label'] as String, style: TextStyle(color: si['color'] as Color, fontSize: 11, fontWeight: FontWeight.w600)),
                  ]),
                ),
              ]),

              // Time
              const SizedBox(height: 6),
              Row(children: [
                Icon(Icons.access_time, size: 12, color: AppColors.textMuted),
                const SizedBox(width: 4),
                Text(_txTimeAgo(tx['created_at']), style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
                const Spacer(),
                Icon(expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, size: 18, color: AppColors.textMuted),
                Text(expanded ? 'Moins' : 'Détails', style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
              ]),
            ]),
          ),
        ),

        // ── Expanded detail ──
        if (expanded) _buildTxDetail(tx, status, isSale, otherUser),
      ]),
    );
  }

  Widget _buildTxDetail(dynamic tx, String status, bool isSale, dynamic otherUser) {
    final isLoading = _actionLoading == tx['id']?.toString();

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Divider(color: AppColors.border, height: 1),
        const SizedBox(height: 12),

        // ── Progress steps ──
        _buildProgressSteps(status),
        const SizedBox(height: 14),

        // ── Details ──
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: AppColors.bgInput, borderRadius: BorderRadius.circular(12)),
          child: Column(children: [
            _infoRow('Référence', '#${(tx['id'] ?? '').toString().substring(0, (tx['id'] ?? '').toString().length.clamp(0, 8)).toUpperCase()}'),
            _infoRow('Montant', '${_formatPrice(tx['amount'])} CFA'),
            if (tx['quantity'] != null)
              _infoRow('Quantité', '${tx['quantity']}'),
            if (tx['payment_method'] != null)
              _infoRow('Paiement', _paymentLabel(tx['payment_method'])),
            if (tx['delivery_type'] != null)
              _infoRow('Livraison', _deliveryLabel(tx['delivery_type'])),
          ]),
        ),
        const SizedBox(height: 12),

        // ── Action buttons (clear labels) ──
        if (status == 'cancelled' || status == 'completed')
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: (status == 'completed' ? AppColors.success : AppColors.danger).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10)),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(status == 'completed' ? Icons.verified : Icons.block,
                color: status == 'completed' ? AppColors.success : AppColors.danger, size: 16),
              const SizedBox(width: 6),
              Text(status == 'completed' ? 'Transaction terminée avec succès' : 'Transaction annulée',
                style: TextStyle(
                  color: status == 'completed' ? AppColors.success : AppColors.danger,
                  fontWeight: FontWeight.w600, fontSize: 13)),
            ]),
          )
        else if (isSale && status == 'pending')
          Column(children: [
            Text('L\'acheteur attend votre confirmation.', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: _actionBtn('Accepter la commande', Icons.check_circle, AppColors.success, isLoading, () => _updateTxStatus(tx, 'processing'))),
              const SizedBox(width: 8),
              Expanded(child: _actionBtn('Refuser', Icons.cancel, AppColors.danger, isLoading, () => _updateTxStatus(tx, 'cancelled'))),
            ]),
          ])
        else if (isSale && status == 'processing')
          Column(children: [
            Text('Préparez la commande et marquez-la comme expédiée.', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: _actionBtn('Marquer expédié', Icons.local_shipping, const Color(0xFF3B82F6), isLoading, () => _updateTxStatus(tx, 'shipped'))),
              const SizedBox(width: 8),
              Expanded(child: _actionBtn('Annuler', Icons.cancel, AppColors.danger, isLoading, () => _updateTxStatus(tx, 'cancelled'))),
            ]),
          ])
        else if (!isSale && status == 'pending')
          Column(children: [
            Text('Le vendeur n\'a pas encore confirmé votre commande.', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
            const SizedBox(height: 8),
            _actionBtn('Annuler ma commande', Icons.cancel, AppColors.danger, isLoading, () => _updateTxStatus(tx, 'cancelled')),
          ])
        else if (!isSale && (status == 'processing' || status == 'shipped' || status == 'delivered'))
          Column(children: [
            Text(status == 'shipped' ? 'Votre commande est en route !' : 'Le vendeur prépare votre commande.',
              style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
            const SizedBox(height: 8),
            _actionBtn('J\'ai reçu ma commande', Icons.done_all, AppColors.success, isLoading, () => _updateTxStatus(tx, 'completed')),
          ]),

        // ── Product link ──
        if (tx['product']?['slug'] != null) ...[
          const SizedBox(height: 10),
          SizedBox(width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => context.push('/product/${tx['product']['slug']}'),
              icon: const Icon(Icons.visibility, size: 16),
              label: const Text('Voir le produit', style: TextStyle(fontSize: 12)),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.accent, side: const BorderSide(color: AppColors.accent),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(vertical: 10)),
            ),
          ),
        ],
      ]),
    );
  }

  // ── Progress steps visualization ──
  Widget _buildProgressSteps(String currentStatus) {
    final steps = [
      {'key': 'pending', 'label': 'Commandé', 'icon': Icons.receipt_long},
      {'key': 'processing', 'label': 'Confirmé', 'icon': Icons.thumb_up},
      {'key': 'shipped', 'label': 'Expédié', 'icon': Icons.local_shipping},
      {'key': 'completed', 'label': 'Terminé', 'icon': Icons.check_circle},
    ];
    if (currentStatus == 'cancelled') {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        decoration: BoxDecoration(color: AppColors.danger.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(10)),
        child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.cancel, color: AppColors.danger, size: 16),
          SizedBox(width: 6),
          Text('Commande annulée', style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.w600, fontSize: 13)),
        ]),
      );
    }

    final statusOrder = ['pending', 'processing', 'shipped', 'delivered', 'completed'];
    final currentIdx = statusOrder.indexOf(currentStatus).clamp(0, steps.length - 1);

    return Row(children: [
      for (int i = 0; i < steps.length; i++) ...[
        if (i > 0)
          Expanded(child: Container(height: 2, color: i <= currentIdx ? AppColors.success : AppColors.border)),
        Column(children: [
          Container(
            width: 30, height: 30,
            decoration: BoxDecoration(
              color: i <= currentIdx
                  ? AppColors.success
                  : AppColors.bgInput,
              shape: BoxShape.circle,
              border: Border.all(color: i <= currentIdx ? AppColors.success : AppColors.border, width: 2)),
            child: Icon(
              steps[i]['icon'] as IconData,
              size: 14,
              color: i <= currentIdx ? Colors.white : AppColors.textMuted)),
          const SizedBox(height: 4),
          Text(steps[i]['label'] as String, style: TextStyle(
            fontSize: 9, fontWeight: i <= currentIdx ? FontWeight.w600 : FontWeight.w400,
            color: i <= currentIdx ? AppColors.success : AppColors.textMuted)),
        ]),
      ],
    ]);
  }

  Widget _actionBtn(String label, IconData icon, Color color, bool loading, VoidCallback onTap) {
    return SizedBox(height: 42,
      child: ElevatedButton(
        onPressed: loading ? null : onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: color.withValues(alpha: 0.12), foregroundColor: color, elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
        child: loading
            ? SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: color))
            : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(icon, size: 16), const SizedBox(width: 6),
                Flexible(child: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis)),
              ]),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
        Text(value, style: TextStyle(color: AppColors.textPrimary, fontSize: 12, fontWeight: FontWeight.w600)),
      ]));
  }

  Map<String, dynamic> _statusInfo(String status) {
    switch (status) {
      case 'completed': return {'color': AppColors.success, 'label': 'Terminé', 'icon': Icons.check_circle};
      case 'pending': return {'color': AppColors.warning, 'label': 'En attente', 'icon': Icons.schedule};
      case 'processing': return {'color': const Color(0xFF3B82F6), 'label': 'Confirmé', 'icon': Icons.autorenew};
      case 'shipped': return {'color': const Color(0xFF3B82F6), 'label': 'Expédié', 'icon': Icons.local_shipping};
      case 'delivered': return {'color': AppColors.success, 'label': 'Livré', 'icon': Icons.done_all};
      case 'cancelled': return {'color': AppColors.danger, 'label': 'Annulé', 'icon': Icons.cancel};
      default: return {'color': AppColors.textMuted, 'label': status, 'icon': Icons.help_outline};
    }
  }

  String _paymentLabel(String m) {
    const labels = {'orange_money': 'Orange Money', 'wave': 'Wave', 'free_money': 'Free Money', 'cash_delivery': 'À la livraison'};
    return labels[m] ?? m;
  }

  String _deliveryLabel(String t) {
    const labels = {'pickup': 'Retrait sur place', 'delivery': 'Livraison', 'meetup': 'Rencontre'};
    return labels[t] ?? t;
  }
}
