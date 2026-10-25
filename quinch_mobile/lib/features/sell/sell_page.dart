import 'dart:io';

import 'package:dio/dio.dart' show CancelToken;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router.dart';
import '../../core/format/fcfa.dart';
import '../../core/media/picked_image.dart';
import '../../core/media/picked_video.dart';
import '../../core/network/api_error.dart';
import '../../core/platform/image_picker.dart';
import '../../core/session/session_controller.dart';
import '../../core/session/session_state.dart';
import '../../data/models/new_product.dart';
import '../../data/models/product.dart';
import '../../shared/widgets/app_widgets.dart';
import '../product/product_providers.dart';
import 'listing_fee.dart';
import 'sell_providers.dart';

/// Publier une annonce « produit » avec photos (brouillon ou publication).
///
/// Reprend le formulaire du web : catégorie principale, titre, prix en FCFA,
/// état, négociable, description, couverture obligatoire et photos en plus.
/// Une vidéo (500 Mo maximum) peut être jointe : elle est envoyée tout de suite,
/// avec progression et annulation, puis rattachée à l'annonce par son
/// identifiant. Le serveur reste l'autorité sur les statuts, les limites et les
/// frais de publication ; les services arrivent dans un lot suivant.
class SellPage extends ConsumerStatefulWidget {
  const SellPage({super.key});

  @override
  ConsumerState<SellPage> createState() => _SellPageState();
}

