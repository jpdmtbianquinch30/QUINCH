import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/network/api_error.dart';
import '../../core/session/session_controller.dart';
import '../../core/validation/validators.dart';
import '../../shared/widgets/app_widgets.dart';
import '../legal/legal_content.dart';

class RegisterPage extends ConsumerStatefulWidget {
  const RegisterPage({super.key});

  @override
  ConsumerState<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends ConsumerState<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _fullName = TextEditingController();
  final _username = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirmation = TextEditingController();
  final _usernameFocus = FocusNode();
  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();
  final _confirmationFocus = FocusNode();

  bool _acceptedTerms = false;
  bool _loading = false;
  String? _error;
  final Map<String, String> _serverErrors = <String, String>{};

  @override
  void dispose() {
    _fullName.dispose();
    _username.dispose();
    _email.dispose();
    _password.dispose();
    _confirmation.dispose();
    _usernameFocus.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    _confirmationFocus.dispose();
    super.dispose();
  }

  void _clearServerError(String field) {
    if (_serverErrors.containsKey(field)) {
      setState(() => _serverErrors.remove(field));
    }
  }

  Future<void> _submit() async {
    if (_loading) {
      return;
    }
    final form = _formKey.currentState;
    if (form == null || !form.validate()) {
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _loading = true;
      _error = null;
      _serverErrors.clear();
    });
    try {
      await ref
          .read(sessionControllerProvider.notifier)
          .register(
            email: _email.text.trim(),
            fullName: _fullName.text.trim(),
            username: _username.text.trim(),
            password: _password.text,
            passwordConfirmation: _confirmation.text,
          );
      // Succès : la redirection du routeur quitte cet écran.
    } on ApiError catch (e) {
      if (mounted) {
        setState(() {
          for (final entry in e.fieldErrors.entries) {
            if (entry.value.isNotEmpty) {
              _serverErrors[entry.key] = entry.value.first;
            }
          }
          _error = _serverErrors.isEmpty ? e.userMessage : null;
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
      title: 'Créer un compte',
      showBack: true,
      children: [
        Form(
          key: _formKey,
          child: AutofillGroup(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_error != null) ...[
                  ErrorMessage(_error!),
                  const SizedBox(height: 16),
                ],
                AppTextField(
                  controller: _fullName,
                  label: 'Nom complet',
                  keyboardType: TextInputType.name,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.name],
                  validator: Validators.fullName,
                  errorText: _serverErrors['full_name'],
                  onChanged: (_) => _clearServerError('full_name'),
                  onFieldSubmitted: (_) => _usernameFocus.requestFocus(),
                ),
                const SizedBox(height: 16),
                AppTextField(
                  controller: _username,
                  focusNode: _usernameFocus,
                  label: "Nom d'utilisateur",
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.newUsername],
                  validator: Validators.username,
                  errorText: _serverErrors['username'],
                  onChanged: (_) => _clearServerError('username'),
                  onFieldSubmitted: (_) => _emailFocus.requestFocus(),
                ),
                const SizedBox(height: 16),
                AppTextField(
                  controller: _email,
                  focusNode: _emailFocus,
                  label: 'Adresse email',
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.email],
                  validator: Validators.email,
                  errorText: _serverErrors['email'],
                  onChanged: (_) => _clearServerError('email'),
                  onFieldSubmitted: (_) => _passwordFocus.requestFocus(),
                ),
                const SizedBox(height: 16),
                PasswordField(
                  controller: _password,
                  focusNode: _passwordFocus,
                  label: 'Mot de passe',
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.newPassword],
                  validator: Validators.newPassword,
                  errorText: _serverErrors['password'],
                  onChanged: (_) => _clearServerError('password'),
                  onFieldSubmitted: (_) => _confirmationFocus.requestFocus(),
                ),
                const SizedBox(height: 16),
                PasswordField(
                  controller: _confirmation,
                  focusNode: _confirmationFocus,
                  label: 'Confirmer le mot de passe',
                  textInputAction: TextInputAction.done,
                  autofillHints: const [AutofillHints.newPassword],
                  validator: Validators.confirmation(() => _password.text),
                  onFieldSubmitted: (_) => _submit(),
                ),
                const SizedBox(height: 8),
                FormField<bool>(
                  validator: (_) => _acceptedTerms
                      ? null
                      : 'Vous devez accepter les conditions pour continuer.',
                  builder: (field) => Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        controlAffinity: ListTileControlAffinity.leading,
                        value: _acceptedTerms,
                        onChanged: _loading
                            ? null
                            : (value) {
                                setState(() => _acceptedTerms = value ?? false);
                                field.didChange(_acceptedTerms);
                              },
                        title: const Text(
                          "J'accepte les conditions d'utilisation et la politique "
                          'de confidentialité de QUINCH.',
                        ),
                      ),
                      Wrap(
                        spacing: 8,
                        children: [
                          TextButton(
                            onPressed: () =>
                                context.push(LegalDocKey.terms.path),
                            child: const Text(
                              "Lire les conditions d'utilisation",
                            ),
                          ),
                          TextButton(
                            onPressed: () =>
                                context.push(LegalDocKey.privacy.path),
                            child: const Text(
                              'Lire la politique de confidentialité',
                            ),
                          ),
                        ],
                      ),
                      if (field.hasError)
                        Text(
                          field.errorText ?? '',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      if (_serverErrors['accept_terms'] != null)
                        Text(
                          _serverErrors['accept_terms']!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                LoadingButton(
                  label: 'Créer mon compte',
                  isLoading: _loading,
                  onPressed: _submit,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
