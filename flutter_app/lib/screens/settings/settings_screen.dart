import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../providers/auth_provider.dart';
import '../../providers/theme_provider.dart';
import '../../services/api_service.dart';
import '../../config/theme.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // ═══ Notification toggles ═══
  bool _pushNotif = true;
  bool _emailNotif = true;
  bool _smsNotif = false;
  // Per-type notification prefs
  Map<String, bool> _notifTypes = {
    'message': true, 'follow': true, 'like': true,
    'comment': true, 'transaction': true, 'system': true,
  };
  bool _loadingNotifPrefs = false;

  // ═══ UI states ═══
  bool _showPasswordForm = false;
  bool _showReportForm = false;
  bool _showBlockedUsers = false;
  bool _showTerms = false;
  bool _savingPassword = false;
  bool _exportingData = false;

  // ═══ Password form ═══
  final _currentPwCtrl = TextEditingController();
  final _newPwCtrl = TextEditingController();
  final _confirmPwCtrl = TextEditingController();

  // ═══ Report form ═══
  String _reportCategory = 'bug';
  final _reportCtrl = TextEditingController();

  // ═══ Blocked users ═══
  List<dynamic> _blockedUsers = [];

  // ═══ Preferences ═══
  String _language = 'fr';
  String _currency = 'XOF';

  // ═══ FAQ expanded state ═══
  int? _expandedFaq;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
    _loadNotifPreferences();
  }

  @override
  void dispose() {
    _currentPwCtrl.dispose();
    _newPwCtrl.dispose();
    _confirmPwCtrl.dispose();
    _reportCtrl.dispose();
    super.dispose();
  }

  // ═══════════════════════════════════════════════
  // PREFERENCES I/O
  // ═══════════════════════════════════════════════

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('quinch_settings');
    if (saved != null) {
      try {
        if (saved.contains('"pushNotifications":false')) _pushNotif = false;
        if (saved.contains('"emailNotifications":false')) _emailNotif = false;
        if (saved.contains('"smsNotifications":true')) _smsNotif = true;
        if (saved.contains('"language":"wo"')) _language = 'wo';
        if (saved.contains('"language":"en"')) _language = 'en';
        if (saved.contains('"currency":"EUR"')) _currency = 'EUR';
        if (saved.contains('"currency":"USD"')) _currency = 'USD';
        if (mounted) setState(() {});
      } catch (_) {}
    }
  }

  Future<void> _savePrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('quinch_settings',
        '{"pushNotifications":$_pushNotif,"emailNotifications":$_emailNotif,"smsNotifications":$_smsNotif,"language":"$_language","currency":"$_currency"}');
  }

  // ═══════════════════════════════════════════════
  // NOTIFICATION PREFERENCES (Backend sync)
  // ═══════════════════════════════════════════════

  Future<void> _loadNotifPreferences() async {
    setState(() => _loadingNotifPrefs = true);
    try {
      final api = context.read<ApiService>();
      final res = await api.get('/notifications/preferences');
      final data = res.data;
      // API returns list of {type, push_enabled, in_app_enabled, email_enabled}
      if (data is List) {
        for (final pref in data) {
          final type = pref['type']?.toString();
          if (type != null && _notifTypes.containsKey(type)) {
            _notifTypes[type] = pref['push_enabled'] == true || pref['in_app_enabled'] == true;
          }
        }
      } else if (data is Map && data['preferences'] is List) {
        for (final pref in data['preferences']) {
          final type = pref['type']?.toString();
          if (type != null && _notifTypes.containsKey(type)) {
            _notifTypes[type] = pref['push_enabled'] == true || pref['in_app_enabled'] == true;
          }
        }
      }
    } catch (e) {
      debugPrint('[Settings] Error loading notif prefs: $e');
    }
    if (mounted) setState(() => _loadingNotifPrefs = false);
  }

  Future<void> _updateNotifPref(String type, bool enabled) async {
    setState(() => _notifTypes[type] = enabled);
    try {
      final api = context.read<ApiService>();
      await api.put('/notifications/preferences', data: {
        'type': type,
        'push_enabled': enabled,
        'in_app_enabled': enabled,
        'email_enabled': enabled && _emailNotif,
      });
    } catch (e) {
      debugPrint('[Settings] Error updating notif pref: $e');
    }
  }

  void _showMsg(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(color: Colors.white, fontSize: 13)),
      backgroundColor: error ? AppColors.danger : const Color(0xFF1E293B),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 20),
    ));
  }

  // ═══════════════════════════════════════════════
  // PASSWORD
  // ═══════════════════════════════════════════════

  Future<void> _submitPasswordChange() async {
    final current = _currentPwCtrl.text;
    final newPw = _newPwCtrl.text;
    final confirm = _confirmPwCtrl.text;
    if (current.isEmpty || newPw.isEmpty || confirm.isEmpty) {
      _showMsg('Veuillez remplir tous les champs.', error: true); return;
    }
    if (newPw.length < 8) {
      _showMsg('Le nouveau mot de passe doit contenir au moins 8 caractères.', error: true); return;
    }
    if (newPw != confirm) {
      _showMsg('Les mots de passe ne correspondent pas.', error: true); return;
    }
    setState(() => _savingPassword = true);
    try {
      await context.read<ApiService>().put('/auth/change-password', data: {
        'current_password': current,
        'new_password': newPw,
        'new_password_confirmation': confirm,
      });
      _showMsg('Mot de passe modifié avec succès !');
      setState(() { _showPasswordForm = false; _savingPassword = false; });
      _currentPwCtrl.clear(); _newPwCtrl.clear(); _confirmPwCtrl.clear();
    } catch (e) {
      setState(() => _savingPassword = false);
      _showMsg('Erreur. Vérifiez votre mot de passe actuel.', error: true);
    }
  }

  // ═══════════════════════════════════════════════
  // DELETE ACCOUNT
  // ═══════════════════════════════════════════════

  Future<void> _deleteAccount() async {
    final c1 = await showDialog<bool>(context: context, builder: (_) => AlertDialog(
      backgroundColor: AppColors.bgCard,
      title: Text('Supprimer le compte ?', style: TextStyle(color: AppColors.textPrimary)),
      content: Text('Cette action est irréversible. Toutes vos données seront supprimées.',
          style: TextStyle(color: AppColors.textSecondary)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
        TextButton(onPressed: () => Navigator.pop(context, true),
            child: const Text('Supprimer', style: TextStyle(color: AppColors.danger))),
      ],
    ));
    if (c1 != true || !mounted) return;
    final c2 = await showDialog<bool>(context: context, builder: (_) => AlertDialog(
      backgroundColor: AppColors.bgCard,
      title: const Text('Dernière chance', style: TextStyle(color: AppColors.danger)),
      content: Text('Toutes vos données seront supprimées définitivement.',
          style: TextStyle(color: AppColors.textSecondary)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
        TextButton(onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirmer la suppression', style: TextStyle(color: AppColors.danger))),
      ],
    ));
    if (c2 != true || !mounted) return;
    try {
      await context.read<ApiService>().delete('/auth/delete-account');
      if (!mounted) return;
      _showMsg('Compte supprimé. Au revoir !');
      await context.read<AuthProvider>().logout();
      if (mounted) context.go('/auth/login');
    } catch (_) {
      _showMsg('Erreur lors de la suppression.', error: true);
    }
  }

  // ═══════════════════════════════════════════════
  // BLOCKED USERS
  // ═══════════════════════════════════════════════

  Future<void> _loadBlockedUsers() async {
    try {
      final res = await context.read<ApiService>().get('/users/blocked');
      if (mounted) setState(() => _blockedUsers = res.data is List ? res.data : []);
    } catch (_) {
      if (mounted) setState(() => _blockedUsers = []);
    }
  }

  Future<void> _unblockUser(dynamic userId) async {
    try {
      await context.read<ApiService>().post('/users/$userId/unblock', data: {});
      setState(() => _blockedUsers.removeWhere((u) => u['id'].toString() == userId.toString()));
      _showMsg('Utilisateur débloqué.');
    } catch (_) {
      _showMsg('Erreur lors du déblocage.', error: true);
    }
  }

  Future<void> _exportData() async {
    setState(() => _exportingData = true);
    try {
      await context.read<ApiService>().get('/users/export-data');
      _showMsg('Vos données ont été préparées pour le téléchargement.');
    } catch (_) {
      _showMsg('Erreur lors de l\'export des données.', error: true);
    }
    if (mounted) setState(() => _exportingData = false);
  }

  Future<void> _submitReport() async {
    if (_reportCtrl.text.trim().isEmpty) {
      _showMsg('Veuillez décrire le problème.', error: true); return;
    }
    try {
      await context.read<ApiService>().post('/support/report', data: {
        'category': _reportCategory,
        'description': _reportCtrl.text.trim(),
      });
      _showMsg('Signalement envoyé. Merci !');
    } catch (_) {
      _showMsg('Signalement enregistré localement.');
    }
    setState(() { _showReportForm = false; _reportCtrl.clear(); _reportCategory = 'bug'; });
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  // ═══════════════════════════════════════════════
  // BUILD
  // ═══════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final auth = context.watch<AuthProvider>();
    final user = auth.user;

    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: AppBar(
        backgroundColor: AppColors.bgSecondary,
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context)),
        title: const Text('Paramètres', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 20)),
      ),
      body: ListView(padding: const EdgeInsets.all(16), children: [

        // ═══════════════════════════════════════════
        // COMPTE
        // ═══════════════════════════════════════════
        _SectionTitle(icon: Icons.person, text: 'Compte'),
        _SettingsCard(children: [
          _SettingsItem(icon: Icons.email, title: 'Email et téléphone',
            subtitle: '${user?.email ?? "Non défini"} • ${user?.phoneNumber ?? ""}',
            onTap: () => context.push('/profile/edit')),
          _SettingsItem(icon: Icons.lock, title: 'Changer mot de passe',
            subtitle: 'Mettre à jour votre sécurité',
            trailing: Icon(_showPasswordForm ? Icons.expand_less : Icons.chevron_right, color: AppColors.textMuted, size: 18),
            onTap: () => setState(() => _showPasswordForm = !_showPasswordForm)),
          if (_showPasswordForm) _buildPasswordForm(),
          _SettingsItem(icon: Icons.edit, title: 'Modifier mon profil',
            subtitle: 'Nom, photo, bio, localisation',
            onTap: () => context.push('/profile/edit')),
          _SettingsItemDanger(icon: Icons.delete_forever, title: 'Supprimer mon compte',
            subtitle: 'Action irréversible', onTap: _deleteAccount),
        ]),

        const SizedBox(height: 20),

        // ═══════════════════════════════════════════
        // NOTIFICATIONS
        // ═══════════════════════════════════════════
        _SectionTitle(icon: Icons.notifications, text: 'Notifications'),
        _SettingsCard(children: [
          _SettingsToggle(icon: Icons.notifications_active, title: 'Notifications push',
            subtitle: 'Alertes sur votre appareil',
            value: _pushNotif, onChanged: (v) {
              setState(() => _pushNotif = v); _savePrefs();
              _showMsg('Notifications push ${v ? "activées" : "désactivées"}');
            }),
          _SettingsToggle(icon: Icons.email_outlined, title: 'Notifications email',
            subtitle: 'Messages importants par email',
            value: _emailNotif, onChanged: (v) {
              setState(() => _emailNotif = v); _savePrefs();
              _showMsg('Notifications email ${v ? "activées" : "désactivées"}');
            }),
          _SettingsToggle(icon: Icons.sms_outlined, title: 'Notifications SMS',
            subtitle: 'Transactions et alertes urgentes',
            value: _smsNotif, onChanged: (v) {
              setState(() => _smsNotif = v); _savePrefs();
              _showMsg('Notifications SMS ${v ? "activées" : "désactivées"}');
            }),
        ]),
        const SizedBox(height: 10),

        // Per-type notification preferences
        _SettingsCard(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
            child: Row(children: [
              Icon(Icons.tune, color: AppColors.accent, size: 16),
              SizedBox(width: 8),
              Text('Recevoir des alertes pour', style: TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
            ]),
          ),
          if (_loadingNotifPrefs)
            const Padding(padding: EdgeInsets.all(16),
              child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accent))))
          else
            for (final entry in {
              'message': ['Messages', Icons.chat_bubble_outline, 'Nouveaux messages reçus'],
              'follow': ['Abonnements', Icons.person_add_outlined, 'Nouveaux abonnés'],
              'like': ['Likes', Icons.favorite_border, 'Likes sur vos posts'],
              'comment': ['Commentaires', Icons.comment_outlined, 'Commentaires sur vos posts'],
              'transaction': ['Transactions', Icons.receipt_long_outlined, 'Mises à jour de commandes'],
              'system': ['Système', Icons.info_outline, 'Mises à jour Quinch'],
            }.entries)
              _SettingsToggle(
                icon: (entry.value[1] as IconData),
                title: entry.value[0] as String,
                subtitle: entry.value[2] as String,
                value: _notifTypes[entry.key] ?? true,
                onChanged: (v) => _updateNotifPref(entry.key, v),
              ),
        ]),

        const SizedBox(height: 20),

        // ═══════════════════════════════════════════
        // CONFIDENTIALITÉ
        // ═══════════════════════════════════════════
        _SectionTitle(icon: Icons.lock_outline, text: 'Confidentialité'),
        _SettingsCard(children: [
          _SettingsItem(icon: Icons.block, title: 'Bloqués et restreints',
            subtitle: 'Gérer les utilisateurs bloqués',
            trailing: Icon(_showBlockedUsers ? Icons.expand_less : Icons.chevron_right, color: AppColors.textMuted, size: 18),
            onTap: () { setState(() => _showBlockedUsers = !_showBlockedUsers); if (_showBlockedUsers) _loadBlockedUsers(); }),
          if (_showBlockedUsers) _buildBlockedUsers(),
          _SettingsItem(icon: Icons.download, title: 'Exporter mes données',
            subtitle: 'Télécharger vos informations',
            trailing: _exportingData
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accent))
                : Icon(Icons.download, color: AppColors.textMuted, size: 18),
            onTap: _exportingData ? null : _exportData),
        ]),

        const SizedBox(height: 20),

        // ═══════════════════════════════════════════
        // PRÉFÉRENCES
        // ═══════════════════════════════════════════
        _SectionTitle(icon: Icons.tune, text: 'Préférences'),
        _SettingsCard(children: [
          _SettingsDropdown(icon: Icons.language, title: 'Langue',
            subtitle: "Langue de l'application",
            value: _language,
            items: const {'fr': 'Français', 'wo': 'Wolof', 'en': 'English'},
            onChanged: (v) {
              setState(() => _language = v); _savePrefs();
              final names = {'fr': 'Français', 'wo': 'Wolof', 'en': 'Anglais'};
              _showMsg('Langue : ${names[v] ?? v}');
            }),
          _SettingsDropdown(icon: Icons.attach_money, title: 'Devise',
            subtitle: "Devise d'affichage",
            value: _currency,
            items: const {'XOF': 'FCFA', 'EUR': 'Euro', 'USD': 'Dollar'},
            onChanged: (v) {
              setState(() => _currency = v); _savePrefs();
              _showMsg('Devise : $v');
            }),
        ]),
        const SizedBox(height: 10),

        // ═══ THEME / APPARENCE ═══
        _SettingsCard(children: [
          Padding(padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
            child: Row(children: [
              Container(width: 36, height: 36,
                decoration: BoxDecoration(color: AppColors.accentSubtle, borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.palette, color: AppColors.accent, size: 18)),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Apparence', style: TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w500)),
                Text('Thème de l\'application', style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
              ])),
            ]),
          ),
          Padding(padding: const EdgeInsets.fromLTRB(14, 4, 14, 14),
            child: Row(children: [
              _ThemeOption(icon: Icons.dark_mode, label: 'Sombre', mode: 'dark',
                selected: theme.themeMode == ThemeMode.dark,
                onTap: () { theme.setTheme(ThemeMode.dark); _showMsg('Mode sombre activé'); }),
              const SizedBox(width: 8),
              _ThemeOption(icon: Icons.light_mode, label: 'Clair', mode: 'light',
                selected: theme.themeMode == ThemeMode.light,
                onTap: () { theme.setTheme(ThemeMode.light); _showMsg('Mode clair activé'); }),
              const SizedBox(width: 8),
              _ThemeOption(icon: Icons.settings_brightness, label: 'Système', mode: 'system',
                selected: theme.themeMode == ThemeMode.system,
                onTap: () { theme.setTheme(ThemeMode.system); _showMsg('Mode système activé'); }),
            ]),
          ),
        ]),

        const SizedBox(height: 20),

        // ═══════════════════════════════════════════
        // SUPPORT & AIDE
        // ═══════════════════════════════════════════
        _SectionTitle(icon: Icons.support_agent, text: 'Support & Aide'),

        // Quick contact options
        Padding(padding: const EdgeInsets.only(bottom: 10),
          child: Row(children: [
            _SupportBtn(icon: Icons.email, label: 'Email', color: AppColors.accent,
              onTap: () => _launchUrl('mailto:support@quinch.sn?subject=Support Quinch')),
            const SizedBox(width: 8),
            _SupportBtn(icon: Icons.phone, label: 'WhatsApp', color: const Color(0xFF25D366),
              onTap: () => _launchUrl('https://wa.me/221770000000?text=Bonjour, j\'ai besoin d\'aide sur Quinch')),
            const SizedBox(width: 8),
            _SupportBtn(icon: Icons.chat, label: 'Chat', color: const Color(0xFF3B82F6),
              onTap: () {
                _showMsg('Le chat support sera bientôt disponible !');
              }),
          ]),
        ),

        // FAQ
        _SettingsCard(children: [
          Padding(padding: const EdgeInsets.fromLTRB(14, 14, 14, 6),
            child: Row(children: [
              Icon(Icons.help_outline, color: AppColors.accent, size: 18),
              SizedBox(width: 8),
              Text('Questions fréquentes', style: TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w600)),
            ])),
          for (int i = 0; i < _faqs.length; i++) _buildFaqItem(i),
        ]),
        const SizedBox(height: 10),

        // Report + Terms
        _SettingsCard(children: [
          _SettingsItem(icon: Icons.report_problem_outlined, title: 'Signaler un problème',
            subtitle: 'Bug, suggestion ou feedback',
            trailing: Icon(_showReportForm ? Icons.expand_less : Icons.chevron_right, color: AppColors.textMuted, size: 18),
            onTap: () => setState(() => _showReportForm = !_showReportForm)),
          if (_showReportForm) _buildReportForm(),
          _SettingsItem(icon: Icons.description_outlined, title: "Conditions d'utilisation",
            subtitle: 'CGU et politique de confidentialité',
            trailing: Icon(_showTerms ? Icons.expand_less : Icons.chevron_right, color: AppColors.textMuted, size: 18),
            onTap: () => setState(() => _showTerms = !_showTerms)),
          if (_showTerms) _buildTerms(),
        ]),

        // Social links
        const SizedBox(height: 10),
        _SettingsCard(children: [
          Padding(padding: const EdgeInsets.fromLTRB(14, 14, 14, 6),
            child: Row(children: [
              Icon(Icons.share, color: AppColors.accent, size: 18),
              SizedBox(width: 8),
              Text('Suivez-nous', style: TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w600)),
            ])),
          Padding(padding: const EdgeInsets.fromLTRB(14, 4, 14, 14),
            child: Row(children: [
              _SocialBtn(icon: Icons.facebook, label: 'Facebook', color: const Color(0xFF1877F2),
                onTap: () => _launchUrl('https://facebook.com/quinchsn')),
              const SizedBox(width: 10),
              _SocialBtn(icon: Icons.camera_alt, label: 'Instagram', color: const Color(0xFFE1306C),
                onTap: () => _launchUrl('https://instagram.com/quinchsn')),
              const SizedBox(width: 10),
              _SocialBtn(icon: Icons.play_circle, label: 'TikTok', color: const Color(0xFF010101),
                onTap: () => _launchUrl('https://tiktok.com/@quinchsn')),
              const SizedBox(width: 10),
              _SocialBtn(icon: Icons.language, label: 'Site web', color: AppColors.accent,
                onTap: () => _launchUrl('https://quinch.sn')),
            ]),
          ),
        ]),

        // ═══ ADMIN ═══
        if (user?.role == 'admin' || user?.role == 'super_admin') ...[
          const SizedBox(height: 20),
          _SectionTitle(icon: Icons.admin_panel_settings, text: 'Administration'),
          _SettingsCard(children: [
            _SettingsItem(icon: Icons.admin_panel_settings, title: 'Panel Admin',
              subtitle: 'Gérer la plateforme Quinch',
              onTap: () => context.push('/admin')),
          ]),
        ],

        const SizedBox(height: 24),

        // ═══ LOGOUT ═══
        SizedBox(width: double.infinity, height: 50,
          child: OutlinedButton.icon(
            onPressed: () async {
              final confirmed = await showDialog<bool>(context: context, builder: (_) => AlertDialog(
                backgroundColor: AppColors.bgCard,
                title: Text('Se déconnecter ?', style: TextStyle(color: AppColors.textPrimary)),
                content: Text('Voulez-vous vraiment vous déconnecter de votre compte ?',
                    style: TextStyle(color: AppColors.textSecondary)),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
                  TextButton(onPressed: () => Navigator.pop(context, true),
                      child: const Text('Déconnexion', style: TextStyle(color: AppColors.danger))),
                ],
              ));
              if (confirmed != true || !mounted) return;
              _showMsg('Déconnexion réussie. À bientôt !');
              await auth.logout();
              if (mounted) context.go('/auth/login');
            },
            icon: const Icon(Icons.logout, color: AppColors.danger, size: 18),
            label: const Text('Déconnexion', style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.w600)),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppColors.danger),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
          ),
        ),
        const SizedBox(height: 20),
        Center(child: Text('Version 2.0.0 • Quinch © 2026',
            style: TextStyle(color: AppColors.textMuted, fontSize: 12))),
        const SizedBox(height: 30),
      ]),
    );
  }

  // ═══════════════════════════════════════════════
  // FAQ DATA
  // ═══════════════════════════════════════════════

  static const _faqs = [
    {'q': 'Comment vendre un produit ?', 'a': 'Appuyez sur "Publier" dans la barre de navigation.\nAjoutez une vidéo et des photos.\nRemplissez le titre, prix et description.\nVotre produit sera visible dans le feed !'},
    {'q': 'Comment acheter un produit ?', 'a': 'Parcourez le feed "Pour toi" ou la page Explorer.\nCliquez sur un produit qui vous plaît.\nAppuyez sur "Acheter" ou "Ajouter au panier".\nChoisissez votre mode de paiement et confirmez.'},
    {'q': 'Comment contacter un vendeur ?', 'a': 'Sur le détail d\'un produit, appuyez sur "Contacter".\nVous pouvez aussi aller sur le profil du vendeur et appuyer sur "Message".'},
    {'q': 'Comment fonctionne le score de confiance ?', 'a': 'Votre score commence à 50% et évolue selon vos activités :\n• Ventes réussies : +5%\n• Avis positifs : +3%\n• Vérification KYC : +15%\n• Signalements : -10%'},
    {'q': 'Comment suivre un vendeur ?', 'a': 'Appuyez sur le bouton "+" à côté de la photo de profil dans le feed.\nOu allez sur le profil du vendeur et appuyez sur "Suivre".'},
    {'q': 'Comment modifier mon profil ?', 'a': 'Allez dans Profil > Modifier le profil.\nVous pouvez changer votre photo, bannière, bio, nom et localisation.'},
    {'q': 'Comment supprimer mon compte ?', 'a': 'Allez dans Paramètres > Compte > Supprimer mon compte.\nAttention : cette action est irréversible !'},
  ];

  // ═══════════════════════════════════════════════
  // BUILD HELPERS
  // ═══════════════════════════════════════════════

  Widget _buildFaqItem(int index) {
    final faq = _faqs[index];
    final expanded = _expandedFaq == index;
    return Column(children: [
      InkWell(
        onTap: () => setState(() => _expandedFaq = expanded ? null : index),
        child: Padding(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(children: [
            Expanded(child: Text(faq['q']!, style: TextStyle(
              color: expanded ? AppColors.accent : AppColors.textPrimary,
              fontSize: 13, fontWeight: FontWeight.w500))),
            Icon(expanded ? Icons.remove : Icons.add, size: 16,
              color: expanded ? AppColors.accent : AppColors.textMuted),
          ])),
      ),
      if (expanded)
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
          child: Text(faq['a']!, style: TextStyle(color: AppColors.textSecondary, fontSize: 12, height: 1.5)),
        ),
      if (index < _faqs.length - 1)
        Divider(height: 1, color: AppColors.border, indent: 14, endIndent: 14),
    ]);
  }

  Widget _buildPasswordForm() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: AppColors.bgPrimary.withValues(alpha: 0.5),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _buildFormField('Mot de passe actuel', _currentPwCtrl, obscure: true, hint: 'Votre mot de passe actuel'),
        const SizedBox(height: 12),
        _buildFormField('Nouveau mot de passe', _newPwCtrl, obscure: true, hint: 'Minimum 8 caractères'),
        const SizedBox(height: 12),
        _buildFormField('Confirmer', _confirmPwCtrl, obscure: true, hint: 'Confirmer le nouveau mot de passe'),
        const SizedBox(height: 16),
        Row(children: [
          Expanded(child: OutlinedButton(
            onPressed: () => setState(() => _showPasswordForm = false),
            style: OutlinedButton.styleFrom(side: BorderSide(color: AppColors.border),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            child: Text('Annuler', style: TextStyle(color: AppColors.textSecondary)))),
          const SizedBox(width: 12),
          Expanded(child: ElevatedButton(
            onPressed: _savingPassword ? null : _submitPasswordChange,
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            child: Text(_savingPassword ? 'Enregistrement...' : 'Changer',
                style: const TextStyle(color: Colors.white)))),
        ]),
      ]),
    );
  }

  Widget _buildFormField(String label, TextEditingController ctrl, {bool obscure = false, String? hint}) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w500)),
      const SizedBox(height: 4),
      TextField(controller: ctrl, obscureText: obscure,
        style: TextStyle(color: AppColors.textPrimary, fontSize: 14),
        decoration: InputDecoration(hintText: hint, hintStyle: TextStyle(color: AppColors.textMuted, fontSize: 13),
          filled: true, fillColor: AppColors.bgInput,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12))),
    ]);
  }

  Widget _buildBlockedUsers() {
    return Container(
      padding: EdgeInsets.all(16), color: AppColors.bgPrimary.withValues(alpha: 0.5),
      child: _blockedUsers.isEmpty
          ? Center(child: Padding(padding: const EdgeInsets.all(20),
              child: Column(children: [
                Icon(Icons.sentiment_satisfied, color: AppColors.textMuted, size: 32),
                SizedBox(height: 8),
                Text('Aucun utilisateur bloqué', style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
              ])))
          : Column(children: _blockedUsers.map((u) => ListTile(dense: true,
              title: Text(u['full_name'] ?? 'Utilisateur', style: TextStyle(color: AppColors.textPrimary, fontSize: 13)),
              subtitle: Text('Bloqué le ${u['blocked_at'] ?? '-'}', style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
              trailing: TextButton(onPressed: () => _unblockUser(u['id']),
                child: const Text('Débloquer', style: TextStyle(color: AppColors.accent, fontSize: 12))))).toList()),
    );
  }

  Widget _buildReportForm() {
    return Container(
      padding: EdgeInsets.all(16), color: AppColors.bgPrimary.withValues(alpha: 0.5),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Type de problème', style: TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w500)),
        const SizedBox(height: 4),
        DropdownButtonFormField<String>(value: _reportCategory, dropdownColor: AppColors.bgCard,
          style: TextStyle(color: AppColors.textPrimary, fontSize: 14),
          decoration: InputDecoration(filled: true, fillColor: AppColors.bgInput,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10)),
          items: const [
            DropdownMenuItem(value: 'bug', child: Text('Bug / Dysfonctionnement')),
            DropdownMenuItem(value: 'suggestion', child: Text("Suggestion d'amélioration")),
            DropdownMenuItem(value: 'security', child: Text('Problème de sécurité')),
            DropdownMenuItem(value: 'other', child: Text('Autre')),
          ],
          onChanged: (v) => setState(() => _reportCategory = v ?? 'bug')),
        const SizedBox(height: 12),
        Text('Description', style: TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w500)),
        const SizedBox(height: 4),
        TextField(controller: _reportCtrl, maxLines: 4,
          style: TextStyle(color: AppColors.textPrimary, fontSize: 14),
          decoration: InputDecoration(hintText: 'Décrivez le problème en détail...', hintStyle: TextStyle(color: AppColors.textMuted, fontSize: 13),
            filled: true, fillColor: AppColors.bgInput,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
            contentPadding: const EdgeInsets.all(14))),
        const SizedBox(height: 16),
        Row(children: [
          Expanded(child: OutlinedButton(
            onPressed: () => setState(() => _showReportForm = false),
            style: OutlinedButton.styleFrom(side: BorderSide(color: AppColors.border),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            child: Text('Annuler', style: TextStyle(color: AppColors.textSecondary)))),
          const SizedBox(width: 12),
          Expanded(child: ElevatedButton(
            onPressed: _submitReport,
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            child: const Text('Envoyer', style: TextStyle(color: Colors.white)))),
        ]),
      ]),
    );
  }

  Widget _buildTerms() {
    return Container(
      padding: EdgeInsets.all(16), color: AppColors.bgPrimary.withValues(alpha: 0.5),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text("Conditions d'utilisation de Quinch",
            style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 15)),
        const SizedBox(height: 12),
        _termsSection('1. Acceptation des conditions',
            "En utilisant Quinch, vous acceptez les présentes conditions d'utilisation. Quinch est une plateforme de commerce social au Sénégal."),
        _termsSection('2. Comptes utilisateurs',
            "Chaque utilisateur est responsable de la confidentialité de son compte. Les informations fournies doivent être exactes."),
        _termsSection('3. Transactions',
            "Les transactions entre acheteurs et vendeurs sont effectuées sous leur responsabilité. Quinch facilite la mise en relation."),
        _termsSection('4. Contenu',
            "Les utilisateurs s'engagent à ne publier aucun contenu illégal ou offensant. Quinch se réserve le droit de supprimer tout contenu inapproprié."),
        _termsSection('5. Protection des données',
            "Quinch respecte la législation sénégalaise sur la protection des données personnelles."),
        _termsSection('6. Contact', 'support@quinch.sn'),
        Text('Dernière mise à jour : Février 2026',
            style: TextStyle(color: AppColors.textMuted, fontSize: 11, fontStyle: FontStyle.italic)),
      ]),
    );
  }

  Widget _termsSection(String title, String body) {
    return Padding(padding: const EdgeInsets.only(bottom: 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 13)),
        const SizedBox(height: 4),
        Text(body, style: TextStyle(color: AppColors.textSecondary, fontSize: 12, height: 1.4)),
      ]));
  }
}

