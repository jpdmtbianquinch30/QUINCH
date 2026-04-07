import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../services/api_service.dart';
import '../../config/theme.dart';

class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({super.key});
  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  List<dynamic> _purchases = [];
  List<dynamic> _sales = [];
  Map<String, dynamic> _stats = {};
  bool _loading = true;
  String _activeTab = 'purchases';
  String _statusFilter = 'all';
  String _dateFilter = 'all';
  String _searchQuery = '';
  String? _expandedId;
  String? _actionLoading;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() => _loading = true);
    try {
      final api = context.read<ApiService>();
      final res = await api.get('/products/transactions/history');
      final data = res.data;
      if (mounted) {
        setState(() {
          _purchases = (data['purchases']?['data'] ?? data['purchases'] ?? []) as List;
          _sales = (data['sales']?['data'] ?? data['sales'] ?? []) as List;
          _stats = data['stats'] ?? {};
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<dynamic> get _filtered {
    List<dynamic> items = _activeTab == 'purchases' ? _purchases : _sales;

    if (_statusFilter != 'all') {
      items = items.where((tx) => tx['payment_status'] == _statusFilter).toList();
    }

    if (_dateFilter != 'all') {
      final now = DateTime.now();
      Duration cutoff;
      switch (_dateFilter) {
        case '7d': cutoff = const Duration(days: 7); break;
        case '30d': cutoff = const Duration(days: 30); break;
        case '90d': cutoff = const Duration(days: 90); break;
        default: cutoff = const Duration(days: 999999);
      }
      final limit = now.subtract(cutoff);
      items = items.where((tx) {
        final d = DateTime.tryParse(tx['created_at'] ?? '');
        return d != null && d.isAfter(limit);
      }).toList();
    }

    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      items = items.where((tx) {
        final title = (tx['product']?['title'] ?? '').toString().toLowerCase();
        final id = (tx['id'] ?? '').toString().toLowerCase();
        return title.contains(q) || id.contains(q);
      }).toList();
    }

    return items;
  }

  Future<void> _updateStatus(dynamic tx, String status) async {
    setState(() => _actionLoading = tx['id']?.toString());
    try {
      final api = context.read<ApiService>();
      await api.put('/products/transactions/${tx['id']}/status', data: {'status': status});
      _showMsg(_statusMessages[status] ?? 'Statut mis à jour !');
      await _loadHistory();
    } catch (e) {
      _showMsg('Erreur lors de la mise à jour.', error: true);
    }
    if (mounted) setState(() => _actionLoading = null);
  }

  static const _statusMessages = {
    'processing': 'Commande acceptée !',
    'shipped': 'Commande marquée comme expédiée !',
    'delivered': 'Commande livrée avec succès !',
    'completed': 'Réception confirmée !',
    'cancelled': 'Commande annulée.',
  };

  void _showMsg(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(color: Colors.white, fontSize: 13)),
      backgroundColor: error ? AppColors.danger : const Color(0xFF1E293B),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  String _formatPrice(dynamic amount) {
    if (amount == null) return '0 F';
    final n = amount is num ? amount : num.tryParse(amount.toString()) ?? 0;
    return '${NumberFormat('#,###', 'fr').format(n)} F';
  }

  String _timeAgo(String? dateStr) {
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

  int _statusStep(String? s) {
    switch (s) {
      case 'pending': return 1;
      case 'processing': return 2;
      case 'shipped': return 2;
      case 'delivered': return 3;
      case 'completed': return 3;
      default: return 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: AppBar(
        backgroundColor: AppColors.bgSecondary,
        title: const Row(children: [
          Icon(Icons.receipt_long, size: 22),
          SizedBox(width: 8),
          Text('Mes Transactions', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
        ]),
      ),
      body: RefreshIndicator(
        color: AppColors.accent,
        onRefresh: _loadHistory,
        child: Column(
          children: [
            // ═══ STATS ═══
            Container(
              padding: const EdgeInsets.all(16),
              child: Row(children: [
                _StatCard(icon: Icons.trending_up, value: _formatPrice(_stats['total_earned']),
                    label: 'Revenus', color: AppColors.success),
                const SizedBox(width: 8),
                _StatCard(icon: Icons.shopping_cart, value: _formatPrice(_stats['total_spent']),
                    label: 'Dépensé', color: AppColors.accent),
                const SizedBox(width: 8),
                _StatCard(icon: Icons.check_circle, value: '${_stats[_activeTab == 'purchases' ? 'completed_purchases' : 'completed_sales'] ?? 0}',
                    label: 'Complétées', color: AppColors.success),
                const SizedBox(width: 8),
                _StatCard(icon: Icons.hourglass_top, value: '${_stats[_activeTab == 'purchases' ? 'pending_purchases' : 'pending_sales'] ?? 0}',
                    label: 'En attente', color: AppColors.warning),
              ]),
            ),

            // ═══ TABS ═══
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(children: [
                Expanded(child: _TabButton(
                  icon: Icons.shopping_bag, label: 'Mes achats',
                  count: '${_stats['purchases_count'] ?? _purchases.length}',
                  active: _activeTab == 'purchases',
                  onTap: () => setState(() => _activeTab = 'purchases'),
                )),
                const SizedBox(width: 8),
                Expanded(child: _TabButton(
                  icon: Icons.storefront, label: 'Mes ventes',
                  count: '${_stats['sales_count'] ?? _sales.length}',
                  active: _activeTab == 'sales',
                  onTap: () => setState(() => _activeTab = 'sales'),
                )),
              ]),
            ),
            const SizedBox(height: 12),

            // ═══ FILTERS ═══
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(children: [
                Expanded(
                  flex: 2,
                  child: TextField(
                    onChanged: (v) => setState(() => _searchQuery = v),
                    style: TextStyle(color: AppColors.textPrimary, fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Rechercher...',
                      hintStyle: TextStyle(color: AppColors.textMuted, fontSize: 12),
                      prefixIcon: Icon(Icons.search, size: 18, color: AppColors.textMuted),
                      filled: true, fillColor: AppColors.bgCard,
                      contentPadding: const EdgeInsets.symmetric(vertical: 8),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _FilterChip2(
                  value: _statusFilter,
                  items: const {'all': 'Tous', 'pending': 'En attente', 'processing': 'En cours', 'completed': 'Terminé', 'cancelled': 'Annulé'},
                  onChanged: (v) => setState(() => _statusFilter = v),
                ),
                const SizedBox(width: 6),
                _FilterChip2(
                  value: _dateFilter,
                  items: const {'all': 'Période', '7d': '7j', '30d': '30j', '90d': '3m'},
                  onChanged: (v) => setState(() => _dateFilter = v),
                ),
              ]),
            ),
            const SizedBox(height: 12),

            // ═══ LIST ═══
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator(color: AppColors.accent))
                  : _filtered.isEmpty
                      ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                          Icon(_activeTab == 'purchases' ? Icons.shopping_bag : Icons.storefront,
                              color: AppColors.textMuted, size: 48),
                          const SizedBox(height: 16),
                          Text(_activeTab == 'purchases' ? 'Aucun achat' : 'Aucune vente',
                              style: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 8),
                          Text(_activeTab == 'purchases' ? 'Vos achats apparaîtront ici' : 'Vos ventes apparaîtront ici',
                              style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
                        ]))
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _filtered.length,
                          itemBuilder: (_, i) => _buildTxCard(_filtered[i]),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTxCard(dynamic tx) {
    final id = tx['id']?.toString() ?? '';
    final expanded = _expandedId == id;
    final status = tx['payment_status'] ?? 'pending';
    final isSale = _activeTab == 'sales';
    final amount = tx['amount'];
    final product = tx['product'];
    final otherUser = isSale ? tx['buyer'] : tx['seller'];

    Color statusColor;
    String statusLabel;
    IconData statusIcon;
    switch (status) {
      case 'completed': statusColor = AppColors.success; statusLabel = 'Terminé'; statusIcon = Icons.check_circle; break;
      case 'pending': statusColor = AppColors.warning; statusLabel = 'En attente'; statusIcon = Icons.schedule; break;
      case 'processing': statusColor = const Color(0xFF3B82F6); statusLabel = 'En cours'; statusIcon = Icons.local_shipping; break;
      case 'shipped': statusColor = const Color(0xFF3B82F6); statusLabel = 'Expédié'; statusIcon = Icons.local_shipping; break;
      case 'delivered': statusColor = AppColors.success; statusLabel = 'Livré'; statusIcon = Icons.done_all; break;
      case 'cancelled': statusColor = AppColors.danger; statusLabel = 'Annulé'; statusIcon = Icons.block; break;
      case 'failed': statusColor = AppColors.danger; statusLabel = 'Échoué'; statusIcon = Icons.cancel; break;
      default: statusColor = AppColors.textMuted; statusLabel = status; statusIcon = Icons.help; break;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: expanded ? AppColors.accent.withValues(alpha: 0.3) : AppColors.border),
      ),
      child: Column(children: [
        // Main row
        InkWell(
          onTap: () => setState(() => _expandedId = expanded ? null : id),
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(children: [
              Container(
                width: 42, height: 42,
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(statusIcon, color: statusColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(product?['title'] ?? 'Produit', maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Row(children: [
                  if (otherUser != null) ...[
                    Icon(Icons.person, size: 12, color: AppColors.textMuted),
                    const SizedBox(width: 3),
                    Text(otherUser['full_name'] ?? otherUser['username'] ?? '—',
                        style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
                    const SizedBox(width: 6),
                  ],
                  Text(_timeAgo(tx['created_at']), style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
                ]),
              ])),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text('${isSale ? '+' : '-'}${_formatPrice(amount)}',
                    style: TextStyle(color: isSale ? AppColors.success : AppColors.accent,
                        fontSize: 15, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(20)),
                  child: Text(statusLabel, style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.w600)),
                ),
              ]),
              const SizedBox(width: 4),
              Icon(expanded ? Icons.expand_less : Icons.expand_more, color: AppColors.textMuted, size: 20),
            ]),
          ),
        ),

        // Expanded detail
        if (expanded) _buildTxDetail(tx, status, isSale, otherUser),
      ]),
    );
  }

  Widget _buildTxDetail(dynamic tx, String status, bool isSale, dynamic otherUser) {
    final step = _statusStep(status);
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
      child: Column(children: [
        Divider(color: AppColors.border),
        const SizedBox(height: 8),

        // Timeline
        Row(children: [
          _TimelineDot(done: step >= 1, active: step == 1, icon: Icons.schedule, label: 'En attente'),
          Expanded(child: Container(height: 2, color: step >= 2 ? AppColors.accent : AppColors.border)),
          _TimelineDot(done: step >= 2, active: step == 2, icon: Icons.local_shipping, label: 'En cours'),
          Expanded(child: Container(height: 2, color: step >= 3 ? AppColors.success : AppColors.border)),
          _TimelineDot(done: step >= 3, active: step == 3, icon: Icons.check_circle, label: 'Terminé'),
        ]),
        const SizedBox(height: 16),

        // Info grid
        _DetailRow2('Référence', '#${(tx['id'] ?? '').toString().substring(0, (tx['id'] ?? '').toString().length.clamp(0, 8)).toUpperCase()}'),
        _DetailRow2('Montant', '${_formatPrice(tx['amount'])} CFA'),
        if (tx['payment_method'] != null)
          _DetailRow2('Paiement', _paymentLabel(tx['payment_method'])),
        if (tx['delivery_type'] != null)
          _DetailRow2('Livraison', _deliveryLabel(tx['delivery_type'])),
        if (tx['transaction_fee'] != null && (tx['transaction_fee'] as num) > 0)
          _DetailRow2('Frais', '${_formatPrice(tx['transaction_fee'])} CFA'),
        _DetailRow2('Date', tx['created_at'] != null
            ? DateFormat("dd MMM yyyy 'à' HH:mm").format(DateTime.tryParse(tx['created_at']) ?? DateTime.now())
            : '-'),

        const SizedBox(height: 12),

        // Contact
        if (otherUser != null) Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.bgPrimary,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(children: [
            CircleAvatar(radius: 18, backgroundColor: AppColors.accentSubtle,
              child: Text((otherUser['full_name'] ?? '?')[0].toUpperCase(),
                  style: const TextStyle(color: AppColors.accent, fontWeight: FontWeight.w600))),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(otherUser['full_name'] ?? '—', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 13)),
              Text('@${otherUser['username'] ?? '-'}', style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
            ])),
          ]),
        ),

        const SizedBox(height: 12),

        // ═══ ACTION BUTTONS ═══
        _buildActions(tx, status, isSale),

        // Product link
        if (tx['product']?['slug'] != null) ...[
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => context.push('/product/${tx['product']['slug']}'),
              icon: const Icon(Icons.visibility, size: 16),
              label: const Text('Voir le produit', style: TextStyle(fontSize: 12)),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.accent,
                side: const BorderSide(color: AppColors.accent),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
        ],
      ]),
    );
  }

  Widget _buildActions(dynamic tx, String status, bool isSale) {
    final isLoading = _actionLoading == tx['id']?.toString();

    if (isSale) {
      // Seller actions
      if (status == 'pending') {
        return Row(children: [
          Expanded(child: _ActionBtn('Accepter', Icons.check, AppColors.success, isLoading, () => _updateStatus(tx, 'processing'))),
          const SizedBox(width: 6),
          Expanded(child: _ActionBtn('Expédier', Icons.local_shipping, AppColors.accent, isLoading, () => _updateStatus(tx, 'shipped'))),
          const SizedBox(width: 6),
          Expanded(child: _ActionBtn('Refuser', Icons.close, AppColors.danger, isLoading, () => _updateStatus(tx, 'cancelled'))),
        ]);
      } else if (status == 'processing') {
        return Row(children: [
          Expanded(child: _ActionBtn('Expédier', Icons.local_shipping, AppColors.accent, isLoading, () => _updateStatus(tx, 'shipped'))),
          const SizedBox(width: 6),
          Expanded(child: _ActionBtn('Livré', Icons.done_all, AppColors.success, isLoading, () => _updateStatus(tx, 'delivered'))),
          const SizedBox(width: 6),
          Expanded(child: _ActionBtn('Annuler', Icons.close, AppColors.danger, isLoading, () => _updateStatus(tx, 'cancelled'))),
        ]);
      } else if (status == 'completed') {
        return _StatusBanner(Icons.verified, 'Vente terminée', AppColors.success);
      } else if (status == 'cancelled') {
        return _StatusBanner(Icons.block, 'Annulée', AppColors.danger);
      }
    } else {
      // Buyer actions
      if (status == 'pending') {
        return SizedBox(
          width: double.infinity,
          child: _ActionBtn('Annuler la commande', Icons.close, AppColors.danger, isLoading, () => _updateStatus(tx, 'cancelled')),
        );
      } else if (status == 'processing' || status == 'shipped' || status == 'delivered') {
        return SizedBox(
          width: double.infinity,
          child: _ActionBtn('Confirmer la réception', Icons.done_all, AppColors.success, isLoading, () => _updateStatus(tx, 'completed')),
        );
      } else if (status == 'completed') {
        return _StatusBanner(Icons.verified, 'Achat terminé', AppColors.success);
      } else if (status == 'cancelled') {
        return _StatusBanner(Icons.block, 'Annulée', AppColors.danger);
      }
    }
    return const SizedBox.shrink();
  }

  String _paymentLabel(String m) {
    const labels = {'orange_money': '🟠 Orange Money', 'wave': '🔵 Wave', 'free_money': '🟢 Free Money', 'cash_delivery': '📦 À la livraison'};
    return labels[m] ?? m;
  }

  String _deliveryLabel(String t) {
    const labels = {'pickup': 'Retrait sur place', 'delivery': 'Livraison', 'meetup': 'Rencontre'};
    return labels[t] ?? t;
  }
}

