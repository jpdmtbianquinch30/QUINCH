import 'dart:io';
import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:dio/dio.dart';
import 'package:video_player/video_player.dart';
import '../../models/category.dart';
import '../../services/product_service.dart';
import '../../config/theme.dart';

// ═══════════════════════════════════════════════════════════════
// IMAGE FILTERS (matching frontend)
// ═══════════════════════════════════════════════════════════════
class _PhotoFilter {
  final String id, name;
  final ColorFilter? colorFilter;
  final double brightness, saturation, contrast;

  const _PhotoFilter({
    required this.id,
    required this.name,
    this.colorFilter,
    this.brightness = 0,
    this.saturation = 1.0,
    this.contrast = 1.0,
  });
}

final _photoFilters = <_PhotoFilter>[
  const _PhotoFilter(id: 'none', name: 'Original'),
  const _PhotoFilter(id: 'bright', name: 'Lumineux', brightness: 0.15, contrast: 1.05),
  const _PhotoFilter(id: 'warm', name: 'Chaud', saturation: 1.3,
    colorFilter: ColorFilter.mode(Color(0x18FF9800), BlendMode.overlay)),
  const _PhotoFilter(id: 'cool', name: 'Froid', saturation: 0.9,
    colorFilter: ColorFilter.mode(Color(0x1A2196F3), BlendMode.overlay)),
  const _PhotoFilter(id: 'vivid', name: 'Vivide', saturation: 1.5, contrast: 1.1),
  const _PhotoFilter(id: 'bw', name: 'N&B',
    colorFilter: ColorFilter.mode(Colors.grey, BlendMode.saturation)),
  const _PhotoFilter(id: 'vintage', name: 'Vintage',
    colorFilter: ColorFilter.mode(Color(0x30795548), BlendMode.overlay), contrast: 0.9, brightness: 0.08),
  const _PhotoFilter(id: 'drama', name: 'Drama', contrast: 1.3, brightness: -0.05, saturation: 1.2),
];

// ═══════════════════════════════════════════════════════════════
// SELL SCREEN
// ═══════════════════════════════════════════════════════════════
class SellScreen extends StatefulWidget {
  const SellScreen({super.key});

  @override
  State<SellScreen> createState() => _SellScreenState();
}

class _SellScreenState extends State<SellScreen> {
  int _step = 0;
  String _type = 'product';
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  String? _categoryId;
  String _condition = 'new';
  bool _negotiable = false;
  bool _delivery = false;
  String _deliveryOption = 'free'; // 'free' or 'fixed'
  final _deliveryFeeCtrl = TextEditingController();
  int _stockQty = 1;
  List<Category> _categories = [];

  // Media
  XFile? _videoFile;
  String? _videoId;
  XFile? _posterImage;
  List<XFile> _images = [];
  bool _loading = false;

  // Video upload state
  bool _uploadingVideo = false;
  double _uploadProgress = 0;
  String? _videoResolution;
  VideoPlayerController? _videoPreviewCtrl;

  // Image editing
  int? _editingImageIndex; // null = not editing, -1 = poster, 0+ = additional images
  String _activeFilter = 'none';

