import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../config/api_config.dart';
import '../../config/theme.dart';
import '../../services/api_service.dart';
import '../../widgets/quinch_logo.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _showServerConfig() async {
    final ctrl = TextEditingController(text: ApiConfig.serverUrl);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bgSecondary,
        title: Text('Configuration serveur',
            style: TextStyle(color: AppColors.textPrimary, fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('URL actuelle : ${ApiConfig.serverUrl}',
                style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              style: TextStyle(color: AppColors.textPrimary, fontSize: 14),
              decoration: InputDecoration(
                labelText: 'URL du serveur',
                hintText: 'http://192.168.x.x:8000',
                labelStyle: TextStyle(color: AppColors.textMuted, fontSize: 13),
                hintStyle: TextStyle(color: AppColors.textMuted),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Exemple : http://192.168.1.4:8000\n'
              'Émulateur : http://10.0.2.2:8000',
              style: TextStyle(color: AppColors.textMuted, fontSize: 10),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await ApiConfig.resetServerUrl();
              if (ctx.mounted) Navigator.pop(ctx, 'reset');
            },
            child: const Text('Auto-détecter', style: TextStyle(color: AppColors.info, fontSize: 13)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Annuler', style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent),
            child: const Text('Enregistrer', style: TextStyle(color: Colors.white, fontSize: 13)),
          ),
        ],
      ),
    );

    if (result != null && mounted) {
      if (result != 'reset' && result.isNotEmpty) {
        await ApiConfig.setServerUrl(result);
      }
      // Rebuild Dio with new base URL
      context.read<ApiService>().refreshBaseUrl();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Serveur : ${ApiConfig.serverUrl}',
              style: const TextStyle(fontSize: 12)),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
      setState(() {});
    }
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    final auth = context.read<AuthProvider>();
    final success = await auth.login(
      phoneNumber: _phoneController.text.trim(),
      password: _passwordController.text,
    );

    if (success && mounted) {
      // Show welcome toast like the frontend
      final name = auth.user?.fullName ?? auth.user?.username ?? '';
      final msg = name.isNotEmpty
          ? 'Bienvenue sur Quinch, $name ! Découvrez les dernières offres.'
          : 'Bienvenue sur Quinch ! Découvrez les dernières offres.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.waving_hand, color: Colors.amber, size: 20),
              const SizedBox(width: 10),
              Expanded(child: Text(msg, style: const TextStyle(color: Colors.white, fontSize: 13))),
            ],
          ),
          backgroundColor: const Color(0xFF1E293B),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 20),
          duration: const Duration(seconds: 4),
        ),
      );
      context.go('/feed');
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const SizedBox(height: 20),

              // ═══ HEADER : logo + texte sur une ligne ═══
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const QuinchLogo(size: 40),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('QUINCH',
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.textPrimary, letterSpacing: -0.5)),
                      Text('Investissons entre nous',
                        style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // ═══ FORMULAIRE ═══
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Error
                      if (auth.error != null) ...[
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.dangerSubtle,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppColors.danger.withValues(alpha: 0.3)),
                          ),
                          child: Row(children: [
                            const Icon(Icons.error_outline, color: AppColors.danger, size: 16),
                            const SizedBox(width: 8),
                            Expanded(child: Text(auth.error!, style: const TextStyle(color: AppColors.danger, fontSize: 12))),
                          ]),
                        ),
                        const SizedBox(height: 12),
                      ],

                      Text('Connexion',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                      const SizedBox(height: 4),
                      Text('Connectez-vous à votre compte',
                        style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                      const SizedBox(height: 20),

                      Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Phone
                            TextFormField(
                              controller: _phoneController,
                              keyboardType: TextInputType.phone,
                              style: TextStyle(color: AppColors.textPrimary),
                              decoration: InputDecoration(
                                labelText: 'Numéro de téléphone',
                                labelStyle: TextStyle(color: AppColors.textMuted, fontSize: 13),
                                hintText: '77 123 45 67',
                                prefixIcon: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12),
                                  margin: const EdgeInsets.only(right: 4),
                                  decoration: BoxDecoration(
                                    border: Border(right: BorderSide(color: AppColors.border)),
                                  ),
                                  child: Center(
                                    widthFactor: 1,
                                    child: Text('+221', style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w600, fontSize: 14)),
                                  ),
                                ),
                                prefixIconConstraints: const BoxConstraints(),
                              ),
                              validator: (v) => v == null || v.trim().isEmpty ? 'Numéro requis' : null,
                            ),

                            const SizedBox(height: 14),

                            // Password
                            TextFormField(
                              controller: _passwordController,
                              obscureText: _obscurePassword,
                              style: TextStyle(color: AppColors.textPrimary),
                              decoration: InputDecoration(
                                labelText: 'Mot de passe',
                                labelStyle: TextStyle(color: AppColors.textMuted, fontSize: 13),
                                hintText: 'Votre mot de passe',
                                prefixIcon: Icon(Icons.lock_outline, color: AppColors.textMuted, size: 20),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                    color: AppColors.textMuted, size: 20,
                                  ),
                                  onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                                ),
                              ),
                              validator: (v) => v == null || v.isEmpty ? 'Mot de passe requis' : null,
                            ),

                            const SizedBox(height: 20),

                            // Submit
                            SizedBox(
                              width: double.infinity,
                              height: 48,
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  gradient: AppColors.primaryGradient,
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: [BoxShadow(color: AppColors.accent.withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 4))],
                                ),
                                child: ElevatedButton(
                                  onPressed: auth.isLoading ? null : _login,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.transparent,
                                    shadowColor: Colors.transparent,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                  child: auth.isLoading
                                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                      : const Text('Se connecter', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white)),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 14),

                      // Demo credentials
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.infoSubtle,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.info.withValues(alpha: 0.2)),
                        ),
                        child: Row(children: [
                          Icon(Icons.info_outline, color: AppColors.info, size: 16),
                          SizedBox(width: 8),
                          Expanded(child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Admin : 770000001 / password', style: TextStyle(color: AppColors.textSecondary, fontSize: 11)),
                              Text('Client : 770000010 / password', style: TextStyle(color: AppColors.textSecondary, fontSize: 11)),
                            ],
                          )),
                        ]),
                      ),
                    ],
                  ),
                ),
              ),

              // ═══ FOOTER FIXE EN BAS ═══
              Padding(
                padding: const EdgeInsets.only(top: 8, bottom: 8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: double.infinity,
                      height: 44,
                      child: OutlinedButton(
                        onPressed: () => context.go('/auth/register'),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: AppColors.border),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: Text('Créer un compte', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 14)),
                      ),
                    ),
                    TextButton(
                      onPressed: () => context.go('/feed'),
                      child: Text('Explorer sans compte', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                    ),
                    // Server config button (for dev)
                    GestureDetector(
                      onTap: _showServerConfig,
                      child: Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.settings_ethernet, size: 13, color: AppColors.textMuted),
                            const SizedBox(width: 4),
                            Text(
                              ApiConfig.serverUrl,
                              style: TextStyle(color: AppColors.textMuted, fontSize: 10),
                            ),
                          ],
                        ),
                      ),
                    ),
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