// ═══ HELPER WIDGETS ═══

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;
  const _StatCard({required this.icon, required this.value, required this.label, required this.color});
  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
        decoration: BoxDecoration(
          color: AppColors.bgCard, borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700), textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis),
          Text(label, style: TextStyle(color: AppColors.textMuted, fontSize: 9), textAlign: TextAlign.center),
        ]),
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final String count;
  final bool active;
  final VoidCallback onTap;
  const _TabButton({required this.icon, required this.label, required this.count, required this.active, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: active ? AppColors.accent.withValues(alpha: 0.15) : AppColors.bgCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: active ? AppColors.accent.withValues(alpha: 0.4) : AppColors.border),
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, size: 16, color: active ? AppColors.accent : AppColors.textMuted),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
              color: active ? AppColors.accent : AppColors.textSecondary)),
          const SizedBox(width: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(
              color: active ? AppColors.accent.withValues(alpha: 0.2) : AppColors.bgInput,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(count, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
                color: active ? AppColors.accent : AppColors.textMuted)),
          ),
        ]),
      ),
    );
  }
}

class _FilterChip2 extends StatelessWidget {
  final String value;
  final Map<String, String> items;
  final ValueChanged<String> onChanged;
  const _FilterChip2({required this.value, required this.items, required this.onChanged});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        color: AppColors.bgCard, borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isDense: true,
          dropdownColor: AppColors.bgCard,
          style: TextStyle(color: AppColors.textPrimary, fontSize: 11),
          items: items.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))).toList(),
          onChanged: (v) { if (v != null) onChanged(v); },
        ),
      ),
    );
  }
}