  // Payment methods
  final Map<String, bool> _selectedPayments = {
    'orange_money': true,
    'wave': true,
    'free_money': true,
    'cash_delivery': false,
  };

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _priceCtrl.dispose();
    _deliveryFeeCtrl.dispose();
    _videoPreviewCtrl?.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    try {
      final cats = await context.read<ProductService>().getCategories();
      if (mounted) setState(() => _categories = cats);
    } catch (_) {}
  }

  // ─── IMAGE SOURCE PICKER (Camera / Gallery) ───
  Future<ImageSource?> _pickImageSource({String title = 'Ajouter une image'}) async {
    final navBarPadding = MediaQuery.of(context).padding.bottom + kBottomNavigationBarHeight;
    return showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: AppColors.bgCard,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + navBarPadding),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(title, style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 16)),
          const SizedBox(height: 16),
          ListTile(
            leading: Container(width: 40, height: 40, decoration: BoxDecoration(color: AppColors.accentSubtle, borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.camera_alt, color: AppColors.accent)),
            title: Text('Prendre une photo', style: TextStyle(color: AppColors.textPrimary, fontSize: 14)),
            subtitle: Text('Utiliser la caméra', style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
            onTap: () => Navigator.pop(context, ImageSource.camera),
          ),
          ListTile(
            leading: Container(width: 40, height: 40, decoration: BoxDecoration(color: AppColors.accentSubtle, borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.photo_library, color: AppColors.accent)),
            title: Text('Galerie', style: TextStyle(color: AppColors.textPrimary, fontSize: 14)),
            subtitle: Text('Choisir depuis les fichiers', style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
            onTap: () => Navigator.pop(context, ImageSource.gallery),
          ),
        ]),
      ),
    );
  }

  // ─── VIDEO PICK & UPLOAD ───
  Future<void> _pickVideo() async {
    final navBarPadding = MediaQuery.of(context).padding.bottom + kBottomNavigationBarHeight;
    final source = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.bgCard,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + navBarPadding),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('Ajouter une vidéo', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 16)),
          const SizedBox(height: 16),
          ListTile(
            leading: Container(width: 40, height: 40, decoration: BoxDecoration(color: AppColors.accentSubtle, borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.videocam, color: AppColors.accent)),
            title: Text('Enregistrer', style: TextStyle(color: AppColors.textPrimary, fontSize: 14)),
            subtitle: Text('Filmer avec la caméra', style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
            onTap: () => Navigator.pop(context, 'camera'),
          ),
          ListTile(
            leading: Container(width: 40, height: 40, decoration: BoxDecoration(color: AppColors.accentSubtle, borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.video_library, color: AppColors.accent)),
            title: Text('Galerie', style: TextStyle(color: AppColors.textPrimary, fontSize: 14)),
            subtitle: Text('Choisir depuis les fichiers', style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
            onTap: () => Navigator.pop(context, 'gallery'),
          ),
          const SizedBox(height: 8),
          Row(children: [
            Icon(Icons.info_outline, size: 12, color: AppColors.textMuted),
            SizedBox(width: 4),
            Flexible(child: Text('Formats: MP4, MOV, WebM — Max 500 Mo', style: TextStyle(color: AppColors.textMuted, fontSize: 10))),
          ]),
        ]),
      ),
    );
    if (source == null) return;

    XFile? picked;
    if (source == 'camera') {
      final picker = ImagePicker();
      picked = await picker.pickVideo(source: ImageSource.camera, maxDuration: const Duration(seconds: 120));
    } else {
      final result = await FilePicker.platform.pickFiles(type: FileType.video, allowMultiple: false);
      if (result != null && result.files.single.path != null) {
        picked = XFile(result.files.single.path!);
      }
    }

    if (picked == null || !mounted) return;

    final fileSize = await File(picked.path).length();
    if (fileSize > 500 * 1024 * 1024) {
      _showMsg('La vidéo ne doit pas dépasser 500 Mo.', error: true);
      return;
    }

    setState(() { _videoFile = picked; _videoId = null; _videoResolution = null; });
    _initVideoPreview(picked.path);
    _uploadVideoToServer(picked);
  }

  Future<void> _initVideoPreview(String path) async {
    _videoPreviewCtrl?.dispose();
    final ctrl = VideoPlayerController.file(File(path));
    _videoPreviewCtrl = ctrl;
    await ctrl.initialize();
    ctrl.setLooping(true);
    ctrl.setVolume(0);
    ctrl.play();
    if (mounted) {
      final w = ctrl.value.size.width.toInt();
      final h = ctrl.value.size.height.toInt();
      final maxDim = w > h ? w : h;
      String res = 'SD';
      if (maxDim >= 3840) res = '4K';
      else if (maxDim >= 1920) res = '1080p';
      else if (maxDim >= 1280) res = '720p';
      else if (maxDim >= 854) res = '480p';
      setState(() => _videoResolution = res);
    }
  }

  Future<void> _uploadVideoToServer(XFile file) async {
    setState(() { _uploadingVideo = true; _uploadProgress = 0; });
    try {
      final formData = FormData.fromMap({
        'video': await MultipartFile.fromFile(file.path, filename: file.name),
        'source': 'upload',
        if (_videoPreviewCtrl != null && _videoPreviewCtrl!.value.isInitialized) ...{
          'width': _videoPreviewCtrl!.value.size.width.toInt(),
          'height': _videoPreviewCtrl!.value.size.height.toInt(),
        },
      });

      final result = await context.read<ProductService>().uploadVideo(
        formData,
        onProgress: (sent, total) {
          if (mounted && total > 0) setState(() => _uploadProgress = sent / total);
        },
      );

      if (mounted) {
        final video = result['video'];
        setState(() { _videoId = video?['id']?.toString(); _uploadingVideo = false; _uploadProgress = 1.0; });
        _showMsg('Vidéo uploadée avec succès !');
      }
    } catch (e) {
      if (mounted) {
        setState(() { _uploadingVideo = false; _uploadProgress = 0; });
        if (e is DioException && e.response?.statusCode == 409) {
          final video = e.response?.data?['video'];
          if (video != null) {
            setState(() => _videoId = video['id']?.toString());
            _showMsg('Vidéo déjà existante, réutilisée.');
            return;
          }
        }
        _showMsg('Erreur lors de l\'upload de la vidéo', error: true);
      }
    }
  }

  void _removeVideo() {
    _videoPreviewCtrl?.dispose();
    _videoPreviewCtrl = null;
    setState(() { _videoFile = null; _videoId = null; _uploadingVideo = false; _uploadProgress = 0; _videoResolution = null; });
  }

  // ─── POSTER IMAGE (Camera / Gallery) ───
  Future<void> _pickPoster() async {
    final source = await _pickImageSource(title: 'Image d\'affiche');
    if (source == null) return;
    final picker = ImagePicker();
    final img = await picker.pickImage(source: source, maxWidth: 1200, imageQuality: 90);
    if (img != null && mounted) setState(() => _posterImage = img);
  }

  // ─── ADDITIONAL IMAGES (Camera / Gallery / Multi) ───
  Future<void> _pickImages() async {
    if (_images.length >= 5) {
      _showMsg('Maximum 5 photos supplémentaires', error: true);
      return;
    }

    final source = await _pickImageSource(title: 'Ajouter des photos');
    if (source == null) return;

    final picker = ImagePicker();
    if (source == ImageSource.camera) {
      final img = await picker.pickImage(source: ImageSource.camera, maxWidth: 1200, imageQuality: 90);
      if (img != null && mounted) {
        setState(() => _images.add(img));
      }
    } else {
      final images = await picker.pickMultiImage(maxWidth: 1200, imageQuality: 90);
      if (images.isNotEmpty && mounted) {
        setState(() => _images.addAll(images.take(5 - _images.length)));
      }
    }
  }

  // ─── IMAGE FILTER EDITOR ───
  void _openImageEditor(int index) {
    setState(() { _editingImageIndex = index; _activeFilter = 'none'; });
  }

  void _closeImageEditor() {
    setState(() { _editingImageIndex = null; _activeFilter = 'none'; });
  }

  String? get _editingImagePath {
    if (_editingImageIndex == null) return null;
    if (_editingImageIndex == -1) return _posterImage?.path;
    if (_editingImageIndex! >= 0 && _editingImageIndex! < _images.length) return _images[_editingImageIndex!].path;
    return null;
  }

  // ─── PUBLISH ───
  Future<void> _publish() async {
    if (!_formKey.currentState!.validate()) return;
    if (_posterImage == null) {
      _showMsg('L\'image principale (poster) est requise', error: true);
      return;
    }
    if (_categoryId == null) {
      _showMsg('Veuillez sélectionner une catégorie', error: true);
      return;
    }
    if (_uploadingVideo) {
      _showMsg('Attendez que la vidéo finisse de s\'uploader', error: true);
      return;
    }

    setState(() => _loading = true);
    try {
      final selectedPayments = _selectedPayments.entries.where((e) => e.value).map((e) => e.key).toList();

      await context.read<ProductService>().createProduct(
        title: _titleCtrl.text.trim(),
        description: _descCtrl.text.trim(),
        price: double.parse(_priceCtrl.text.trim()),
        type: _type,
        categoryId: _categoryId,
        condition: _condition,
        isNegotiable: _negotiable,
        deliveryAvailable: _delivery,
        videoId: _videoId,
        posterPath: _posterImage?.path,
        imagePaths: _images.map((i) => i.path).toList(),
        stockQuantity: _stockQty,
        paymentMethods: selectedPayments,
        deliveryOption: _delivery ? _deliveryOption : null,
        deliveryFee: _delivery && _deliveryOption == 'fixed'
            ? int.tryParse(_deliveryFeeCtrl.text.trim())
            : null,
      );
      if (!mounted) return;
      _showMsg('Publication créée avec succès !');
      context.go('/feed');
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      String errorMsg = 'Erreur lors de la publication';
      if (e is DioException && e.response?.data != null) {
        final data = e.response!.data;
        if (data is Map && data['message'] != null) errorMsg = data['message'].toString();
        else if (data is Map && data['errors'] != null) {
          final errors = data['errors'] as Map;
          errorMsg = errors.values.expand((v) => v is List ? v : [v]).join('\n');
        }
      }
      _showMsg(errorMsg, error: true);
    }
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

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom + kBottomNavigationBarHeight + 16;

    return Stack(children: [
      Scaffold(
        backgroundColor: AppColors.bgPrimary,
        appBar: AppBar(backgroundColor: AppColors.bgSecondary, title: Text('Publier', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 20))),
        body: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(20, 20, 20, bottomPadding),
          child: Form(
            key: _formKey,
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              // ═══ STEP INDICATOR ═══
              Row(children: List.generate(3, (i) => Expanded(
                child: Container(
                  margin: EdgeInsets.only(right: i < 2 ? 6 : 0), height: 4,
                  decoration: BoxDecoration(color: i <= _step ? AppColors.accent : AppColors.bgCard, borderRadius: BorderRadius.circular(2)),
                ),
              ))),
              const SizedBox(height: 8),
              Text(['1/3 — Média', '2/3 — Détails', '3/3 — Prix & options'][_step],
                style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
              const SizedBox(height: 20),

              // ═══ STEP 0: MEDIA ═══
              if (_step == 0) ..._buildMediaStep(),

              // ═══ STEP 1: DETAILS ═══
              if (_step == 1) ..._buildDetailsStep(),

              // ═══ STEP 2: PRICE & OPTIONS ═══
              if (_step == 2) ..._buildPriceStep(),

              const SizedBox(height: 24),

              // ═══ NAV BUTTONS ═══
              Row(children: [
                if (_step > 0)
                  Expanded(child: SizedBox(height: 48,
                    child: OutlinedButton(
                      onPressed: () => setState(() => _step--),
                      style: OutlinedButton.styleFrom(side: BorderSide(color: AppColors.border),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                      child: const Text('Précédent'),
                    ),
                  )),
                if (_step > 0) const SizedBox(width: 10),
                Expanded(child: SizedBox(height: 48,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: _step == 2 ? const LinearGradient(colors: [AppColors.success, Color(0xFF34D399)]) : AppColors.primaryGradient,
                      borderRadius: BorderRadius.circular(12)),
                    child: ElevatedButton(
                      onPressed: _loading ? null : () { if (_step < 2) setState(() => _step++); else _publish(); },
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.transparent, shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                      child: _loading
                          ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : Text(_step == 2 ? 'Publier' : 'Suivant', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                    ),
                  ),
                )),
              ]),
              const SizedBox(height: 20),
            ]),
          ),
        ),
      ),

      // ═══ IMAGE FILTER EDITOR (overlay) ═══
      if (_editingImageIndex != null && _editingImagePath != null) _buildImageEditor(),
    ]);
  }

  // ═══════════════════════════════════════════════════════════════
  // STEP 0 — MEDIA
  // ═══════════════════════════════════════════════════════════════
  List<Widget> _buildMediaStep() {
    return [
      // Type selector
      Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(color: AppColors.bgCard, borderRadius: BorderRadius.circular(12)),
        child: Row(children: [
          _TypeTab(label: 'Produit', icon: Icons.shopping_bag, active: _type == 'product',
            onTap: () => setState(() => _type = 'product')),
          _TypeTab(label: 'Service', icon: Icons.handyman, active: _type == 'service',
            color: AppColors.secondary, onTap: () => setState(() => _type = 'service')),
        ]),
      ),
      const SizedBox(height: 12),

      // Info message
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF1A2A4A), borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.accent.withValues(alpha: 0.3))),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Icon(Icons.info_outline, color: AppColors.accent, size: 18),
          const SizedBox(width: 10),
          Expanded(child: Text(
            _type == 'product'
                ? 'Les produits avec vidéo apparaîtront dans le fil "Pour toi". Les produits avec images uniquement seront visibles dans l\'Explorer et les recherches.'
                : 'Les services avec vidéo apparaîtront dans le fil "Pour toi". Les services avec images uniquement seront visibles dans l\'Explorer et les recherches.',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 12, height: 1.4),
          )),
        ]),
      ),
      const SizedBox(height: 16),

      // ─── VIDEO SECTION ───
      _sectionHeader('Vidéo de présentation', subtitle: 'optionnelle', icon: Icons.videocam),
      const SizedBox(height: 4),
      Text('Format vertical recommandé (9:16) — MP4, MOV, WebM — Max 200 Mo',
        style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
      const SizedBox(height: 10),

      if (_videoFile != null) ...[
        _buildVideoPreview(),
        // Action bar
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: _ActionBtn(icon: Icons.delete, label: 'Supprimer', color: AppColors.danger, onTap: _removeVideo)),
        ]),
      ] else
        _buildVideoPlaceholder(),

      // Upload progress
      if (_uploadingVideo) ...[
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(value: _uploadProgress, backgroundColor: AppColors.bgCard, color: AppColors.accent, minHeight: 4))),
          const SizedBox(width: 8),
          Text('${(_uploadProgress * 100).toInt()}%', style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
        ]),
      ],
      if (_videoId != null && !_uploadingVideo) ...[
        const SizedBox(height: 6),
        Row(children: [
          Icon(Icons.check_circle, color: AppColors.success, size: 14),
          const SizedBox(width: 4),
          Text('Vidéo prête', style: TextStyle(color: AppColors.success, fontSize: 11, fontWeight: FontWeight.w600)),
          if (_videoResolution != null) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(color: AppColors.accentSubtle, borderRadius: BorderRadius.circular(6)),
              child: Text(_videoResolution!, style: TextStyle(color: AppColors.accent, fontSize: 9, fontWeight: FontWeight.w700)),
            ),
          ],
        ]),
      ],

      const SizedBox(height: 24),

      // ─── POSTER IMAGE ───
      _sectionHeader('Image d\'affiche', required: true, icon: Icons.photo_camera),
      const SizedBox(height: 4),
      Text(
        _type == 'product'
            ? 'Cette image sera la couverture de votre produit dans Explorer'
            : 'Cette image sera la couverture de votre service dans Explorer',
        style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
      const SizedBox(height: 10),

      if (_posterImage != null)
        _buildPosterPreview()
      else
        _buildPosterPlaceholder(),

      const SizedBox(height: 24),

      // ─── ADDITIONAL IMAGES ───
      Row(children: [
        Expanded(child: _sectionHeader(
          _type == 'product' ? 'Photos supplémentaires' : 'Portfolio / Réalisations',
          icon: Icons.photo_library)),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(color: AppColors.bgCard, borderRadius: BorderRadius.circular(8)),
          child: Text('${_images.length}/5', style: TextStyle(color: AppColors.textMuted, fontSize: 11, fontWeight: FontWeight.w600)),
        ),
      ]),
      const SizedBox(height: 4),
      Text('Jusqu\'à 5 images — Tap pour modifier — Max 10 Mo chacune',
        style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
      const SizedBox(height: 10),
      _buildImagesGrid(),
    ];
  }

  Widget _sectionHeader(String title, {bool required = false, String? subtitle, IconData? icon}) {
    return Row(children: [
      if (icon != null) ...[
        Icon(icon, size: 18, color: AppColors.accent),
        const SizedBox(width: 6),
      ],
      Text(title, style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 15)),
      if (required)
        const Text(' *', style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.w600, fontSize: 15)),
      if (subtitle != null) ...[
        const SizedBox(width: 6),
        Text('($subtitle)', style: TextStyle(color: AppColors.textMuted, fontWeight: FontWeight.w400, fontSize: 12)),
      ],
    ]);
  }

  // ── Video placeholder ──
  Widget _buildVideoPlaceholder() {
    return GestureDetector(
      onTap: _pickVideo,
      child: Container(
        height: 140,
        decoration: BoxDecoration(color: AppColors.bgInput, borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border, style: BorderStyle.solid)),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          // Camera option
          Expanded(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Container(width: 50, height: 50, decoration: BoxDecoration(
              color: AppColors.accentSubtle, borderRadius: BorderRadius.circular(14)),
              child: const Icon(Icons.upload_file, color: AppColors.accent, size: 24)),
            const SizedBox(height: 8),
            Text('Importer', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 12)),
            Text('ou filmer', style: TextStyle(color: AppColors.textMuted, fontSize: 10)),
          ])),
        ]),
      ),
    );
  }

  // ── Video preview ──
  Widget _buildVideoPreview() {
    return Container(
      height: 280,
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.accent)),
      clipBehavior: Clip.antiAlias,
      child: Stack(children: [
        if (_videoPreviewCtrl != null && _videoPreviewCtrl!.value.isInitialized)
          SizedBox(
            width: double.infinity, height: 280,
            child: FittedBox(fit: BoxFit.cover,
              child: SizedBox(
                width: _videoPreviewCtrl!.value.size.width,
                height: _videoPreviewCtrl!.value.size.height,
                child: VideoPlayer(_videoPreviewCtrl!),
              ),
            ),
          )
        else
          Container(width: double.infinity, height: 280, color: AppColors.bgCard,
            child: const Center(child: CircularProgressIndicator(color: AppColors.accent, strokeWidth: 2))),

        // Badges
        if (_videoResolution != null)
          Positioned(top: 10, left: 10,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: AppColors.accent, borderRadius: BorderRadius.circular(6)),
              child: Text(_videoResolution!, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700)),
            )),

        Positioned(top: 10, right: 10,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: _videoId != null ? AppColors.success : (_uploadingVideo ? AppColors.warning : Colors.black54),
              borderRadius: BorderRadius.circular(6)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(
                _videoId != null ? Icons.check_circle : (_uploadingVideo ? Icons.cloud_upload : Icons.hourglass_empty),
                color: Colors.white, size: 12),
              const SizedBox(width: 4),
              Text(
                _videoId != null ? 'Prête' : (_uploadingVideo ? 'Upload...' : 'En attente'),
                style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600)),
            ]),
          )),

        // Play/Pause
        if (_videoPreviewCtrl != null && _videoPreviewCtrl!.value.isInitialized)
          Positioned.fill(child: GestureDetector(
            onTap: () => setState(() {
              _videoPreviewCtrl!.value.isPlaying ? _videoPreviewCtrl!.pause() : _videoPreviewCtrl!.play();
            }),
            child: Container(color: Colors.transparent),
          )),
      ]),
    );
  }

  // ── Poster preview with overlay ──
  Widget _buildPosterPreview() {
    return GestureDetector(
      onTap: () => _openImageEditor(-1),
      child: Container(
        height: 180,
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.accent)),
        clipBehavior: Clip.antiAlias,
        child: Stack(fit: StackFit.expand, children: [
          Image.file(File(_posterImage!.path), fit: BoxFit.cover),

          // Overlay on hover/tap
          Positioned(bottom: 0, left: 0, right: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                gradient: LinearGradient(begin: Alignment.bottomCenter, end: Alignment.topCenter,
                  colors: [Colors.black.withValues(alpha: 0.8), Colors.transparent])),
              child: Row(children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: AppColors.accent, borderRadius: BorderRadius.circular(6)),
                  child: const Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.check_circle, color: Colors.white, size: 12),
                    SizedBox(width: 4),
                    Text('Image d\'affiche', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600)),
                  ]),
                ),
                const Spacer(),
                _MiniActionBtn(icon: Icons.tune, label: 'Modifier', onTap: () => _openImageEditor(-1)),
                const SizedBox(width: 6),
                _MiniActionBtn(icon: Icons.refresh, label: 'Changer', onTap: _pickPoster),
                const SizedBox(width: 6),
                _MiniActionBtn(icon: Icons.delete, label: 'Suppr.', color: AppColors.danger,
                  onTap: () => setState(() => _posterImage = null)),
              ]),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _buildPosterPlaceholder() {
    return GestureDetector(
      onTap: _pickPoster,
      child: Container(
        height: 120, width: double.infinity,
        decoration: BoxDecoration(color: AppColors.bgInput, borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border, style: BorderStyle.solid)),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(width: 50, height: 50, decoration: BoxDecoration(
            color: AppColors.accentSubtle, borderRadius: BorderRadius.circular(14)),
            child: const Icon(Icons.add_a_photo, color: AppColors.accent, size: 24)),
          const SizedBox(height: 8),
          Text('Ajouter l\'image d\'affiche', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 13)),
          Text('JPEG, PNG, WebP — Max 5 Mo', style: TextStyle(color: AppColors.textMuted, fontSize: 10)),
        ]),
      ),
    );
  }

  // ── Images grid with edit overlay ──
  Widget _buildImagesGrid() {
    return GridView.count(
      crossAxisCount: 3, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 8, crossAxisSpacing: 8,
      children: [
        ..._images.asMap().entries.map((e) => GestureDetector(
          onTap: () => _openImageEditor(e.key),
          child: Container(
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
            clipBehavior: Clip.antiAlias,
            child: Stack(fit: StackFit.expand, children: [
              Image.file(File(e.value.path), fit: BoxFit.cover),
              // Edit overlay
              Positioned(bottom: 0, left: 0, right: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  color: Colors.black54,
                  child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(Icons.tune, color: Colors.white70, size: 14),
                    SizedBox(width: 4),
                    Text('Modifier', style: TextStyle(color: Colors.white70, fontSize: 9)),
                  ]),
                ),
              ),
              // Delete button
              Positioned(top: 4, right: 4,
                child: GestureDetector(
                  onTap: () => setState(() => _images.removeAt(e.key)),
                  child: Container(width: 22, height: 22,
                    decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(11)),
                    child: const Icon(Icons.close, color: Colors.white, size: 12)),
                )),
            ]),
          ),
        )),
        if (_images.length < 5)
          GestureDetector(
            onTap: _pickImages,
            child: Container(
              decoration: BoxDecoration(color: AppColors.bgInput, borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border)),
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.add_photo_alternate, color: AppColors.accent, size: 28),
                SizedBox(height: 4),
                Text('Ajouter', style: TextStyle(color: AppColors.textMuted, fontSize: 10)),
              ]),
            ),
          ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // IMAGE FILTER EDITOR (Full-screen overlay like frontend)
  // ═══════════════════════════════════════════════════════════════
  Widget _buildImageEditor() {
    final path = _editingImagePath!;
    final filter = _photoFilters.firstWhere((f) => f.id == _activeFilter, orElse: () => _photoFilters[0]);

    return Material(
      color: Colors.black.withValues(alpha: 0.95),
      child: SafeArea(
        child: Column(children: [
          // Top bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(children: [
              GestureDetector(
                onTap: _closeImageEditor,
                child: Container(width: 36, height: 36,
                  decoration: BoxDecoration(color: Colors.white12, borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.arrow_back, color: Colors.white, size: 20)),
              ),
              const SizedBox(width: 12),
              const Expanded(child: Text('Modifier l\'image', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700))),
              GestureDetector(
                onTap: () {
                  // Apply filter (just close for now — CSS filters are visual only)
                  _closeImageEditor();
                  _showMsg('Filtre appliqué !');
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(color: AppColors.accent, borderRadius: BorderRadius.circular(10)),
                  child: const Text('Appliquer', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                ),
              ),
            ]),
          ),

          // Preview
          Expanded(
            child: Center(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(16),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: 30)]),
                clipBehavior: Clip.antiAlias,
                child: ColorFiltered(
                  colorFilter: filter.colorFilter ?? const ColorFilter.mode(Colors.transparent, BlendMode.dst),
                  child: Image.file(File(path), fit: BoxFit.contain),
                ),
              ),
            ),
          ),

          // Filter strip
          const SizedBox(height: 12),
          SizedBox(
            height: 100,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _photoFilters.length,
              itemBuilder: (_, i) {
                final f = _photoFilters[i];
                final isActive = _activeFilter == f.id;
                return GestureDetector(
                  onTap: () => setState(() => _activeFilter = f.id),
                  child: Container(
                    width: 72,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: isActive ? AppColors.accent : Colors.white12, width: isActive ? 2 : 1),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Column(children: [
                      Expanded(
                        child: ColorFiltered(
                          colorFilter: f.colorFilter ?? const ColorFilter.mode(Colors.transparent, BlendMode.dst),
                          child: Image.file(File(path), fit: BoxFit.cover, width: 72),
                        ),
                      ),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        color: isActive ? AppColors.accent : const Color(0xFF1A1F35),
                        child: Text(f.name, textAlign: TextAlign.center,
                          style: TextStyle(color: isActive ? Colors.white : Colors.white70, fontSize: 9, fontWeight: isActive ? FontWeight.w700 : FontWeight.w400)),
                      ),
                    ]),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 20),
        ]),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // STEP 1 — DETAILS
  // ═══════════════════════════════════════════════════════════════
  List<Widget> _buildDetailsStep() {
    return [
      _Label('Titre *'),
      const SizedBox(height: 8),
      TextFormField(controller: _titleCtrl, style: TextStyle(color: AppColors.textPrimary),
        decoration: const InputDecoration(hintText: 'Ex: iPhone 14 Pro Max 256Go'),
        validator: (v) => v == null || v.trim().isEmpty ? 'Titre requis' : null),
      const SizedBox(height: 16),
      _Label('Description'),
      const SizedBox(height: 8),
      TextFormField(controller: _descCtrl, maxLines: 4, minLines: 3,
        style: TextStyle(color: AppColors.textPrimary),
        decoration: const InputDecoration(hintText: 'Décrivez votre produit ou service en détail...')),
      const SizedBox(height: 16),
      _Label('Catégorie *'),
      const SizedBox(height: 8),
      DropdownButtonFormField<String>(
        value: _categoryId,
        decoration: const InputDecoration(hintText: 'Sélectionner une catégorie'),
        dropdownColor: AppColors.bgElevated,
        items: _categories.map((c) => DropdownMenuItem<String>(value: c.id, child: Text(c.name))).toList(),
        onChanged: (v) => setState(() => _categoryId = v),
        style: TextStyle(color: AppColors.textPrimary),
        validator: (v) => v == null ? 'Catégorie requise' : null),
      if (_type == 'product') ...[
        const SizedBox(height: 16),
        _Label('État'),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: [
          _CondChip(label: 'Neuf', active: _condition == 'new', onTap: () => setState(() => _condition = 'new')),
          _CondChip(label: 'Comme neuf', active: _condition == 'like_new', onTap: () => setState(() => _condition = 'like_new')),
          _CondChip(label: 'Bon état', active: _condition == 'good', onTap: () => setState(() => _condition = 'good')),
          _CondChip(label: 'Usé', active: _condition == 'fair', onTap: () => setState(() => _condition = 'fair')),
        ]),
      ],
    ];
  }

  // ═══════════════════════════════════════════════════════════════
  // STEP 2 — PRICE & OPTIONS
  // ═══════════════════════════════════════════════════════════════
  List<Widget> _buildPriceStep() {
    return [
      _Label('Prix (F CFA) *'),
      const SizedBox(height: 8),
      TextFormField(controller: _priceCtrl, keyboardType: TextInputType.number,
        style: TextStyle(color: AppColors.textPrimary, fontSize: 20, fontWeight: FontWeight.w700),
        decoration: const InputDecoration(hintText: '0', suffixText: 'F CFA'),
        validator: (v) => v == null || v.trim().isEmpty ? 'Prix requis' : null),
      const SizedBox(height: 16),
      _Toggle(label: 'Prix négociable', subtitle: 'Les acheteurs peuvent proposer un prix',
        value: _negotiable, onChanged: (v) => setState(() => _negotiable = v)),
      const SizedBox(height: 12),
      if (_type == 'product') ...[
        _Toggle(label: 'Livraison disponible', subtitle: 'Vous pouvez livrer ce produit',
          value: _delivery, onChanged: (v) => setState(() => _delivery = v)),

        // ─── DELIVERY OPTIONS (shown when delivery is enabled) ───
        if (_delivery) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.bgCard, borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.accent.withValues(alpha: 0.3)),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Icon(Icons.local_shipping, color: AppColors.accent, size: 18),
                SizedBox(width: 8),
                Text('Frais de livraison', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 14)),
              ]),
              const SizedBox(height: 12),

              // Free / Fixed toggle
              Row(children: [
                Expanded(child: GestureDetector(
                  onTap: () => setState(() => _deliveryOption = 'free'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: _deliveryOption == 'free' ? AppColors.success.withValues(alpha: 0.15) : AppColors.bgInput,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: _deliveryOption == 'free' ? AppColors.success : AppColors.border),
                    ),
                    child: Column(children: [
                      Icon(Icons.card_giftcard,
                        color: _deliveryOption == 'free' ? AppColors.success : AppColors.textMuted, size: 24),
                      const SizedBox(height: 6),
                      Text('Gratuite',
                        style: TextStyle(
                          color: _deliveryOption == 'free' ? AppColors.success : AppColors.textSecondary,
                          fontWeight: _deliveryOption == 'free' ? FontWeight.w700 : FontWeight.w500,
                          fontSize: 13)),
                      const SizedBox(height: 2),
                      Text('0 F CFA',
                        style: TextStyle(
                          color: _deliveryOption == 'free' ? AppColors.success.withValues(alpha: 0.7) : AppColors.textMuted,
                          fontSize: 10)),
                    ]),
                  ),
                )),
                const SizedBox(width: 10),
                Expanded(child: GestureDetector(
                  onTap: () => setState(() => _deliveryOption = 'fixed'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: _deliveryOption == 'fixed' ? AppColors.accent.withValues(alpha: 0.15) : AppColors.bgInput,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: _deliveryOption == 'fixed' ? AppColors.accent : AppColors.border),
                    ),
                    child: Column(children: [
                      Icon(Icons.payments,
                        color: _deliveryOption == 'fixed' ? AppColors.accent : AppColors.textMuted, size: 24),
                      const SizedBox(height: 6),
                      Text('Frais fixes',
                        style: TextStyle(
                          color: _deliveryOption == 'fixed' ? AppColors.accent : AppColors.textSecondary,
                          fontWeight: _deliveryOption == 'fixed' ? FontWeight.w700 : FontWeight.w500,
                          fontSize: 13)),
                      const SizedBox(height: 2),
                      Text('Montant à définir',
                        style: TextStyle(
                          color: _deliveryOption == 'fixed' ? AppColors.accent.withValues(alpha: 0.7) : AppColors.textMuted,
                          fontSize: 10)),
                    ]),
                  ),
                )),
              ]),

              // Fee input (shown only for fixed)
              if (_deliveryOption == 'fixed') ...[
                const SizedBox(height: 12),
                TextFormField(
                  controller: _deliveryFeeCtrl,
                  keyboardType: TextInputType.number,
                  style: TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w600),
                  decoration: InputDecoration(
                    hintText: 'Ex: 1500',
                    hintStyle: TextStyle(color: AppColors.textMuted),
                    prefixIcon: const Icon(Icons.local_shipping, color: AppColors.accent, size: 20),
                    suffixText: 'F CFA',
                    suffixStyle: TextStyle(color: AppColors.textMuted, fontSize: 12),
                    filled: true, fillColor: AppColors.bgInput,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 6),
                Text('Ce montant sera affiché aux acheteurs en plus du prix du produit',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 10)),
              ],

              // Free delivery info
              if (_deliveryOption == 'free') ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8)),
                  child: const Row(children: [
                    Icon(Icons.check_circle, color: AppColors.success, size: 16),
                    SizedBox(width: 8),
                    Expanded(child: Text('La livraison gratuite attire plus d\'acheteurs !',
                      style: TextStyle(color: AppColors.success, fontSize: 11, fontWeight: FontWeight.w500))),
                  ]),
                ),
              ],
            ]),
          ),
        ],

        const SizedBox(height: 16),
        _Label('Quantité en stock'),
        const SizedBox(height: 8),
        Row(children: [
          IconButton(onPressed: _stockQty > 1 ? () => setState(() => _stockQty--) : null,
            icon: Icon(Icons.remove_circle_outline, color: AppColors.textMuted)),
          Container(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            decoration: BoxDecoration(color: AppColors.bgCard, borderRadius: BorderRadius.circular(8)),
            child: Text('$_stockQty', style: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w700))),
          IconButton(onPressed: () => setState(() => _stockQty++),
            icon: const Icon(Icons.add_circle_outline, color: AppColors.accent)),
        ]),
      ],
      const SizedBox(height: 16),
      _Label('Méthodes de paiement acceptées'),
      const SizedBox(height: 8),
      ..._selectedPayments.entries.map((entry) {
        final labels = {'orange_money': 'Orange Money', 'wave': 'Wave', 'free_money': 'Free Money', 'cash_delivery': 'Paiement à la livraison'};
        return CheckboxListTile(
          value: entry.value,
          onChanged: (v) => setState(() => _selectedPayments[entry.key] = v ?? false),
          title: Text(labels[entry.key] ?? entry.key, style: TextStyle(color: AppColors.textPrimary, fontSize: 13)),
          dense: true, contentPadding: EdgeInsets.zero, activeColor: AppColors.accent,
          controlAffinity: ListTileControlAffinity.leading);
      }),
      const SizedBox(height: 20),
      // Summary
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: AppColors.bgCard, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Récapitulatif', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 14)),
          const SizedBox(height: 8),
          _SummaryRow('Type', _type == 'product' ? 'Produit' : 'Service'),
          _SummaryRow('Vidéo', _videoId != null ? 'Uploadée${_videoResolution != null ? " ($_videoResolution)" : ""}' : '—'),
          _SummaryRow('Poster', _posterImage != null ? 'Sélectionné' : 'Requis'),
          _SummaryRow('Photos', '${_images.length}/5'),
          if (_type == 'product' && _delivery)
            _SummaryRow('Livraison', _deliveryOption == 'free'
                ? 'Gratuite'
                : 'Frais fixes${_deliveryFeeCtrl.text.trim().isNotEmpty ? " (${_deliveryFeeCtrl.text.trim()} F)" : ""}'),
        ]),
      ),
    ];
  }
}