class _SellPageState extends ConsumerState<SellPage> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _price = TextEditingController();
  final _description = TextEditingController();

  PickedImage? _poster;
  final List<PickedImage> _images = <PickedImage>[];
  String? _categoryId;
  ProductCondition _condition = ProductCondition.brandNew;
  bool _negotiable = true;

  bool _saving = false;
  double? _progress;
  String? _error;
  String? _coverError;
  String? _categoryError;
  final Map<String, String> _serverErrors = <String, String>{};

  PickedVideo? _video;
  String? _videoId;
  bool _videoUploading = false;
  double? _videoProgress;
  CancelToken? _cancelToken;
  String? _videoError;

  @override
  void dispose() {
    _cancelToken?.cancel('Écran fermé');
    _title.dispose();
    _price.dispose();
    _description.dispose();
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

  Future<void> _pickCover() async {
    PickedImage? picked;
    try {
      picked = await ref.read(imagePickProvider)();
    } on Exception {
      if (mounted) {
        _toast("Impossible d'ouvrir la galerie.");
      }
      return;
    }
    if (picked == null || !mounted) {
      return;
    }
    final problem = validateListingImage(picked);
    if (problem != null) {
      _toast(problem);
      return;
    }
    setState(() {
      _poster = picked;
      _coverError = null;
    });
  }

  Future<void> _addImages() async {
    List<PickedImage> picked;
    try {
      picked = await ref.read(imagesPickProvider)();
    } on Exception {
      if (mounted) {
        _toast("Impossible d'ouvrir la galerie.");
      }
      return;
    }
    if (picked.isEmpty || !mounted) {
      return;
    }
    String? problem;
    var capped = false;
    final accepted = <PickedImage>[];
    for (final image in picked) {
      final issue = validateListingImage(image);
      if (issue != null) {
        problem ??= issue;
        continue;
      }
      final known =
          _images.any((i) => i.path == image.path) ||
          accepted.any((i) => i.path == image.path);
      if (known) {
        continue;
      }
      if (_images.length + accepted.length >= listingExtraImagesHardMax) {
        capped = true;
        break;
      }
      accepted.add(image);
    }
    setState(() => _images.addAll(accepted));
    if (problem != null) {
      _toast(problem);
    } else if (capped) {
      _toast('$listingExtraImagesHardMax photos supplémentaires maximum.');
    }
  }

  Future<void> _pickVideo() async {
    if (_videoUploading || _saving) {
      return;
    }
    PickedVideo? picked;
    try {
      picked = await ref.read(videoPickProvider)();
    } on Exception {
      if (mounted) {
        _toast("Impossible d'ouvrir la galerie.");
      }
      return;
    }
    if (picked == null || !mounted) {
      return;
    }
    final problem = validateListingVideo(picked);
    if (problem != null) {
      _toast(problem);
      return;
    }
    final chosen = picked;
    if (videoNeedsSizeWarning(chosen)) {
      final proceed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Vidéo volumineuse'),
          content: Text(
            'Cette vidéo pèse ${formatMegabytes(chosen.sizeBytes)}. '
            "L'envoi peut être long et consommer beaucoup de données "
            'mobiles. Utilisez de préférence le Wi-Fi.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Envoyer quand même'),
            ),
          ],
        ),
      );
      if (proceed != true || !mounted) {
        return;
      }
    }
    await _uploadVideo(chosen);
  }

  Future<void> _uploadVideo(PickedVideo video) async {
    final token = CancelToken();
    setState(() {
      _video = video;
      _videoId = null;
      _videoUploading = true;
      _videoProgress = 0;
      _videoError = null;
      _cancelToken = token;
    });
    try {
      final uploaded = await ref
          .read(productRepositoryProvider)
          .uploadVideo(
            video,
            cancelToken: token,
            onProgress: (value) {
              if (mounted) {
                setState(() => _videoProgress = value);
              }
            },
          );
      if (!mounted) {
        return;
      }
      setState(() {
        _videoId = uploaded.id;
        _coverError = null;
      });
      if (uploaded.alreadyOnServer) {
        _toast('Cette vidéo était déjà sur QUINCH : elle est reprise.');
      }
    } on ApiError catch (e) {
      if (mounted) {
        setState(() {
          _video = null;
          // Annulation voulue par l'utilisateur : pas de message d'erreur.
          _videoError = token.isCancelled ? null : e.userMessage;
        });
      }
    } on Exception {
      // Fichier disparu ou illisible avant l'envoi.
      if (mounted) {
        setState(() {
          _video = null;
          _videoError =
              'Impossible de lire cette vidéo. Choisissez-la à nouveau.';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _videoUploading = false;
          _videoProgress = null;
          _cancelToken = null;
        });
      }
    }
  }

  void _cancelVideoUpload() => _cancelToken?.cancel('Envoi annulé');

  void _removeVideo() => setState(() {
    _video = null;
    _videoId = null;
  });

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
    if (price == null || price <= 0) {
      return 'Indiquez un prix en FCFA (nombre entier supérieur à 0).';
    }
    return null;
  }

  String? _validateDescription(String? value) {
    if ((value ?? '').length > 5000) {
      return '5000 caractères maximum.';
    }
    return null;
  }

  Future<void> _submit(PublishIntent intent) async {
    if (_saving) {
      return;
    }
    if (_videoUploading) {
      _toast("Patientez : la vidéo est en cours d'envoi.");
      return;
    }
    final formOk = _formKey.currentState?.validate() ?? false;
    final categoryId = _categoryId;
    final poster = _poster;
    final hasMedia = poster != null || _images.isNotEmpty || _videoId != null;
    setState(() {
      _categoryError = categoryId == null ? 'Choisissez une catégorie.' : null;
      _coverError = hasMedia
          ? null
          : 'Ajoutez au moins une photo ou une vidéo.';
    });
    if (!formOk || categoryId == null || !hasMedia) {
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() {
      _saving = true;
      _progress = 0;
      _error = null;
      _serverErrors.clear();
    });
    try {
      final result = await ref
          .read(productRepositoryProvider)
          .createProduct(
            NewProduct(
              title: _title.text.trim(),
              categoryId: categoryId,
              price: int.parse(_price.text.trim()),
              poster: poster,
              videoId: _videoId,
              description: _description.text.trim(),
              condition: _condition,
              isNegotiable: _negotiable,
              images: List<PickedImage>.unmodifiable(_images),
            ),
            intent,
            onProgress: (value) {
              if (mounted) {
                setState(() => _progress = value);
              }
            },
          );
      if (!mounted) {
        return;
      }
      if (result.paymentUrl != null) {
        // L'annonce est créée (en brouillon) : le formulaire n'est plus occupé
        // pendant que l'utilisateur lit la demande de paiement.
        setState(() {
          _saving = false;
          _progress = null;
        });
        await _handleListingFee(result);
        return;
      }
      _toast(
        result.message ??
            (intent == PublishIntent.draft
                ? 'Brouillon enregistré.'
                : 'Annonce publiée.'),
      );
      context.pushReplacement(myProductsPath);
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
    } on Exception {
      // Fichier disparu ou illisible avant l'envoi.
      if (mounted) {
        setState(
          () => _error =
              'Impossible de lire un fichier choisi. Choisissez-le à nouveau.',
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
          _progress = null;
        });
      }
    }
  }

  /// Le serveur a gardé l'annonce en brouillon et demande des frais : on propose
  /// d'ouvrir la page de paiement, sans jamais considérer le paiement comme fait.
  Future<void> _handleListingFee(ProductSaveResult result) async {
    final message = await runListingFeeFlow(context, ref, result);
    if (!mounted || message == null) {
      return;
    }
    _toast(message);
    context.pushReplacement(myProductsPath);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final categories = ref.watch(categoriesProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Publier une annonce')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_error != null) ...[
            ErrorMessage(_error!),
            const SizedBox(height: 16),
          ],
          Text('Photos', style: theme.textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            'JPEG, PNG ou WebP, 5 Mo maximum par photo. Le nombre de photos '
            'supplémentaires dépend de votre compte.',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          _buildCover(theme),
          const SizedBox(height: 16),
          _buildExtraImages(theme),
          const Divider(height: 40),
          _buildVideo(theme),
          const Divider(height: 40),
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
                _buildCategory(categories),
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
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Prix négociable'),
                  value: _negotiable,
                  onChanged: (value) => setState(() => _negotiable = value),
                ),
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
                      items: [
                        for (final condition in ProductCondition.values)
                          DropdownMenuItem<ProductCondition>(
                            value: condition,
                            child: Text(condition.label),
                          ),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => _condition = value);
                        }
                      },
                    ),
                  ),
                ),
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
          if (_saving) ...[
            LinearProgressIndicator(
              value: _progress,
              semanticsLabel: "Envoi de l'annonce",
            ),
            const SizedBox(height: 12),
          ],
          LoadingButton(
            label: 'Publier',
            isLoading: _saving,
            onPressed: () => _submit(PublishIntent.publish),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
            ),
            onPressed: _saving ? null : () => _submit(PublishIntent.draft),
            child: const Text('Enregistrer en brouillon'),
          ),
        ],
      ),
    );
  }

  Widget _buildVideo(ThemeData theme) {
    final config = ref.watch(publicConfigProvider).valueOrNull;
    final session = ref.watch(sessionControllerProvider);
    final isPremium = session is SessionAuthenticated && session.user.isPremium;
    final fee = (config == null || config.beta)
        ? 0
        : config.listingFeeWithVideo;
    final video = _video;
    final percent = ((_videoProgress ?? 0) * 100).round();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Vidéo', style: theme.textTheme.titleMedium),
        const SizedBox(height: 4),
        Text(
          'MP4, MOV, AVI ou WebM, 500 Mo maximum. Les annonces avec vidéo '
          'sont mises en avant.',
          style: theme.textTheme.bodySmall,
        ),
        if (fee > 0 && !isPremium) ...[
          const SizedBox(height: 4),
          Text(
            'Publier avec une vidéo coûte ${formatFcfa(fee)} '
            '(gratuit avec Premium). Vous pouvez enregistrer en brouillon sans '
            'payer.',
            style: theme.textTheme.bodySmall,
          ),
        ],
        const SizedBox(height: 12),
        if (_videoUploading) ...[
          LinearProgressIndicator(
            value: _videoProgress,
            semanticsLabel: 'Envoi de la vidéo',
          ),
          Row(
            children: [
              Expanded(child: Text('Envoi de la vidéo… $percent %')),
              TextButton(
                onPressed: _cancelVideoUpload,
                child: const Text("Annuler l'envoi"),
              ),
            ],
          ),
        ] else if (video != null && _videoId != null)
          Row(
            children: [
              const Icon(Icons.videocam_outlined),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '${video.name} · ${formatMegabytes(video.sizeBytes)}\n'
                  'Vidéo envoyée',
                ),
              ),
              IconButton(
                tooltip: 'Retirer la vidéo',
                onPressed: _saving ? null : _removeVideo,
                icon: const Icon(Icons.close),
              ),
            ],
          )
        else
          OutlinedButton.icon(
            onPressed: _saving ? null : _pickVideo,
            icon: const Icon(Icons.video_library_outlined),
            label: const Text('Choisir une vidéo'),
          ),
        if (_videoError != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              _videoError!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildCover(ThemeData theme) {
    final poster = _poster;
    final error = _coverError ?? _serverErrors['poster_file'];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _Thumb(image: poster, size: 96),
            const SizedBox(width: 16),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _saving ? null : _pickCover,
                icon: const Icon(Icons.photo_outlined),
                label: Text(
                  poster == null
                      ? 'Choisir la couverture'
                      : 'Changer la couverture',
                ),
              ),
            ),
          ],
        ),
        if (error != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              error,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildExtraImages(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_images.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final image in _images)
                  _Thumb(
                    image: image,
                    size: 72,
                    onRemove: _saving
                        ? null
                        : () => setState(() => _images.remove(image)),
                  ),
              ],
            ),
          ),
        OutlinedButton.icon(
          onPressed: _saving ? null : _addImages,
          icon: const Icon(Icons.add_photo_alternate_outlined),
          label: Text(
            _images.isEmpty
                ? 'Ajouter des photos'
                : 'Ajouter des photos (${_images.length})',
          ),
        ),
        if (_serverErrors['image_files'] != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              _serverErrors['image_files']!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildCategory(AsyncValue<List<Category>> categories) {
    return categories.when(
      loading: () => const LinearProgressIndicator(
        semanticsLabel: 'Chargement des catégories',
      ),
      error: (error, stackTrace) => Row(
        children: [
          const Expanded(child: Text('Catégories indisponibles.')),
          TextButton(
            onPressed: () => ref.invalidate(categoriesProvider),
            child: const Text('Réessayer'),
          ),
        ],
      ),
      data: (list) => InputDecorator(
        decoration: InputDecoration(
          labelText: 'Catégorie',
          border: const OutlineInputBorder(),
          errorText: _categoryError ?? _serverErrors['category_id'],
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: _categoryId,
            isExpanded: true,
            hint: const Text('Sélectionnez'),
            items: [
              for (final category in list)
                DropdownMenuItem<String>(
                  value: category.id,
                  child: Text(category.name),
                ),
            ],
            onChanged: (value) => setState(() {
              _categoryId = value;
              _categoryError = null;
              _serverErrors.remove('category_id');
            }),
          ),
        ),
      ),
    );
  }
}

/// Miniature d'une photo choisie (lecture locale, taille réduite en mémoire).
class _Thumb extends StatelessWidget {
  const _Thumb({required this.image, required this.size, this.onRemove});

  final PickedImage? image;
  final double size;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final placeholder = ColoredBox(
      color: scheme.surfaceContainerHighest,
      child: Icon(Icons.image_outlined, color: scheme.outline),
    );
    final picked = image;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: picked == null
                ? placeholder
                : Image.file(
                    File(picked.path),
                    fit: BoxFit.cover,
                    cacheWidth: 300,
                    errorBuilder: (context, error, stackTrace) => placeholder,
                  ),
          ),
          if (onRemove != null)
            Positioned(
              top: 0,
              right: 0,
              child: IconButton(
                tooltip: 'Retirer la photo',
                iconSize: 18,
                visualDensity: VisualDensity.compact,
                style: IconButton.styleFrom(
                  backgroundColor: Colors.black54,
                  foregroundColor: Colors.white,
                ),
                onPressed: onRemove,
                icon: const Icon(Icons.close),
              ),
            ),
        ],
      ),
    );
  }
}
