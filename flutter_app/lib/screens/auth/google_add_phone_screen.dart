import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../config/theme.dart';

class GoogleAddPhoneScreen extends StatefulWidget {
  const GoogleAddPhoneScreen({super.key});

  @override
  State<GoogleAddPhoneScreen> createState() => _GoogleAddPhoneScreenState();
}

class _GoogleAddPhoneScreenState extends State<GoogleAddPhoneScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _loading = true; _error = null; });

    try {
      final auth = context.read<AuthProvider>();
      await auth.addGooglePhone(
        phoneNumber: '+221${_phoneController.text.trim()}',
      );
      if (mounted) context.go('/home');
    } catch (e) {
      setState(() { _error = e.toString(); });
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
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.phone_android, size: 60, color: AppColors.accent),
              const SizedBox(height: 16),
              Text('Ajouter votre numéro',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary),
                textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Text('Un numéro Sénégal est requis pour utiliser QUINCH.\nVous pourrez le modifier plus tard.',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.5),
                textAlign: TextAlign.center),
              const SizedBox(height: 32),

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

              Form(
                key: _formKey,
                child: TextFormField(
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
                        child: Text('+221',
                          style: TextStyle(color: AppColors.textSecondary,
                              fontWeight: FontWeight.w600, fontSize: 14)),
                      ),
                    ),
                    prefixIconConstraints: const BoxConstraints(),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Numéro requis';
                    if (!RegExp(r'^[0-9]{9}$').hasMatch(v.trim())) {
                      return 'Format invalide (9 chiffres après +221)';
                    }
                    return null;
                  },
                ),
              ),

              const SizedBox(height: 24),

              SizedBox(
                height: 52,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: ElevatedButton(
                    onPressed: _loading ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: _loading
                      ? const SizedBox(width: 20, height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Confirmer',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white)),
                  ),
                ),
              ),

              const SizedBox(height: 12),

              TextButton(
                onPressed: () => context.go('/home'),
                child: Text('Passer pour l\'instant',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}