class _TimelineDot extends StatelessWidget {
  final bool done;
  final bool active;
  final IconData icon;
  final String label;
  const _TimelineDot({required this.done, required this.active, required this.icon, required this.label});
  @override
  Widget build(BuildContext context) {
    final color = done ? (active ? AppColors.accent : AppColors.success) : AppColors.textMuted;
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Container(
        width: 30, height: 30,
        decoration: BoxDecoration(
          color: done ? color.withValues(alpha: 0.15) : AppColors.bgInput,
          shape: BoxShape.circle,
          border: Border.all(color: color, width: active ? 2 : 1),
        ),
        child: Icon(icon, size: 14, color: color),
      ),
      const SizedBox(height: 4),
      Text(label, style: TextStyle(color: color, fontSize: 8, fontWeight: done ? FontWeight.w600 : FontWeight.w400)),
    ]);
  }
}

class _DetailRow2 extends StatelessWidget {
  final String label;
  final String value;
  const _DetailRow2(this.label, this.value);
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
        Text(value, style: TextStyle(color: AppColors.textPrimary, fontSize: 12, fontWeight: FontWeight.w500)),
      ]),
    );
  }
}

// ignore: non_constant_identifier_names
Widget _ActionBtn(String label, IconData icon, Color color, bool loading, VoidCallback onTap) {
  return ElevatedButton(
    onPressed: loading ? null : onTap,
    style: ElevatedButton.styleFrom(
      backgroundColor: color.withValues(alpha: 0.15),
      foregroundColor: color,
      elevation: 0,
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ),
    child: loading
        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
        : Row(mainAxisAlignment: MainAxisAlignment.center, mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 14),
            const SizedBox(width: 4),
            Flexible(child: Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis)),
          ]),
  );
}

// ignore: non_constant_identifier_names
Widget _StatusBanner(IconData icon, String text, Color color) {
  return Container(
    padding: const EdgeInsets.symmetric(vertical: 10),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10),
    ),
    child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(icon, color: color, size: 18),
      const SizedBox(width: 8),
      Text(text, style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 13)),
    ]),
  );
}
