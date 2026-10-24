import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router.dart';
import '../../core/network/api_error.dart';
import '../../core/providers.dart';
import '../../core/session/session_controller.dart';
import '../../core/session/session_state.dart';
import '../../core/validation/validators.dart';
import '../../shared/widgets/app_widgets.dart';

/// Paramètres du compte : mot de passe et suppression du compte.
/// (Les préférences de notification arrivent avec les notifications.)
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Paramètres')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.notifications_outlined),
            title: const Text('Préférences de notification'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push(notificationPreferencesPath),
          ),
          const Divider(height: 32),
          const _ChangePasswordCard(),
          const SizedBox(height: 24),
          const _DeleteAccountCard(),
        ],
      ),
    );
  }
}

class _ChangePasswordCard extends ConsumerStatefulWidget {
  const _ChangePasswordCard();

  @override
  ConsumerState<_ChangePasswordCard> createState() =>
      _ChangePasswordCardState();
}

class _ChangePasswordCardState extends ConsumerState<_ChangePasswordCard> {
  final _formKey = GlobalKey<FormState>();
  final _current = TextEditingController();
  final _new = TextEditingController();
  final _confirmation = TextEditingController();
  bool _loading = false;
  String? _error;
  String? _newError;

  @override
  void dispose() {
    _current.dispose();
    _new.dispose();
    _confirmation.dispose();
    super.dispose();
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
      _newError = null;
    });
    try {
      final message = await ref
          .read(authRepositoryProvider)
          .changePassword(
            currentPassword: _current.text,
            newPassword: _new.text,
            confirmation: _confirmation.text,
          );
      if (mounted) {
        _current.clear();
        _new.clear();
        _confirmation.clear();
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(content: Text(message ?? 'Mot de passe modifié.')),
          );
      }
    } on ApiError catch (e) {
      if (mounted) {
        setState(() {
          _newError = e.firstFieldError('new_password');
          _error = _newError == null ? e.userMessage : null;
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
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Mot de passe', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          const Text('Vos autres appareils seront déconnectés.'),
          const SizedBox(height: 12),
          if (_error != null) ...[
            ErrorMessage(_error!),
            const SizedBox(height: 12),
          ],
          PasswordField(
            controller: _current,
            label: 'Mot de passe actuel',
            textInputAction: TextInputAction.next,
            validator: Validators.passwordPresent,
          ),
          const SizedBox(height: 12),
          PasswordField(
            controller: _new,
            label: 'Nouveau mot de passe',
            textInputAction: TextInputAction.next,
            validator: Validators.newPassword,
            errorText: _newError,
            onChanged: (_) {
              if (_newError != null) {
                setState(() => _newError = null);
              }
            },
          ),
          const SizedBox(height: 12),
          PasswordField(
            controller: _confirmation,
            label: 'Confirmer le nouveau mot de passe',
            textInputAction: TextInputAction.done,
            validator: Validators.confirmation(() => _new.text),
            onFieldSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: 12),
          LoadingButton(
            label: 'Changer le mot de passe',
            isLoading: _loading,
            onPressed: _submit,
          ),
        ],
      ),
    );
  }
}

class _DeleteAccountCard extends ConsumerWidget {
  const _DeleteAccountCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Supprimer mon compte',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 4),
        const Text(
          'Vos données personnelles sont effacées. Cette action est définitive.',
        ),
        const SizedBox(height: 12),
        OutlinedButton(
          style: OutlinedButton.styleFrom(foregroundColor: scheme.error),
          onPressed: () async {
            final deleted = await showDialog<bool>(
              context: context,
              builder: (dialogContext) => const _DeleteAccountDialog(),
            );
            if (deleted == true) {
              await ref
                  .read(sessionControllerProvider.notifier)
                  .closeLocally(SessionEndReason.accountDeleted);
            }
          },
          child: const Text('Supprimer mon compte'),
        ),
      ],
    );
  }
}

class _DeleteAccountDialog extends ConsumerStatefulWidget {
  const _DeleteAccountDialog();

  @override
  ConsumerState<_DeleteAccountDialog> createState() =>
      _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends ConsumerState<_DeleteAccountDialog> {
  final _password = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  Future<void> _delete() async {
    if (_password.text.isEmpty) {
      setState(() => _error = 'Saisissez votre mot de passe.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ref.read(authRepositoryProvider).deleteAccount(_password.text);
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } on ApiError catch (e) {
      if (mounted) {
        setState(() {
          _error = e.firstFieldError('password') ?? e.userMessage;
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Supprimer votre compte ?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Saisissez votre mot de passe pour confirmer.'),
          const SizedBox(height: 12),
          PasswordField(
            controller: _password,
            label: 'Mot de passe',
            textInputAction: TextInputAction.done,
            errorText: _error,
            onFieldSubmitted: (_) => _delete(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _loading ? null : () => Navigator.of(context).pop(false),
          child: const Text('Annuler'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
          onPressed: _loading ? null : _delete,
          child: const Text('Supprimer définitivement'),
        ),
      ],
    );
  }
}
