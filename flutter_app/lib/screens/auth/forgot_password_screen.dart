import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:dio/dio.dart';
import '../../config/theme.dart';
import '../../services/auth_service.dart';
import '../../widgets/quinch_logo.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _phoneFormKey = GlobalKey<FormState>();
  final _resetFormKey = GlobalKey<FormState>();

  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();
  final _passwordController = TextEditingController();
  final _passwordConfirmController = TextEditingController();

  bool _otpSent = false;
  bool _loading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _phoneController.dispose();
    _otpController.dispose();
    _passwordController.dispose();
    _passwordConfirmController.dispose();
    super.dispose();
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

  String _extractError(Object e, String fallback) {
    if (e is DioException && e.response?.data is Map) {
      final data = e.response!.data as Map;
      return (data['message'] ?? fallback).toString();
    }
    return fallback;
  }

  Future<void> _requestOtp() async {
    if (!_phoneFormKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final msg = await context.read<AuthService>().forgotPassword(
            phoneNumber: _phoneController.text.trim(),
          );
      if (!mounted) return;
      setState(() { _loading = false; _otpSent = true; });
      _showMsg(msg);
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      _showMsg(_extractError(e, "Erreur lors de l'envoi du code."), error: true);
    }
  }

  Future<void> _resetPassword() async {
    if (!_resetFormKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await context.read<AuthService>().resetPassword(
            phoneNumber: _phoneController.text.trim(),
            otp: _otpController.text.trim(),
            password: _passwordController.text,
            passwordConfirmation: _passwordConfirmController.text,
          );
      if (!mounted) return;
      _showMsg('Mot de passe réinitialisé ! Connectez-vous avec le nouveau.');
      context.go('/auth/login');
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      _showMsg(_extractError(e, 'Code invalide ou expiré.'), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: AppBar(
        backgroundColor: AppColors.bgPrimary,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () {
            if (_otpSent) {
              setState(() => _otpSent = false);
            } else {
              context.pop();
            }
          },
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              const QuinchLogo(size: 48, withShadow: false),
              const SizedBox(height: 24),
              Text(
                _otpSent ? 'Nouveau mot de passe' : 'Mot de passe oublié',
                style: TextStyle(color: AppColors.textPrimary, fontSize: 24, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Text(
                _otpSent
                    ? 'Entrez le code reçu par SMS au ${_phoneController.text.trim()} et choisissez un nouveau mot de passe.'
                    : 'Entrez votre numéro de téléphone : un code de vérification vous sera envoyé par SMS.',
                style: TextStyle(color: AppColors.textMuted, fontSize: 13),
              ),
              const SizedBox(height: 28),

              if (!_otpSent) ..._buildPhoneStep() else ..._buildResetStep(),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildPhoneStep() {
    return [
      Form(
        key: _phoneFormKey,
        child: TextFormField(
          controller: _phoneController,
          keyboardType: TextInputType.phone,
          style: TextStyle(color: AppColors.textPrimary),
          decoration: InputDecoration(
            labelText: 'Numéro de téléphone',
            labelStyle: TextStyle(color: AppColors.textMuted, fontSize: 13),
            hintText: '+221 7X XXX XX XX',
            prefixIcon: Icon(Icons.phone_outlined, color: AppColors.textMuted, size: 20),
          ),
          validator: (v) => v == null || v.trim().isEmpty ? 'Numéro requis' : null,
        ),
      ),
      const SizedBox(height: 24),
      _buildPrimaryButton(
        label: 'Envoyer le code',
        onPressed: _loading ? null : _requestOtp,
      ),
    ];
  }

  List<Widget> _buildResetStep() {
    return [
      Form(
        key: _resetFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextFormField(
              controller: _otpController,
              keyboardType: TextInputType.number,
              maxLength: 6,
              style: TextStyle(color: AppColors.textPrimary, letterSpacing: 6, fontSize: 18),
              decoration: InputDecoration(
                labelText: 'Code reçu par SMS',
                labelStyle: TextStyle(color: AppColors.textMuted, fontSize: 13),
                counterText: '',
                prefixIcon: Icon(Icons.sms_outlined, color: AppColors.textMuted, size: 20),
              ),
              validator: (v) => v == null || v.trim().length != 6 ? 'Code à 6 chiffres requis' : null,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _passwordController,
              obscureText: _obscurePassword,
              style: TextStyle(color: AppColors.textPrimary),
              decoration: InputDecoration(
                labelText: 'Nouveau mot de passe',
                labelStyle: TextStyle(color: AppColors.textMuted, fontSize: 13),
                prefixIcon: Icon(Icons.lock_outline, color: AppColors.textMuted, size: 20),
                suffixIcon: IconButton(
                  icon: Icon(_obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                      color: AppColors.textMuted, size: 20),
                  onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                ),
              ),
              validator: (v) {
                if (v == null || v.length < 8) return '8 caractères minimum';
                if (!RegExp(r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d).+$').hasMatch(v)) {
                  return '1 majuscule, 1 minuscule, 1 chiffre requis';
                }
                return null;
              },
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _passwordConfirmController,
              obscureText: _obscurePassword,
              style: TextStyle(color: AppColors.textPrimary),
              decoration: InputDecoration(
                labelText: 'Confirmer le mot de passe',
                labelStyle: TextStyle(color: AppColors.textMuted, fontSize: 13),
                prefixIcon: Icon(Icons.lock_outline, color: AppColors.textMuted, size: 20),
              ),
              validator: (v) => v != _passwordController.text ? 'Les mots de passe ne correspondent pas' : null,
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: _loading ? null : _requestOtp,
                child: Text('Renvoyer le code', style: TextStyle(color: AppColors.accent, fontSize: 12)),
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 16),
      _buildPrimaryButton(
        label: 'Réinitialiser le mot de passe',
        onPressed: _loading ? null : _resetPassword,
      ),
    ];
  }

  Widget _buildPrimaryButton({required String label, required VoidCallback? onPressed}) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: AppColors.primaryGradient,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: AppColors.accent.withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 4))],
        ),
        child: ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: _loading
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : Text(label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white)),
        ),
      ),
    );
  }
}