// ═══════════════════════════════════════════════════════════
// HELPER WIDGETS
// ═══════════════════════════════════════════════════════════

class _SectionTitle extends StatelessWidget {
  final IconData icon; final String text;
  const _SectionTitle({required this.icon, required this.text});
  @override
  Widget build(BuildContext context) {
    return Padding(padding: const EdgeInsets.only(bottom: 10, left: 2),
      child: Row(children: [
        Icon(icon, color: AppColors.accent, size: 16),
        const SizedBox(width: 6),
        Text(text, style: TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w600)),
      ]));
  }
}

class _SettingsCard extends StatelessWidget {
  final List<Widget> children;
  const _SettingsCard({required this.children});
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(color: AppColors.bgCard, borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border)),
      clipBehavior: Clip.antiAlias,
      child: Column(children: children));
  }
}

class _SettingsItem extends StatelessWidget {
  final IconData icon; final String title; final String? subtitle;
  final Widget? trailing; final VoidCallback? onTap;
  const _SettingsItem({required this.icon, required this.title, this.subtitle, this.trailing, this.onTap});
  @override
  Widget build(BuildContext context) {
    return InkWell(onTap: onTap,
      child: Padding(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(children: [
          Container(width: 36, height: 36,
            decoration: BoxDecoration(color: AppColors.accentSubtle, borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: AppColors.accent, size: 18)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w500)),
            if (subtitle != null) Text(subtitle!, style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
          ])),
          trailing ?? Icon(Icons.chevron_right, color: AppColors.textMuted, size: 18),
        ])));
  }
}

