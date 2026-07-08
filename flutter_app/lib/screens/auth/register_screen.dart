import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../config/theme.dart';
import '../../widgets/quinch_logo.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  // Password strength indicators
  bool _hasMinLength = false;
  bool _hasUppercase = false;
  bool _hasDigit = false;

  @override
  void initState() {
    super.initState();
    _passwordController.addListener(_checkPasswordStrength);
  }

  void _checkPasswordStrength() {
    final p = _passwordController.text;
    setState(() {
      _hasMinLength = p.length >= 8;
      _hasUppercase = p.contains(RegExp(r'[A-Z]'));
      _hasDigit = p.contains(RegExp(r'[0-9]'));
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _usernameController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;

    final auth = context.read<AuthProvider>();
    final success = await auth.register(
      fullName: _nameController.text.trim(),
      username: _usernameController.text.trim().toLowerCase(),
      phoneNumber: _phoneController.text.trim(),
      password: _passwordController.text,
      passwordConfirmation: _confirmController.text,
    );

    if (success && mounted) {
      context.go('/onboarding');
    }
  }

  String? _validatePassword(String? v) {
    if (v == null || v.isEmpty) return 'Mot de passe requis';
    if (v.length < 8) return 'Minimum 8 caractères';
    if (!v.contains(RegExp(r'[A-Z]'))) return '1 lettre majuscule requise';
    if (!v.contains(RegExp(r'[0-9]'))) return '1 chiffre requis';
    return null;
  }

  String? _validateUsername(String? v) {
    if (v == null || v.trim().isEmpty) return "Nom d'utilisateur requis";
    final clean = v.trim();
    if (clean.length < 3) return 'Minimum 3 caractères';
    if (clean.length > 30) return 'Maximum 30 caractères';
    if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(clean)) {
      return 'Lettres, chiffres et _ uniquement';
    }
    return null;
  }

  Widget _strengthIndicator(bool met, String label) {
    return Row(
      children: [
        Icon(
          met ? Icons.check_circle : Icons.radio_button_unchecked,
          size: 14,
          color: met ? Colors.green : AppColors.textMuted,
        ),
        const SizedBox(width: 4),
        Text(label,
            style: TextStyle(
                fontSize: 11,
                color: met ? Colors.green : AppColors.textMuted)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final passwordStarted = _passwordController.text.isNotEmpty;

    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const SizedBox(height: 20),

              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const QuinchLogo(size: 40),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('QUINCH',
                          style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                              letterSpacing: -0.5)),
                      Text('Rejoignez la communauté',
                          style: TextStyle(
                              fontSize: 11, color: AppColors.textMuted)),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 16),

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
                            border: Border.all(
                                color:
                                    AppColors.danger.withValues(alpha: 0.3)),
                          ),
                          child: Row(children: [
                            const Icon(Icons.error_outline,
                                color: AppColors.danger, size: 16),
                            const SizedBox(width: 8),
                            Expanded(
                                child: Text(auth.error!,
                                    style: const TextStyle(
                                        color: AppColors.danger,
                                        fontSize: 12))),
                          ]),
                        ),
                        const SizedBox(height: 10),
                      ],

                      Text('Créer un compte',
                          style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary)),
                      const SizedBox(height: 4),
                      Text('Inscription gratuite',
                          style: TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary)),
                      const SizedBox(height: 16),

                      Form(
                        key: _formKey,
                        child: Column(
                          children: [
                            // Nom complet
                            TextFormField(
                              controller: _nameController,
                              textCapitalization: TextCapitalization.words,
                              style: TextStyle(color: AppColors.textPrimary),
                              decoration: InputDecoration(
                                labelText: 'Nom complet',
                                labelStyle: TextStyle(
                                    color: AppColors.textMuted, fontSize: 13),
                                hintText: 'Abdoulaye Diallo',
                                prefixIcon: Icon(Icons.person_outline,
                                    color: AppColors.textMuted, size: 20),
                              ),
                              validator: (v) => v == null || v.trim().isEmpty
                                  ? 'Nom requis'
                                  : null,
                            ),

                            const SizedBox(height: 12),

                            // Username
                            TextFormField(
                              controller: _usernameController,
                              style: TextStyle(color: AppColors.textPrimary),
                              decoration: InputDecoration(
                                labelText: "Nom d'utilisateur",
                                labelStyle: TextStyle(
                                    color: AppColors.textMuted, fontSize: 13),
                                hintText: 'abdoulaye_77',
                                prefixIcon: Icon(Icons.alternate_email,
                                    color: AppColors.textMuted, size: 20),
                                helperText:
                                    'Lettres, chiffres et _ uniquement',
                                helperStyle: TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textMuted),
                              ),
                              validator: _validateUsername,
                            ),

                            const SizedBox(height: 12),

                            // Téléphone
                            TextFormField(
                              controller: _phoneController,
                              keyboardType: TextInputType.phone,
                              style: TextStyle(color: AppColors.textPrimary),
                              decoration: InputDecoration(
                                labelText: 'Numéro de téléphone',
                                labelStyle: TextStyle(
                                    color: AppColors.textMuted, fontSize: 13),
                                hintText: '77 123 45 67',
                                prefixIcon: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12),
                                  margin: const EdgeInsets.only(right: 4),
                                  decoration: BoxDecoration(
                                    border: Border(
                                        right: BorderSide(
                                            color: AppColors.border)),
                                  ),
                                  child: Center(
                                    widthFactor: 1,
                                    child: Text('+221',
                                        style: TextStyle(
                                            color: AppColors.textSecondary,
                                            fontWeight: FontWeight.w600,
                                            fontSize: 14)),
                                  ),
                                ),
                                prefixIconConstraints:
                                    const BoxConstraints(),
                              ),
                              validator: (v) =>
                                  v == null || v.trim().isEmpty
                                      ? 'Numéro requis'
                                      : null,
                            ),

                            const SizedBox(height: 12),

                            // Mot de passe
                            TextFormField(
                              controller: _passwordController,
                              obscureText: _obscurePassword,
                              style: TextStyle(
                                  color: AppColors.textPrimary, fontSize: 14),
                              decoration: InputDecoration(
                                labelText: 'Mot de passe',
                                labelStyle: TextStyle(
                                    color: AppColors.textMuted, fontSize: 13),
                                hintText: 'Min. 8 car., 1 maj., 1 chiffre',
                                hintStyle: const TextStyle(fontSize: 12),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                      _obscurePassword
                                          ? Icons.visibility_off_outlined
                                          : Icons.visibility_outlined,
                                      color: AppColors.textMuted,
                                      size: 18),
                                  onPressed: () => setState(() =>
                                      _obscurePassword = !_obscurePassword),
                                ),
                              ),
                              validator: _validatePassword,
                            ),

                            // Indicateurs de force
                            if (passwordStarted) ...[
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  _strengthIndicator(
                                      _hasMinLength, '8 caractères'),
                                  const SizedBox(width: 12),
                                  _strengthIndicator(
                                      _hasUppercase, '1 majuscule'),
                                  const SizedBox(width: 12),
                                  _strengthIndicator(_hasDigit, '1 chiffre'),
                                ],
                              ),
                            ],

                            const SizedBox(height: 12),

                            // Confirmer mot de passe
                            TextFormField(
                              controller: _confirmController,
                              obscureText: _obscureConfirm,
                              style: TextStyle(
                                  color: AppColors.textPrimary, fontSize: 14),
                              decoration: InputDecoration(
                                labelText: 'Confirmer le mot de passe',
                                labelStyle: TextStyle(
                                    color: AppColors.textMuted, fontSize: 13),
                                hintText: 'Répétez le mot de passe',
                                hintStyle: const TextStyle(fontSize: 12),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                      _obscureConfirm
                                          ? Icons.visibility_off_outlined
                                          : Icons.visibility_outlined,
                                      color: AppColors.textMuted,
                                      size: 18),
                                  onPressed: () => setState(() =>
                                      _obscureConfirm = !_obscureConfirm),
                                ),
                              ),
                              validator: (v) =>
                                  v != _passwordController.text
                                      ? 'Les mots de passe ne correspondent pas'
                                      : null,
                            ),

                            const SizedBox(height: 20),

                            // Bouton inscription
                            SizedBox(
                              width: double.infinity,
                              height: 48,
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  gradient: AppColors.primaryGradient,
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: [
                                    BoxShadow(
                                        color: AppColors.accent
                                            .withValues(alpha: 0.3),
                                        blurRadius: 12,
                                        offset: const Offset(0, 4))
                                  ],
                                ),
                                child: ElevatedButton(
                                  onPressed:
                                      auth.isLoading ? null : _register,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.transparent,
                                    shadowColor: Colors.transparent,
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(12)),
                                  ),
                                  child: auth.isLoading
                                      ? const SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.white))
                                      : const Text('Créer mon compte',
                                          style: TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.white)),
                                ),
                              ),
                            ),

                            const SizedBox(height: 16),

                            // Lien connexion
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text('Déjà un compte ? ',
                                    style: TextStyle(
                                        color: AppColors.textSecondary,
                                        fontSize: 13)),
                                GestureDetector(
                                  onTap: () => context.go('/login'),
                                  child: Text('Se connecter',
                                      style: TextStyle(
                                          color: AppColors.accent,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600)),
                                ),
                              ],
                            ),

                            const SizedBox(height: 20),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}