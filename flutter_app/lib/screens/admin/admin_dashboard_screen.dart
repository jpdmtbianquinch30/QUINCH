import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:video_player/video_player.dart';
import '../../services/admin_service.dart';
import '../../config/theme.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});
  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  String _tab = 'dashboard';
  bool _loading = true;
  Map<String, dynamic> _metrics = {};
  Map<String, dynamic>? _realTime;
  List<dynamic> _alerts = [];
  List<dynamic> _pendingVideos = [];
  Timer? _refreshTimer;

  // Users
  List<dynamic> _users = [];
  int _userTotal = 0;
  int _userPage = 1;
  bool _loadingUsers = false;
  String _userSearch = '';
  String _userFilter = 'all';

  // Reports
  int _reportDays = 7;
  Map<String, dynamic>? _reportData;
  Map<String, dynamic>? _txReport;

  // Security
  List<dynamic> _securityLogs = [];

  // Video Preview
  VideoPlayerController? _videoController;
  String? _playingVideoUrl;

  @override
  void initState() {
    super.initState();
    _loadDashboard();
    _refreshTimer = Timer.periodic(const Duration(seconds: 15), (_) => _loadRealTime());
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _videoController?.dispose();
    super.dispose();
  }

  AdminService get _admin => context.read<AdminService>();

  Future<void> _loadDashboard() async {
    setState(() => _loading = true);
    try {
      _metrics = await _admin.getMetrics();
      _loadRealTime();
      final alerts = await _admin.getSecurityAlerts();
      _alerts = alerts['data'] ?? [];
      final pending = await _admin.getPendingModeration();
      _pendingVideos = pending['data'] ?? [];
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _loadRealTime() async {
    try {
      final rt = await _admin.getRealTimeData();
      if (mounted) setState(() => _realTime = rt);
    } catch (_) {}
  }

  Future<void> _loadUsers({bool refresh = false}) async {
    if (_loadingUsers) return;
    setState(() => _loadingUsers = true);
    try {
      if (refresh) {
        _userPage = 1;
        _users.clear();
      }
      final params = <String, dynamic>{'page': _userPage, 'per_page': 20};
      if (_userSearch.isNotEmpty) params['search'] = _userSearch;
      if (_userFilter != 'all') params['status'] = _userFilter;
      final res = await _admin.getUsers(params);
      if (mounted) setState(() {
        final newUsers = res['data'] ?? [];
        if (refresh) {
          _users = newUsers;
        } else {
          _users.addAll(newUsers);
        }
        _userTotal = res['total'] ?? 0;
        if (newUsers.isNotEmpty) _userPage++;
      });
    } catch (_) {}
    if (mounted) setState(() => _loadingUsers = false);
  }

  Future<void> _loadReports() async {
    try {
      _reportData = await _admin.getOverviewReport(_reportDays);
      _txReport = await _admin.getTransactionReport(_reportDays);
      if (mounted) setState(() {});
    } catch (_) {}
  }

  Future<void> _loadSecurityLogs() async {
    try {
      final res = await _admin.getAuditLogs({'per_page': 50});
      if (mounted) setState(() => _securityLogs = res['data'] ?? []);
    } catch (_) {}
  }

  void _switchTab(String tab) {
    setState(() => _tab = tab);
    if (tab == 'users' && _users.isEmpty) _loadUsers(refresh: true);
    if (tab == 'reports' && _reportData == null) _loadReports();
    if (tab == 'security' && _securityLogs.isEmpty) _loadSecurityLogs();
  }

  String _fmtNum(dynamic n) {
    if (n == null) return '0';
    final num v = n is num ? n : num.tryParse(n.toString()) ?? 0;
    if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}M';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}K';
    return v.toStringAsFixed(0);
  }

  String _fmtCurrency(dynamic n) {
    if (n == null) return '0 F';
    final num v = n is num ? n : num.tryParse(n.toString()) ?? 0;
    return '${NumberFormat('#,###', 'fr').format(v)} F';
  }

  void _showMsg(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(color: Colors.white)),
      backgroundColor: error ? AppColors.danger : const Color(0xFF1E293B),
      behavior: SnackBarBehavior.floating,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: AppBar(
        backgroundColor: AppColors.bgSecondary,
        title: const Row(children: [
          Icon(Icons.admin_panel_settings, size: 22),
          SizedBox(width: 8),
          Text('Panel Admin', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
        ]),
        actions: [
          if (_realTime != null)
            Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Container(width: 6, height: 6, decoration: const BoxDecoration(color: AppColors.success, shape: BoxShape.circle)),
                const SizedBox(width: 4),
                const Text('Live', style: TextStyle(color: AppColors.success, fontSize: 11, fontWeight: FontWeight.w600)),
              ]),
            ),
          IconButton(icon: const Icon(Icons.refresh, size: 20), onPressed: _loadDashboard),
        ],
      ),
      body: Column(children: [
        // Tab navigation
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(children: [
            _AdminTab('Dashboard', Icons.dashboard, 'dashboard'),
            _AdminTab('Utilisateurs', Icons.people, 'users', badge: _metrics['users']?['suspended']),
            _AdminTab('Modération', Icons.shield, 'moderation', badge: _metrics['moderation']?['pending_videos']),
            _AdminTab('Finance', Icons.account_balance, 'finance'),
            _AdminTab('Rapports', Icons.analytics, 'reports'),
            _AdminTab('Sécurité', Icons.security, 'security', badge: _metrics['security']?['fraud_alerts'], badgeColor: AppColors.danger),
          ]),
        ),

        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: AppColors.accent))
              : _buildTabContent(),
        ),
      ]),
    );
  }

  Widget _AdminTab(String label, IconData icon, String tab, {dynamic badge, Color? badgeColor}) {
    final active = _tab == tab;
    return GestureDetector(
      onTap: () => _switchTab(tab),
      child: Container(
        margin: const EdgeInsets.only(right: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: active ? AppColors.accent.withValues(alpha: 0.15) : AppColors.bgCard,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: active ? AppColors.accent : AppColors.border),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 16, color: active ? AppColors.accent : AppColors.textMuted),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(fontSize: 12, fontWeight: active ? FontWeight.w600 : FontWeight.w400,
              color: active ? AppColors.accent : AppColors.textSecondary)),
          if (badge != null && badge != 0) ...[
            const SizedBox(width: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: badgeColor ?? AppColors.warning,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text('$badge', style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700)),
            ),
          ],
        ]),
      ),
    );
  }

  Widget _buildTabContent() {
    switch (_tab) {
      case 'dashboard': return _buildDashboard();
      case 'users': return _buildUsers();
      case 'moderation': return _buildModeration();
      case 'finance': return _buildFinance();
      case 'reports': return _buildReports();
      case 'security': return _buildSecurity();
      default: return _buildDashboard();
    }
  }

  // ═══ DASHBOARD TAB ═══
  Widget _buildDashboard() {
    final users = _metrics['users'] ?? {};
    final txs = _metrics['transactions'] ?? {};
    final products = _metrics['products'] ?? {};

    return ListView(padding: const EdgeInsets.all(16), children: [
      // KPI Grid
      Row(children: [
        _KpiCard('Utilisateurs', _fmtNum(users['total']), '+${users['new_today'] ?? 0} aujourd\'hui', Icons.people, const Color(0xFF3B82F6)),
        const SizedBox(width: 8),
        _KpiCard('Revenue', _fmtCurrency(txs['revenue']), '${_fmtCurrency(txs['today_volume'])} auj.', Icons.payments, AppColors.success),
      ]),
      const SizedBox(height: 8),
      Row(children: [
        _KpiCard('Transactions', _fmtNum(txs['total']), '${txs['success_rate'] ?? 0}% succès', Icons.receipt_long, const Color(0xFF8B5CF6)),
        const SizedBox(width: 8),
        _KpiCard('Produits', _fmtNum(products['active']), '+${products['new_today'] ?? 0} auj.', Icons.inventory_2, const Color(0xFFF59E0B)),
      ]),
      const SizedBox(height: 16),

      // Real-time
      if (_realTime != null) ...[
        _SCard(title: 'Temps réel', titleIcon: Icons.fiber_manual_record, titleIconColor: AppColors.success, children: [
          Row(children: [
            _RtStat(Icons.person, '${_realTime!['active_users'] ?? 0}', 'Utilisateurs actifs'),
            _RtStat(Icons.trending_up, '${_realTime!['transactions_today'] ?? 0}', 'Transactions auj.'),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            _RtStat(Icons.attach_money, _fmtCurrency(_realTime!['revenue_today']), 'Revenue auj.'),
            _RtStat(Icons.pending, '${_realTime!['pending_moderations'] ?? 0}', 'En modération'),
          ]),
        ]),
        const SizedBox(height: 12),
      ],

      // Alerts
      _SCard(title: 'Alertes critiques', children: [
        if (_alerts.isEmpty)
          Padding(padding: const EdgeInsets.all(16), child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.check_circle, color: AppColors.success, size: 20),
            SizedBox(width: 8),
            Text('Aucune alerte', style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
          ]))
        else
          ...(_alerts.take(5).map((a) => ListTile(
            dense: true,
            leading: Icon(a['severity'] == 'critical' ? Icons.error : Icons.warning,
                color: a['severity'] == 'critical' ? AppColors.danger : AppColors.warning, size: 20),
            title: Text(a['description'] ?? a['type'] ?? 'Alerte', style: TextStyle(color: AppColors.textPrimary, fontSize: 12)),
            trailing: Text(a['created_at']?.toString().substring(0, 16) ?? '', style: TextStyle(color: AppColors.textMuted, fontSize: 10)),
          ))),
      ]),
      const SizedBox(height: 12),

      // Quick stats
      _SCard(title: 'Statistiques', children: [
        _StatRow('Utilisateurs actifs', '${users['active'] ?? 0}'),
        _StatRow('KYC Vérifiés', '${users['verified'] ?? 0}'),
        _StatRow('Suspendus', '${users['suspended'] ?? 0}', danger: true),
        _StatRow('Tx complétées', '${txs['completed'] ?? 0}'),
        _StatRow('Tx en attente', '${txs['pending'] ?? 0}', warning: true),
        _StatRow('Panier moyen', _fmtCurrency(txs['avg_basket'])),
      ]),
    ]);
  }

  // ═══ USERS TAB ═══
  Widget _buildUsers() {
    return Column(children: [
      Padding(
        padding: const EdgeInsets.all(12),
        child: Row(children: [
          Expanded(
            child: TextField(
              onChanged: (v) { _userSearch = v; },
              onSubmitted: (_) => _loadUsers(refresh: true),
              style: TextStyle(color: AppColors.textPrimary, fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Rechercher un utilisateur...',
                hintStyle: TextStyle(color: AppColors.textMuted, fontSize: 12),
                prefixIcon: Icon(Icons.search, size: 18, color: AppColors.textMuted),
                filled: true, fillColor: AppColors.bgCard,
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(color: AppColors.bgCard, borderRadius: BorderRadius.circular(10)),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _userFilter, isDense: true, dropdownColor: AppColors.bgCard,
                style: TextStyle(color: AppColors.textPrimary, fontSize: 12),
                items: const [
                  DropdownMenuItem(value: 'all', child: Text('Tous')),
                  DropdownMenuItem(value: 'active', child: Text('Actifs')),
                  DropdownMenuItem(value: 'suspended', child: Text('Suspendus')),
                ],
                onChanged: (v) { _userFilter = v ?? 'all'; _loadUsers(refresh: true); },
              ),
            ),
          ),
        ]),
      ),
      Expanded(
        child: _users.isEmpty && !_loadingUsers
            ? Center(child: Text('Aucun utilisateur trouvé', style: TextStyle(color: AppColors.textMuted)))
            : ListView.builder(
                itemCount: _users.length + (_users.length < _userTotal ? 1 : 0),
                itemBuilder: (_, i) {
                  if (i == _users.length) {
                    return Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Center(
                        child: _loadingUsers
                            ? const CircularProgressIndicator(color: AppColors.accent)
                            : TextButton(
                                onPressed: () => _loadUsers(),
                                child: const Text('Charger plus'),
                              ),
                      ),
                    );
                  }
                  return _buildUserTile(_users[i]);
                },
              ),
      ),
    ]);
  }

  Widget _buildUserTile(dynamic user) {
    final status = user['account_status'] ?? 'active';
    Color statusColor;
    switch (status) {
      case 'active': statusColor = AppColors.success; break;
      case 'suspended': statusColor = AppColors.danger; break;
      default: statusColor = AppColors.warning;
    }
    final trust = ((user['trust_score'] ?? 0) * 100).toInt();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.bgCard, borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(children: [
        CircleAvatar(radius: 20, backgroundColor: AppColors.accentSubtle,
          child: Text((user['full_name'] ?? '?')[0].toUpperCase(),
              style: const TextStyle(color: AppColors.accent, fontWeight: FontWeight.w700))),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(user['full_name'] ?? '-', style: TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
          Text('${user['username'] ?? '-'} • ${user['phone_number'] ?? '-'}',
              style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
        ])),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
            child: Text(status, style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.w600)),
          ),
          const SizedBox(height: 4),
          Text('$trust%', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
              color: trust >= 80 ? AppColors.success : trust >= 50 ? AppColors.warning : AppColors.danger)),
        ]),
        const SizedBox(width: 8),
        PopupMenuButton<String>(
          icon: Icon(Icons.more_vert, size: 18, color: AppColors.textMuted),
          color: AppColors.bgCard,
          onSelected: (action) async {
            switch (action) {
              case 'suspend': await _admin.suspendUser(user['id'], 'Admin action', 7); _showMsg('Utilisateur suspendu'); _loadUsers(refresh: true); break;
              case 'activate': await _admin.activateUser(user['id']); _showMsg('Utilisateur réactivé'); _loadUsers(refresh: true); break;
              case 'verify_kyc': await _admin.verifyKyc(user['id'], 'verified'); _showMsg('KYC vérifié'); _loadUsers(refresh: true); break;
              case 'delete':
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    backgroundColor: AppColors.bgCard,
                    title: const Text('Supprimer l\'utilisateur ?', style: TextStyle(color: AppColors.danger)),
                    content: Text('Cette action est irréversible. L\'utilisateur ${user['full_name']} sera définitivement supprimé.',
                        style: TextStyle(color: AppColors.textSecondary)),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('Supprimer', style: TextStyle(color: AppColors.danger)),
                      ),
                    ],
                  ),
                );
                if (confirm == true) {
                  await _admin.deleteUser(user['id'], 'Admin delete');
                  _showMsg('Utilisateur supprimé');
                  _loadUsers(refresh: true);
                }
                break;
            }
          },
          itemBuilder: (_) => [
            if (status == 'active')
              const PopupMenuItem(value: 'suspend', child: Text('Suspendre', style: TextStyle(color: AppColors.danger, fontSize: 13))),
            if (status != 'active')
              const PopupMenuItem(value: 'activate', child: Text('Réactiver', style: TextStyle(color: AppColors.success, fontSize: 13))),
            if (user['kyc_status'] == 'pending')
              const PopupMenuItem(value: 'verify_kyc', child: Text('Vérifier KYC', style: TextStyle(color: AppColors.accent, fontSize: 13))),
            const PopupMenuDivider(),
            const PopupMenuItem(value: 'delete', child: Text('Supprimer', style: TextStyle(color: AppColors.danger, fontSize: 13))),
          ],
        ),
      ]),
    );
  }

  // ═══ MODERATION TAB ═══
  Widget _buildModeration() {
    return Column(children: [
      Padding(
        padding: const EdgeInsets.all(12),
        child: Row(children: [
          Text('${_pendingVideos.length} en attente', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
          const Spacer(),
          TextButton.icon(
            icon: const Icon(Icons.delete_sweep, size: 16, color: AppColors.danger),
            label: const Text('Tout supprimer', style: TextStyle(fontSize: 12, color: AppColors.danger)),
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  backgroundColor: AppColors.bgCard,
                  title: const Text('Confirmer la suppression', style: TextStyle(color: AppColors.danger)),
                  content: Text(
                    'Voulez-vous vraiment supprimer TOUTES les vidéos de la plateforme ?\n\nCette action est irréversible.',
                    style: TextStyle(color: AppColors.textPrimary),
                  ),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('Supprimer', style: TextStyle(color: AppColors.danger)),
                    ),
                  ],
                ),
              );

              if (confirm == true) {
                await _admin.deleteAllVideos();
                _showMsg('Toutes les vidéos ont été supprimées');
                _loadDashboard();
              }
            },
          ),
          const SizedBox(width: 8),
          TextButton.icon(
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text('Rafraîchir', style: TextStyle(fontSize: 12)),
            onPressed: () async {
              final p = await _admin.getPendingModeration();
              if (mounted) setState(() => _pendingVideos = p['data'] ?? []);
            },
          ),
        ]),
      ),
      Expanded(
        child: _pendingVideos.isEmpty
            ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.check_circle, color: AppColors.success, size: 48),
                SizedBox(height: 8),
                Text('File de modération vide', style: TextStyle(color: AppColors.textMuted)),
              ]))
            : ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: _pendingVideos.length,
                itemBuilder: (_, i) {
                  final v = _pendingVideos[i];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.bgCard, borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(children: [
                      Container(
                        width: 60, height: 60,
                        decoration: BoxDecoration(color: AppColors.bgInput, borderRadius: BorderRadius.circular(8)),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            if (_playingVideoUrl == v['video_url'] && _videoController != null && _videoController!.value.isInitialized)
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: AspectRatio(
                                  aspectRatio: _videoController!.value.aspectRatio,
                                  child: VideoPlayer(_videoController!),
                                ),
                              )
                            else
                              const Icon(Icons.play_circle, color: AppColors.accent),
                            
                            Positioned.fill(
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(8),
                                  onTap: () {
                                    if (v['video_url'] != null) {
                                      _playPreview(v['video_url']);
                                    } else {
                                      _showMsg('URL vidéo invalide', error: true);
                                    }
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(v['product']?['title'] ?? 'Vidéo #${v['id']}',
                            style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 13)),
                        Text(v['user']?['full_name'] ?? 'Utilisateur',
                            style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
                      ])),
                      IconButton(
                        icon: const Icon(Icons.check_circle, color: AppColors.success, size: 28),
                        onPressed: () async {
                          await _admin.moderateVideo(v['id'], 'approved');
                          setState(() => _pendingVideos.removeAt(i));
                          _showMsg('Approuvé');
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.cancel, color: AppColors.danger, size: 28),
                        onPressed: () async {
                          await _admin.moderateVideo(v['id'], 'rejected');
                          setState(() => _pendingVideos.removeAt(i));
                          _showMsg('Rejeté');
                        },
                      ),
                    ]),
                  );
                },
              ),
      ),
    ]);
  }

  // ═══ FINANCE TAB ═══
  Widget _buildFinance() {
    final txs = _metrics['transactions'] ?? {};
    return ListView(padding: const EdgeInsets.all(16), children: [
      Row(children: [
        _KpiCard('Revenue', _fmtCurrency(txs['revenue']), 'Total', Icons.account_balance_wallet, AppColors.success),
        const SizedBox(width: 8),
        _KpiCard('Volume mois', _fmtCurrency(txs['month_volume']), 'Ce mois', Icons.show_chart, const Color(0xFF3B82F6)),
      ]),
      const SizedBox(height: 8),
      Row(children: [
        _KpiCard('Panier moyen', _fmtCurrency(txs['avg_basket']), 'Moyenne', Icons.shopping_cart, const Color(0xFF8B5CF6)),
        const SizedBox(width: 8),
        _KpiCard('Frais', _fmtCurrency(txs['total_fees']), 'Collectés', Icons.local_atm, const Color(0xFFF59E0B)),
      ]),
      const SizedBox(height: 16),
      _SCard(title: 'Répartition', children: [
        _StatRow('Total transactions', '${txs['total'] ?? 0}'),
        _StatRow('Complétées', '${txs['completed'] ?? 0}'),
        _StatRow('En attente', '${txs['pending'] ?? 0}', warning: true),
        _StatRow('Disputes', '${txs['disputed'] ?? 0}', danger: true),
        _StatRow('Taux de succès', '${txs['success_rate'] ?? 0}%'),
      ]),
    ]);
  }

  // ═══ REPORTS TAB ═══
  Widget _buildReports() {
    return ListView(padding: const EdgeInsets.all(16), children: [
      // Period selector
      Row(children: [
        for (final d in [7, 14, 30, 90]) ...[
          Expanded(child: GestureDetector(
            onTap: () { setState(() => _reportDays = d); _loadReports(); },
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: _reportDays == d ? AppColors.accent.withValues(alpha: 0.15) : AppColors.bgCard,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _reportDays == d ? AppColors.accent : AppColors.border),
              ),
              child: Text('${d}j', textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, fontWeight: _reportDays == d ? FontWeight.w600 : FontWeight.w400,
                      color: _reportDays == d ? AppColors.accent : AppColors.textMuted)),
            ),
          )),
          if (d != 90) const SizedBox(width: 6),
        ],
      ]),
      const SizedBox(height: 16),

      if (_txReport?['summary'] != null) ...[
        Row(children: [
          _KpiCard('Transactions', '${_txReport!['summary']['total_transactions'] ?? 0}', '', Icons.receipt, const Color(0xFF3B82F6)),
          const SizedBox(width: 8),
          _KpiCard('Volume', _fmtCurrency(_txReport!['summary']['total_volume']), '', Icons.payments, AppColors.success),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          _KpiCard('Frais', _fmtCurrency(_txReport!['summary']['total_fees']), '', Icons.local_atm, const Color(0xFFF59E0B)),
          const SizedBox(width: 8),
          _KpiCard('Succès', '${_txReport!['summary']['success_rate'] ?? 0}%', '', Icons.trending_up, const Color(0xFF8B5CF6)),
        ]),
        const SizedBox(height: 16),
      ],

      if (_reportData?['daily'] != null) ...[
        _SCard(title: 'Activité quotidienne', children: [
          ...(_reportData!['daily'] as List).take(7).map((day) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(children: [
              SizedBox(width: 70, child: Text(day['date'] ?? '', style: TextStyle(color: AppColors.textMuted, fontSize: 11))),
              Expanded(child: Text('${day['users'] ?? 0} users', style: TextStyle(color: AppColors.textPrimary, fontSize: 11))),
              Text('${day['transactions'] ?? 0} tx', style: const TextStyle(color: AppColors.accent, fontSize: 11)),
              const SizedBox(width: 8),
              Text(_fmtCurrency(day['revenue']), style: const TextStyle(color: AppColors.success, fontSize: 11, fontWeight: FontWeight.w600)),
            ]),
          )),
        ]),
      ],
    ]);
  }

  // ═══ SECURITY TAB ═══
  Widget _buildSecurity() {
    return ListView(padding: const EdgeInsets.all(16), children: [
      Row(children: [
        _KpiCard('Fraudes', '${_metrics['security']?['fraud_alerts'] ?? 0}', '', Icons.gpp_bad, AppColors.danger),
        const SizedBox(width: 8),
        _KpiCard('Suspects', '${_metrics['security']?['suspicious_users'] ?? 0}', '', Icons.person_off, const Color(0xFFF59E0B)),
        const SizedBox(width: 8),
        _KpiCard('Santé', '${_realTime?['system_health'] ?? 100}%', '', Icons.shield, AppColors.success),
      ]),
      const SizedBox(height: 16),

      _SCard(title: 'Alertes de sécurité', children: [
        if (_alerts.isEmpty)
          Padding(padding: EdgeInsets.all(16), child: Center(child: Text('Aucune alerte active', style: TextStyle(color: AppColors.textMuted))))
        else
          ..._alerts.map((a) => ListTile(
            dense: true,
            leading: Icon(a['severity'] == 'critical' ? Icons.error : Icons.warning,
                color: a['severity'] == 'critical' ? AppColors.danger : AppColors.warning, size: 18),
            title: Text(a['description'] ?? a['type'] ?? '', style: TextStyle(color: AppColors.textPrimary, fontSize: 12)),
            subtitle: Text('${a['ip_address'] ?? ''} • ${a['user']?['full_name'] ?? 'N/A'}',
                style: TextStyle(color: AppColors.textMuted, fontSize: 10)),
          )),
      ]),
      const SizedBox(height: 12),

      _SCard(title: 'Journal d\'audit', children: [
        if (_securityLogs.isEmpty)
          Padding(padding: EdgeInsets.all(16), child: Center(child: Text('Aucun log', style: TextStyle(color: AppColors.textMuted))))
        else
          ..._securityLogs.take(20).map((log) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
            child: Row(children: [
              Expanded(child: Text(log['action_type'] ?? log['action'] ?? '', style: TextStyle(color: AppColors.textPrimary, fontSize: 11))),
              Text(log['ip_address'] ?? '', style: TextStyle(color: AppColors.textMuted, fontSize: 10)),
              const SizedBox(width: 8),
              Text((log['created_at'] ?? '').toString().substring(0, (log['created_at'] ?? '').toString().length.clamp(0, 16)),
                  style: TextStyle(color: AppColors.textMuted, fontSize: 10)),
            ]),
          )),
      ]),

      const SizedBox(height: 32),
      Center(
        child: ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.danger,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
          icon: const Icon(Icons.delete_forever),
          label: const Text('RÉINITIALISER LE SYSTÈME'),
          onPressed: () async {
            final confirm = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                backgroundColor: AppColors.bgCard,
                title: const Text('ATTENTION', style: TextStyle(color: AppColors.danger)),
                content: Text(
                  'Voulez-vous vraiment supprimer TOUS les utilisateurs (sauf admins) et TOUTES les vidéos ?\n\nCette action est irréversible.',
                  style: TextStyle(color: AppColors.textPrimary),
                ),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text('TOUT SUPPRIMER', style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            );

            if (confirm == true) {
              await _admin.resetSystem();
              _showMsg('Système réinitialisé');
              _loadDashboard();
            }
          },
        ),
      ),
      const SizedBox(height: 24),
    ]);
  }

  // ═══ HELPER WIDGETS ═══
  Widget _KpiCard(String label, String value, String sub, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.bgCard, borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 8),
          Text(value, style: TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w800),
              maxLines: 1, overflow: TextOverflow.ellipsis),
          Text(label, style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
          if (sub.isNotEmpty) Text(sub, style: TextStyle(color: color, fontSize: 10)),
        ]),
      ),
    );
  }

  Widget _SCard({required String title, IconData? titleIcon, Color? titleIconColor, required List<Widget> children}) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.bgCard, borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
          child: Row(children: [
            if (titleIcon != null) ...[Icon(titleIcon, size: 10, color: titleIconColor ?? AppColors.accent), const SizedBox(width: 6)],
            Text(title, style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 14)),
          ]),
        ),
        ...children,
        const SizedBox(height: 8),
      ]),
    );
  }

  Widget _RtStat(IconData icon, String value, String label) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Row(children: [
          Icon(icon, size: 18, color: AppColors.accent),
          const SizedBox(width: 8),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(value, style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 14)),
            Text(label, style: TextStyle(color: AppColors.textMuted, fontSize: 10)),
          ])),
        ]),
      ),
    );
  }

  Widget _StatRow(String label, String value, {bool danger = false, bool warning = false}) {
    Color vColor = AppColors.textPrimary;
    if (danger) vColor = AppColors.danger;
    if (warning) vColor = AppColors.warning;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
        Text(value, style: TextStyle(color: vColor, fontWeight: FontWeight.w600, fontSize: 13)),
      ]),
    );
  }

  Future<void> _playPreview(String url) async {
    if (_playingVideoUrl == url) {
      if (_videoController != null && _videoController!.value.isPlaying) {
        _videoController!.pause();
        setState(() => _playingVideoUrl = null);
      }
      return;
    }

    _videoController?.dispose();
    setState(() {
      _playingVideoUrl = url;
      _videoController = null;
    });

    try {
      final ctrl = VideoPlayerController.networkUrl(Uri.parse(url));
      await ctrl.initialize();
      ctrl.setLooping(true);
      await ctrl.play();
      if (mounted && _playingVideoUrl == url) {
        setState(() => _videoController = ctrl);
      } else {
        ctrl.dispose();
      }
    } catch (e) {
      debugPrint('Video error: $e');
      _showMsg('Erreur de lecture vidéo', error: true);
      if (mounted) setState(() => _playingVideoUrl = null);
    }
  }
}
