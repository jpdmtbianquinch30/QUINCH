import 'package:flutter/material.dart';

import '../../core/network/api_error.dart';

/// Feuille de signalement : choix du motif + description facultative.
/// `onSubmit` reçoit l'indice du motif et la description, et renvoie le message
/// du serveur. Les erreurs (dont « déjà signalé », 409) s'affichent dans la feuille.
Future<void> showReportSheet(
  BuildContext context, {
  required String title,
  required List<String> reasons,
  required Future<String?> Function(int reasonIndex, String description)
  onSubmit,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  final message = await showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheetContext) =>
        _ReportSheet(title: title, reasons: reasons, onSubmit: onSubmit),
  );
  if (message != null) {
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

class _ReportSheet extends StatefulWidget {
  const _ReportSheet({
    required this.title,
    required this.reasons,
    required this.onSubmit,
  });

  final String title;
  final List<String> reasons;
  final Future<String?> Function(int reasonIndex, String description) onSubmit;

  @override
  State<_ReportSheet> createState() => _ReportSheetState();
}

class _ReportSheetState extends State<_ReportSheet> {
  final _description = TextEditingController();
  int? _selected;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _description.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final selected = _selected;
    if (selected == null) {
      setState(() => _error = 'Choisissez un motif.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final message = await widget.onSubmit(selected, _description.text);
      if (mounted) {
        Navigator.of(context).pop(message ?? 'Signalement envoyé.');
      }
    } on ApiError catch (e) {
      if (mounted) {
        setState(() {
          _error = e.userMessage;
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        0,
        16,
        16 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(widget.title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (var i = 0; i < widget.reasons.length; i++)
                  ChoiceChip(
                    label: Text(widget.reasons[i]),
                    selected: _selected == i,
                    onSelected: _loading
                        ? null
                        : (_) => setState(() => _selected = i),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _description,
              enabled: !_loading,
              maxLength: 2000,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Précisions (facultatif)',
                border: OutlineInputBorder(),
              ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            FilledButton(
              onPressed: _loading ? null : _submit,
              child: _loading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        semanticsLabel: 'Envoi en cours',
                      ),
                    )
                  : const Text('Envoyer le signalement'),
            ),
          ],
        ),
      ),
    );
  }
}
