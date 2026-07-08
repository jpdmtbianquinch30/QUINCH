import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../config/theme.dart';
import '../../widgets/quinch_logo.dart';

class GoogleLoginScreen extends StatefulWidget {
  const GoogleLoginScreen({super.key});

  @override
  State<GoogleLoginScreen> createState() => _GoogleLoginScreenState();
}

class _GoogleLoginScreenState extends State<GoogleLoginScreen> {
  bool _loading = false;
  String? _error;

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile'],
    clientId: '771019520770-siehda850rkgqk7ah04n3n1ku84rb7pc.apps.googleusercontent.com',
  );

  Future<void> _signInWithGoogle() async {
    setState(() { _loading = true; _error = null; });

    try {
      debugPrint('[Google] Attempting sign in...');
      final account = await _googleSignIn.signIn();
      debugPrint('[Google] Account: $account');
      if (account == null) {
        debugPrint('[Google] User cancelled');
        setState(() { _loading = false; });
        return;
      }

      final auth = await account.authentication;
      final idToken = auth.idToken;

      if (idToken == null) {
        setState(() {
          _loading = false;
          _error = 'Impossible d\'obtenir le token Google.';
        });
        return;
      }

      if (!mounted) return;
      final authProvider = context.read<AuthProvider>();
      final result = await authProvider.loginWithGoogle(idToken: idToken);

      if (!mounted) return;

      if (result['success'] == true) {
        if (result['needs_phone'] == true) {
          context.go('/google-add-phone');
        } else if (result['needs_username'] == true) {
          context.go('/google-add-username');
        } else {
          context.go('/home');
        }
      } else {
        setState(() { _error = result['error'] ?? 'Erreur de connexion Google.'; });
      }
    } catch (e) {
      setState(() { _error = 'Erreur : $e'; });
    } finally {
      if (mounted) setState(() { _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const QuinchLogo(size: 60),
              const SizedBox(height: 16),
              Text('QUINCH',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary, letterSpacing: -0.5)),
              Text('Investissons entre nous',
                style: TextStyle(fontSize: 14, color: AppColors.textMuted)),
              const SizedBox(height: 48),

              if (_error != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.dangerSubtle,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.danger.withValues(alpha: 0.3)),
                  ),
                  child: Text(_error!,
                    style: const TextStyle(color: AppColors.danger, fontSize: 13)),
                ),
                const SizedBox(height: 16),
              ],

              // Bouton Google
              SizedBox(
                width: double.infinity,
                height: 52,
                child: OutlinedButton.icon(
                  onPressed: _loading ? null : _signInWithGoogle,
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: AppColors.border, width: 1.5),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    backgroundColor: AppColors.bgSecondary,
                  ),
                  icon: _loading
                    ? const SizedBox(width: 20, height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : Image.network(
                        'https://www.google.com/favicon.ico',
                        width: 22, height: 22,
                        errorBuilder: (_, __, ___) =>
                          const Icon(Icons.g_mobiledata, size: 24),
                      ),
                  label: Text(
                    _loading ? 'Connexion...' : 'Continuer avec Google',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              Row(children: [
                Expanded(child: Divider(color: AppColors.border)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text('ou', style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
                ),
                Expanded(child: Divider(color: AppColors.border)),
              ]),

              const SizedBox(height: 16),

              // Bouton connexion classique
              SizedBox(
                width: double.infinity,
                height: 52,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: ElevatedButton(
                    onPressed: () => context.go('/login'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text('Se connecter avec téléphone',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white)),
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // Créer un compte
              TextButton(
                onPressed: () => context.go('/register'),
                child: Text('Pas encore de compte ? Créer un compte',
                  style: TextStyle(color: AppColors.accent, fontSize: 13)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}