// ═══════════════════════════════════════════════════════════════
// HELPER WIDGETS
// ═══════════════════════════════════════════════════════════════

class _MiniActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;
  final VoidCallback onTap;
  const _MiniActionBtn({required this.icon, required this.label, this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(color: (color ?? Colors.white).withValues(alpha: 0.2), borderRadius: BorderRadius.circular(6)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: color ?? Colors.white, size: 12),
          const SizedBox(width: 3),
          Text(label, style: TextStyle(color: color ?? Colors.white, fontSize: 9, fontWeight: FontWeight.w600)),
        ]),
      ),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _ActionBtn({required this.icon, required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.3))),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
        ]),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);
  @override
  Widget build(BuildContext context) => Text(text, style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 15));
}

class _TypeTab extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool active;
  final Color? color;
  final VoidCallback onTap;
  const _TypeTab({required this.label, required this.icon, required this.active, this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.accent;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(color: active ? c.withValues(alpha: 0.15) : Colors.transparent, borderRadius: BorderRadius.circular(10)),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, size: 18, color: active ? c : AppColors.textMuted),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(color: active ? c : AppColors.textMuted, fontWeight: active ? FontWeight.w600 : FontWeight.w500, fontSize: 13)),
          ]),
        ),
      ),
    );
  }
}

class _CondChip extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _CondChip({required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(color: active ? AppColors.accentSubtle : AppColors.bgCard, borderRadius: BorderRadius.circular(10),
          border: Border.all(color: active ? AppColors.accent : AppColors.border)),
        child: Text(label, style: TextStyle(color: active ? AppColors.accent : AppColors.textSecondary, fontSize: 12, fontWeight: active ? FontWeight.w600 : FontWeight.w400)),
      ),
    );
  }
}

class _Toggle extends StatelessWidget {
  final String label, subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _Toggle({required this.label, required this.subtitle, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(color: AppColors.bgCard, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
      child: Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w500, fontSize: 14)),
          Text(subtitle, style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
        ])),
        Switch(value: value, onChanged: onChanged, activeTrackColor: AppColors.accent, inactiveTrackColor: AppColors.bgInput),
      ]),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label, value;
  const _SummaryRow(this.label, this.value);
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
        Flexible(child: Text(value, style: TextStyle(color: AppColors.textPrimary, fontSize: 12, fontWeight: FontWeight.w500), textAlign: TextAlign.end)),
      ]),
    );
  }
}
