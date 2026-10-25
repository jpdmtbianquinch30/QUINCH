import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/network/api_error.dart';
import '../../data/models/new_product.dart';
import '../../data/models/product.dart';
import '../../shared/widgets/app_widgets.dart';
import '../product/product_providers.dart';
import 'profile_providers.dart';

/// Modifier une de mes annonces.
///
/// Le serveur n'accepte que : titre, description, prix, stock, état, négociable
/// et statut. Les photos, la vidéo et la catégorie ne se modifient pas. Seuls les
/// champs réellement changés sont envoyés.
class EditProductPage extends ConsumerStatefulWidget {
  const EditProductPage({super.key, required this.card});

  final ProductCard card;

  @override
  ConsumerState<EditProductPage> createState() => _EditProductPageState();
}

class _EditProductPageState extends ConsumerState<EditProductPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _title;
  late final TextEditingController _price;
  late final TextEditingController _description;
  late final TextEditingController _stock;
  ProductCondition? _condition;
  late bool _negotiable;

  bool _saving = false;
  String? _error;
  final Map<String, String> _serverErrors = <String, String>{};

  ProductCard get _card => widget.card;
  bool get _isProduct => _card.type == 'product';

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: _card.title);
    _price = TextEditingController(text: _card.price.round().toString());
    _description = TextEditingController(text: _card.description);
    _stock = TextEditingController(text: _card.stockQuantity?.toString() ?? '');
    _negotiable = _card.isNegotiable;
    for (final condition in ProductCondition.values) {
      if (condition.value == _card.condition) {
        _condition = condition;
      }
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _price.dispose();
    _description.dispose();
    _stock.dispose();
    super.dispose();
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void _clearError(String field) {
    if (_serverErrors.containsKey(field)) {
      setState(() => _serverErrors.remove(field));
    }
  }

  String? _validateTitle(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) {
      return 'Saisissez le titre de votre annonce.';
    }
    if (text.length > 200) {
      return '200 caractères maximum.';
    }
    return null;
  }

  String? _validatePrice(String? value) {
    final price = int.tryParse(value?.trim() ?? '');
    if (price == null || price < 0) {
      return 'Indiquez un prix en FCFA (nombre entier).';
    }
    return null;
  }

  String? _validateStock(String? value) {
    if (!_isProduct || (value ?? '').trim().isEmpty) {
      return null;
    }
    final stock = int.tryParse(value!.trim());
    if (stock == null || stock < 0) {
      return 'Indiquez un nombre entier (0 ou plus).';
    }
    return null;
  }

  String? _validateDescription(String? value) {
    final text = value?.trim() ?? '';
    if (text.length > 5000) {
      return '5000 caractères maximum.';
    }
    // Le serveur refuse une description vide : on ne peut pas l'effacer.
    if (text.isEmpty && _card.description.trim().isNotEmpty) {
      return 'La description ne peut pas être vide.';
    }
    return null;
  }

  /// Champs réellement modifiés par rapport à l'annonce d'origine.
  ProductUpdate _changes() {
    final title = _title.text.trim();
    final description = _description.text.trim();
    final price = int.parse(_price.text.trim());
    final stockText = _stock.text.trim();
    final stock = stockText.isEmpty ? null : int.parse(stockText);
    return ProductUpdate(
      title: title != _card.title ? title : null,
      description: description.isNotEmpty && description != _card.description
          ? description
          : null,
      price: price != _card.price.round() ? price : null,
      stockQuantity: _isProduct && stock != null && stock != _card.stockQuantity
          ? stock
          : null,
      condition:
          _isProduct &&
              _condition != null &&
              _condition!.value != _card.condition
          ? _condition
          : null,
      isNegotiable: _negotiable != _card.isNegotiable ? _negotiable : null,
    );
  }

  Future<void> _submit() async {
    if (_saving || !(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    final update = _changes();
    if (update.isEmpty) {
      _toast('Aucune modification à enregistrer.');
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _saving = true;
      _error = null;
      _serverErrors.clear();
    });
    try {
      final result = await ref
          .read(productRepositoryProvider)
          .updateProduct(_card.id, update);
      await ref.read(myProductsProvider.notifier).refresh();
      if (!mounted) {
        return;
      }
      _toast(result.message ?? 'Annonce mise à jour.');
      context.pop();
    } on ApiError catch (e) {
      if (mounted) {
        setState(() {
          for (final entry in e.fieldErrors.entries) {
            if (entry.value.isNotEmpty) {
              _serverErrors[entry.key] = entry.value.first;
            }
          }
          _error = e.userMessage;
        });
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text("Modifier l'annonce")),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_error != null) ...[
            ErrorMessage(_error!),
            const SizedBox(height: 16),
          ],
          Text(
            'Les photos, la vidéo et la catégorie ne peuvent pas être '
            "modifiées après la création de l'annonce.",
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 16),
          Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppTextField(
                  controller: _title,
                  label: 'Titre',
                  maxLength: 200,
                  textInputAction: TextInputAction.next,
                  validator: _validateTitle,
                  errorText: _serverErrors['title'],
                  onChanged: (_) => _clearError('title'),
                ),
                const SizedBox(height: 16),
                AppTextField(
                  controller: _price,
                  label: 'Prix (FCFA)',
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.next,
                  validator: _validatePrice,
                  errorText: _serverErrors['price'],
                  onChanged: (_) => _clearError('price'),
                ),
                if (_isProduct) ...[
                  const SizedBox(height: 16),
                  AppTextField(
                    controller: _stock,
                    label: 'Quantité en stock',
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.next,
                    validator: _validateStock,
                    errorText: _serverErrors['stock_quantity'],
                    onChanged: (_) => _clearError('stock_quantity'),
                  ),
                ],
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Prix négociable'),
                  value: _negotiable,
                  onChanged: (value) => setState(() => _negotiable = value),
                ),
                if (_isProduct) ...[
                  const SizedBox(height: 8),
                  InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'État',
                      border: OutlineInputBorder(),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<ProductCondition>(
                        value: _condition,
                        isExpanded: true,
                        hint: const Text('Non précisé'),
                        items: [
                          for (final condition in ProductCondition.values)
                            DropdownMenuItem<ProductCondition>(
                              value: condition,
                              child: Text(condition.label),
                            ),
                        ],
                        onChanged: (value) =>
                            setState(() => _condition = value),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                TextFormField(
                  controller: _description,
                  minLines: 4,
                  maxLines: 8,
                  maxLength: 5000,
                  keyboardType: TextInputType.multiline,
                  validator: _validateDescription,
                  decoration: InputDecoration(
                    labelText: 'Description',
                    alignLabelWithHint: true,
                    border: const OutlineInputBorder(),
                    errorText: _serverErrors['description'],
                  ),
                  onChanged: (_) => _clearError('description'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          LoadingButton(
            label: 'Enregistrer',
            isLoading: _saving,
            onPressed: _submit,
          ),
        ],
      ),
    );
  }
}

/// Affichée si l'écran de modification est ouvert sans annonce (ex. après un
/// redémarrage de l'application) : il suffit de revenir à la liste.
class MissingProductPage extends StatelessWidget {
  const MissingProductPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Modifier l'annonce")),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            "Cette annonce n'est plus disponible. Revenez à « Mes annonces ».",
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
