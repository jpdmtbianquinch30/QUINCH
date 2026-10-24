import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router.dart';
import '../../core/network/api_error.dart';
import '../../core/providers.dart';
import '../../core/validation/validators.dart';
import '../../shared/widgets/app_widgets.dart';

enum _Step { request, reset }

/// Récupération du mot de passe par email, en deux temps :
/// 1) `auth/forgot-password` (le serveur répond pareil que le compte existe ou non) ;
/// 2) `auth/reset-password` avec le code reçu par email.
class ForgotPasswordPage extends ConsumerStatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  ConsumerState<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends ConsumerState<ForgotPasswordPage> {
  final _requestKey = GlobalKey<FormState>();
  final _resetKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _otp = TextEditingController();
  final _password = TextEditingController();
  final _confirmation = TextEditingController();

  _Step _step = _Step.request;
  bool _loading = false;
  String? _error;
  String? _info;
  String? _passwordError;

  @override
  void dispose() {
    _email.dispose();
    _otp.dispose();
    _password.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  Future<void> _requestCode() async {
    if (_loading) {
      return;
    }
    final form = _requestKey.currentState;
    if (form == null || !form.validate()) {
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final message = await ref
          .read(authRepositoryProvider)
          .requestPasswordReset(_email.text.trim());
      if (mounted) {
        setState(() {
          _step = _Step.reset;
          _info =
              message ??
              'Si un compte existe pour cette adresse, un code vient de lui être envoyé.';
        });
      }
    } on ApiError catch (e) {
      if (mounted) {
        setState(() => _error = e.userMessage);
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _resetPassword() async {
    if (_loading) {
      return;
    }
    final form = _resetKey.currentState;
    if (form == null || !form.validate()) {
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _loading = true;
      _error = null;
      _passwordError = null;
    });
    try {
      final message = await ref
          .read(authRepositoryProvider)
          .resetPassword(
            email: _email.text.trim(),
            otp: _otp.text.trim(),
            password: _password.text,
            passwordConfirmation: _confirmation.text,
          );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            message ?? 'Mot de passe modifié. Vous pouvez vous connecter.',
          ),
        ),
      );
      context.go(loginPath);
    } on ApiError catch (e) {
      if (mounted) {
        setState(() {
          _passwordError = e.firstFieldError('password');
          _error = _passwordError == null ? e.userMessage : null;
        });
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: 'Mot de passe oublié',
      showBack: true,
      children: [
        if (_error != null) ...[
          ErrorMessage(_error!),
          const SizedBox(height: 16),
        ],
        if (_step == _Step.request) _buildRequest() else _buildReset(),
      ],
    );
  }

  Widget _buildRequest() {
    return Form(
      key: _requestKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Saisissez votre adresse email : nous vous enverrons un code pour choisir un nouveau mot de passe.',
          ),
          const SizedBox(height: 16),
          AppTextField(
            controller: _email,
            label: 'Adresse email',
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.email],
            validator: Validators.email,
            onFieldSubmitted: (_) => _requestCode(),
          ),
          const SizedBox(height: 16),
          LoadingButton(
            label: 'Envoyer le code',
            isLoading: _loading,
            onPressed: _requestCode,
          ),
        ],
      ),
    );
  }

  Widget _buildReset() {
    return Form(
      key: _resetKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_info != null) ...[Text(_info!), const SizedBox(height: 16)],
          AppTextField(
            controller: _otp,
            label: 'Code reçu par email',
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.next,
            maxLength: 6,
            validator: Validators.otp,
          ),
          const SizedBox(height: 16),
          PasswordField(
            controller: _password,
            label: 'Nouveau mot de passe',
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.newPassword],
            validator: Validators.newPassword,
            errorText: _passwordError,
            onChanged: (_) {
              if (_passwordError != null) {
                setState(() => _passwordError = null);
              }
            },
          ),
          const SizedBox(height: 16),
          PasswordField(
            controller: _confirmation,
            label: 'Confirmer le mot de passe',
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.newPassword],
            validator: Validators.confirmation(() => _password.text),
            onFieldSubmitted: (_) => _resetPassword(),
          ),
          const SizedBox(height: 16),
          LoadingButton(
            label: 'Changer le mot de passe',
            isLoading: _loading,
            onPressed: _resetPassword,
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: _loading ? null : _requestCode,
            child: const Text('Renvoyer un code'),
          ),
          TextButton(
            onPressed: _loading
                ? null
                : () => setState(() {
                    _step = _Step.request;
                    _error = null;
                  }),
            child: const Text("Changer d'adresse email"),
          ),
        ],
      ),
    );
  }
}