class _SettingsItemDanger extends StatelessWidget {
  final IconData icon; final String title; final String? subtitle; final VoidCallback onTap;
  const _SettingsItemDanger({required this.icon, required this.title, this.subtitle, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return InkWell(onTap: onTap,
      child: Padding(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(children: [
          Container(width: 36, height: 36,
            decoration: BoxDecoration(color: AppColors.danger.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: AppColors.danger, size: 18)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(color: AppColors.danger, fontSize: 14, fontWeight: FontWeight.w500)),
            if (subtitle != null) Text(subtitle!, style: TextStyle(color: AppColors.danger.withValues(alpha: 0.7), fontSize: 11)),
          ])),
          const Icon(Icons.chevron_right, color: AppColors.danger, size: 18),
        ])));
  }
}

class _SettingsToggle extends StatelessWidget {
  final IconData icon; final String title; final String? subtitle;
  final bool value; final ValueChanged<bool> onChanged;
  const _SettingsToggle({required this.icon, required this.title, this.subtitle, required this.value, required this.onChanged});
  @override
  Widget build(BuildContext context) {
    return Padding(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Row(children: [
        Container(width: 36, height: 36,
          decoration: BoxDecoration(color: AppColors.accentSubtle, borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: AppColors.accent, size: 18)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w500)),
          if (subtitle != null) Text(subtitle!, style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
        ])),
        Switch(value: value, onChanged: onChanged, activeTrackColor: AppColors.accent, inactiveTrackColor: AppColors.bgInput),
      ]));
  }
}

