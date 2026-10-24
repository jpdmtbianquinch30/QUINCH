import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_error.dart';
import '../../core/validation/validators.dart';
import '../../data/repositories/safety_repository.dart';
import '../../shared/widgets/app_widgets.dart';
import '../profile/profile_providers.dart';

/// Envoi d'un signalement à l'équipe (`POST support/report`).
class SupportPage extends ConsumerStatefulWidget {
  const SupportPage({super.key});

  @override
  ConsumerState<SupportPage> createState() => _SupportPageState();
}

class _SupportPageState extends ConsumerState<SupportPage> {
  final _formKey = GlobalKey<FormState>();
  final _description = TextEditingController();
  SupportCategory _category = SupportCategory.bug;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _description.dispose();
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
    });
    try {
      final message = await ref
          .read(safetyRepositoryProvider)
          .reportProblem(_category, _description.text);
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(content: Text(message ?? 'Signalement reçu. Merci.')),
          );
        Navigator.of(context).pop();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Signaler un problème')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('Votre message est lu par l\'équipe QUINCH.'),
                const SizedBox(height: 16),
                if (_error != null) ...[
                  ErrorMessage(_error!),
                  const SizedBox(height: 16),
                ],
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    for (final category in SupportCategory.values)
                      ChoiceChip(
                        label: Text(category.label),
                        selected: _category == category,
                        onSelected: _loading
                            ? null
                            : (_) => setState(() => _category = category),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _description,
                  minLines: 4,
                  maxLines: 8,
                  maxLength: 2000,
                  validator: Validators.description2000,
                  decoration: const InputDecoration(
                    labelText: 'Décrivez le problème ou votre idée',
                    alignLabelWithHint: true,
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                LoadingButton(
                  label: 'Envoyer',
                  isLoading: _loading,
                  onPressed: _submit,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