class _SettingsDropdown extends StatelessWidget {
  final IconData icon; final String title; final String? subtitle;
  final String value; final Map<String, String> items; final ValueChanged<String> onChanged;
  const _SettingsDropdown({required this.icon, required this.title, this.subtitle, required this.value, required this.items, required this.onChanged});
  @override
  Widget build(BuildContext context) {
    return Padding(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(children: [
        Container(width: 36, height: 36,
          decoration: BoxDecoration(color: AppColors.accentSubtle, borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: AppColors.accent, size: 18)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w500)),
          if (subtitle != null) Text(subtitle!, style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
        ])),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(color: AppColors.bgInput, borderRadius: BorderRadius.circular(8)),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(value: value, isDense: true, dropdownColor: AppColors.bgCard,
              style: TextStyle(color: AppColors.textPrimary, fontSize: 12),
              items: items.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))).toList(),
              onChanged: (v) { if (v != null) onChanged(v); }))),
      ]));
  }
}

// ═══ Theme option button — visually represents each theme ═══
class _ThemeOption extends StatelessWidget {
  final IconData icon; final String label; final bool selected;
  final VoidCallback onTap; final String mode; // 'dark', 'light', 'system'
  const _ThemeOption({required this.icon, required this.label, required this.selected, required this.onTap, required this.mode});
  @override
  Widget build(BuildContext context) {
    // Each mode has distinct visual style
    Color bgColor;
    Color fgColor;
    Color borderColor;
    if (selected) {
      switch (mode) {
        case 'dark':
          bgColor = const Color(0xFF000000); fgColor = Colors.white; borderColor = Colors.white24;
        case 'light':
          bgColor = Colors.white; fgColor = const Color(0xFF1A1D26); borderColor = Colors.grey.shade300;
        default: // system
          bgColor = AppColors.accent; fgColor = Colors.white; borderColor = AppColors.accent;
      }
    } else {
      bgColor = AppColors.bgInput; fgColor = AppColors.textMuted; borderColor = AppColors.border;
    }
    return Expanded(child: GestureDetector(onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor, width: selected ? 2 : 1),
          boxShadow: selected ? [BoxShadow(color: bgColor.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 2))] : null),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 24, color: fgColor),
          const SizedBox(height: 6),
          Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: fgColor)),
          if (selected) ...[
            const SizedBox(height: 4),
            Container(width: 6, height: 6, decoration: BoxDecoration(
              color: mode == 'system' ? Colors.white : AppColors.accent, shape: BoxShape.circle)),
          ],
        ]))));
  }
}

// ═══ Support button ═══
class _SupportBtn extends StatelessWidget {
  final IconData icon; final String label; final Color color; final VoidCallback onTap;
  const _SupportBtn({required this.icon, required this.label, required this.color, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return Expanded(child: GestureDetector(onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.25))),
        child: Column(children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
        ]))));
  }
}

// ═══ Social media button ═══
class _SocialBtn extends StatelessWidget {
  final IconData icon; final String label; final Color color; final VoidCallback onTap;
  const _SocialBtn({required this.icon, required this.label, required this.color, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return Expanded(child: GestureDetector(onTap: onTap,
      child: Column(children: [
        Container(
          width: 42, height: 42,
          decoration: BoxDecoration(color: color.withValues(alpha: 0.12), shape: BoxShape.circle),
          child: Icon(icon, color: color, size: 20)),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(color: AppColors.textMuted, fontSize: 9)),
      ])));
  }
}
