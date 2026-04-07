import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import '../../providers/auth_provider.dart';
import '../../services/user_service.dart';
import '../../config/theme.dart';
import '../../config/api_config.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameCtrl;
  late TextEditingController _usernameCtrl;
  late TextEditingController _emailCtrl;
  late TextEditingController _bioCtrl;
  String? _selectedCity;
  String? _selectedRegion;
  bool _saving = false;
  bool _uploadingAvatar = false;
  bool _uploadingCover = false;
  String? _localAvatarPath;
  String? _localCoverPath;

  static final _regions = <String>[
    'Dakar', 'Diourbel', 'Fatick', 'Kaffrine', 'Kaolack', 'Kédougou',
    'Kolda', 'Louga', 'Matam', 'Saint-Louis', 'Sédhiou', 'Tambacounda',
    'Thiès', 'Ziguinchor',
  ];

  static final _regionCities = <String, List<String>>{
    'Dakar': ['Dakar', 'Pikine', 'Guédiawaye', 'Rufisque', 'Keur Massar', 'Diamniadio'],
    'Diourbel': ['Diourbel', 'Touba', 'Mbacké', 'Bambey'],
    'Fatick': ['Fatick', 'Foundiougne', 'Gossas'],
    'Kaffrine': ['Kaffrine', 'Birkelane', 'Koungheul', 'Malem-Hodar'],
    'Kaolack': ['Kaolack', 'Nioro du Rip', 'Guinguinéo'],
    'Kédougou': ['Kédougou', 'Salémata', 'Saraya'],
    'Kolda': ['Kolda', 'Vélingara', 'Médina Yoro Foulah'],
    'Louga': ['Louga', 'Linguère', 'Kébémer'],
    'Matam': ['Matam', 'Kanel', 'Ranérou'],
    'Saint-Louis': ['Saint-Louis', 'Richard-Toll', 'Dagana', 'Podor'],
    'Sédhiou': ['Sédhiou', 'Bounkiling', 'Goudomp'],
    'Tambacounda': ['Tambacounda', 'Bakel', 'Goudiry', 'Koumpentoum'],
    'Thiès': ['Thiès', 'Mbour', 'Tivaouane', 'Saly', 'Joal-Fadiouth'],
    'Ziguinchor': ['Ziguinchor', 'Bignona', 'Oussouye'],
  };

  List<String> get _cities {
    if (_selectedRegion != null && _regionCities.containsKey(_selectedRegion)) {
      return List<String>.from(_regionCities[_selectedRegion]!);
    }
    final all = _regionCities.values.expand((c) => c).toList();
    all.sort();
    return all;
  }

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthProvider>().user;
    _nameCtrl = TextEditingController(text: user?.fullName);
    _usernameCtrl = TextEditingController(text: user?.username);
    _emailCtrl = TextEditingController(text: user?.email);
    _bioCtrl = TextEditingController(text: user?.bio);

    // Only set region/city if they exist in our lists (prevents DropdownButton crash)
    final userRegion = user?.region;
    if (userRegion != null && _regions.contains(userRegion)) {
      _selectedRegion = userRegion;
    }
    final userCity = user?.city;
    if (userCity != null && _selectedRegion != null) {
      final cities = _regionCities[_selectedRegion] ?? [];
      if (cities.contains(userCity)) {
        _selectedCity = userCity;
      }
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _usernameCtrl.dispose();
    _emailCtrl.dispose();
    _bioCtrl.dispose();
    super.dispose();
  }

  // ═══ PICK & UPLOAD AVATAR ═══
  Future<void> _pickAvatar() async {
    final file = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 600);
    if (file == null || !mounted) return;
    setState(() {
      _localAvatarPath = file.path;
      _uploadingAvatar = true;
    });
    try {
      await context.read<UserService>().updateAvatar(file.path);
      if (mounted) await context.read<AuthProvider>().refreshUser();
      if (mounted) {
        setState(() => _uploadingAvatar = false);
        _showSuccess('Photo de profil mise à jour !');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _uploadingAvatar = false);
        _showError('Erreur lors de l\'upload de la photo.');
      }
    }
  }

  // ═══ PICK & UPLOAD COVER ═══
  Future<void> _pickCover() async {
    final file = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 1200);
    if (file == null || !mounted) return;
    setState(() {
      _localCoverPath = file.path;
      _uploadingCover = true;
    });
    try {
      final formData = FormData.fromMap({
        'cover': await MultipartFile.fromFile(file.path),
      });
      await context.read<UserService>().uploadCover(formData);
      if (mounted) await context.read<AuthProvider>().refreshUser();
      if (mounted) {
        setState(() => _uploadingCover = false);
        _showSuccess('Photo de couverture mise à jour !');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _uploadingCover = false);
        _showError('Erreur lors de l\'upload de la couverture.');
      }
    }
  }

  // ═══ SAVE PROFILE ═══
  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    // Only send non-empty values (like the frontend)
    final payload = <String, dynamic>{};
    final name = _nameCtrl.text.trim();
    final username = _usernameCtrl.text.trim();
    final email = _emailCtrl.text.trim();

    if (name.isNotEmpty) payload['full_name'] = name;
    if (username.isNotEmpty) payload['username'] = username;
    if (email.isNotEmpty) payload['email'] = email;
    // Bio: always send it (even empty to allow clearing)
    payload['bio'] = _bioCtrl.text.trim();
    if (_selectedCity != null && _selectedCity!.isNotEmpty) payload['city'] = _selectedCity;
    if (_selectedRegion != null && _selectedRegion!.isNotEmpty) payload['region'] = _selectedRegion;

    try {
      await context.read<UserService>().updateProfile(extra: payload);
      if (mounted) await context.read<AuthProvider>().refreshUser();
      if (mounted) {
        Navigator.pop(context);
        _showSuccess('Profil mis à jour !');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        String msg = 'Erreur lors de la sauvegarde.';
        if (e is DioException && e.response?.data is Map) {
          final data = e.response!.data as Map;
          msg = data['message'] ?? msg;
          // Show validation errors
          if (data['errors'] is Map) {
            final errors = data['errors'] as Map;
            final firstError = errors.values.first;
            if (firstError is List && firstError.isNotEmpty) {
              msg = firstError.first.toString();
            }
          }
        }
        _showError(msg);
      }
    }
  }

  void _showSuccess(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        const Icon(Icons.check_circle, color: Colors.white, size: 18),
        const SizedBox(width: 8),
        Expanded(child: Text(msg, style: const TextStyle(color: Colors.white, fontSize: 13))),
      ]),
      backgroundColor: const Color(0xFF10B981),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 20),
    ));
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        const Icon(Icons.error_outline, color: Colors.white, size: 18),
        const SizedBox(width: 8),
        Expanded(child: Text(msg, style: const TextStyle(color: Colors.white, fontSize: 13))),
      ]),
      backgroundColor: AppColors.danger,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 20),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    final avatarUrl = user?.avatarUrl;
    final coverUrl = user?.coverUrl;

    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      body: CustomScrollView(
        slivers: [
          // ═══ APP BAR ═══
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            backgroundColor: AppColors.bgSecondary,
            leading: IconButton(
              onPressed: () => Navigator.pop(context),
              icon: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.4),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
              ),
            ),
            title: const Text('Modifier le profil',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: _saving
                    ? const Center(
                        child: SizedBox(
                          width: 20, height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accent),
                        ),
                      )
                    : TextButton(
                        onPressed: _save,
                        child: const Text('Sauvegarder',
                            style: TextStyle(color: AppColors.accent, fontWeight: FontWeight.w600, fontSize: 14)),
                      ),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  // Cover image
                  if (_localCoverPath != null)
                    Image.file(File(_localCoverPath!), fit: BoxFit.cover)
                  else if (coverUrl != null && coverUrl.isNotEmpty)
                    CachedNetworkImage(
                      imageUrl: ApiConfig.resolveUrl(coverUrl),
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => _coverPlaceholder(),
                    )
                  else
                    _coverPlaceholder(),
                  // Gradient overlay
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.1),
                          Colors.black.withValues(alpha: 0.6),
                        ],
                      ),
                    ),
                  ),
                  // Upload cover button
                  Positioned(
                    right: 16, bottom: 16,
                    child: GestureDetector(
                      onTap: _uploadingCover ? null : _pickCover,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (_uploadingCover)
                              const SizedBox(
                                width: 16, height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            else
                              const Icon(Icons.photo_camera, color: Colors.white, size: 16),
                            const SizedBox(width: 6),
                            Text(
                              _uploadingCover ? 'Upload...' : 'Bannière',
                              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ═══ BODY ═══
          SliverToBoxAdapter(
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  // ═══ AVATAR SECTION ═══
                  Container(
                    margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.bgCard,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      children: [
                        // Avatar
                        GestureDetector(
                          onTap: _uploadingAvatar ? null : _pickAvatar,
                          child: Stack(
                            children: [
                              Container(
                                width: 72, height: 72,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(color: AppColors.accent, width: 2.5),
                                ),
                                child: ClipOval(
                                  child: _localAvatarPath != null
                                      ? Image.file(File(_localAvatarPath!), fit: BoxFit.cover,
                                          width: 67, height: 67)
                                      : avatarUrl != null && avatarUrl.isNotEmpty
                                          ? CachedNetworkImage(
                                              imageUrl: ApiConfig.resolveUrl(avatarUrl),
                                              fit: BoxFit.cover,
                                              width: 67, height: 67,
                                              errorWidget: (_, __, ___) => _avatarFallback(user?.fullName),
                                            )
                                          : _avatarFallback(user?.fullName),
                                ),
                              ),
                              // Camera badge
                              Positioned(
                                bottom: 0, right: 0,
                                child: Container(
                                  width: 26, height: 26,
                                  decoration: BoxDecoration(
                                    gradient: AppColors.primaryGradient,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: AppColors.bgCard, width: 2),
                                  ),
                                  child: _uploadingAvatar
                                      ? const Padding(
                                          padding: EdgeInsets.all(4),
                                          child: CircularProgressIndicator(
                                              strokeWidth: 2, color: Colors.white),
                                        )
                                      : const Icon(Icons.camera_alt, color: Colors.white, size: 13),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 14),
                        // Info text
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Photo de profil',
                                  style: TextStyle(
                                      color: AppColors.textPrimary,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600)),
                              const SizedBox(height: 2),
                              Text('Une photo claire augmente la confiance de 40%',
                                  style: TextStyle(
                                      color: AppColors.textMuted,
                                      fontSize: 11)),
                              const SizedBox(height: 6),
                              GestureDetector(
                                onTap: _pickAvatar,
                                child: const Text('Changer la photo',
                                    style: TextStyle(
                                        color: AppColors.accent,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600)),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // ═══ PERSONAL INFO SECTION ═══
                  _buildSection(
                    icon: Icons.person,
                    title: 'Informations personnelles',
                    children: [
                      _buildField(
                        label: 'Nom complet *',
                        child: TextFormField(
                          controller: _nameCtrl,
                          style: TextStyle(color: AppColors.textPrimary, fontSize: 14),
                          decoration: _inputDecoration(
                            hint: 'Votre nom complet',
                            prefixIcon: Icons.person_outline,
                          ),
                          validator: (v) =>
                              v == null || v.trim().length < 2 ? 'Le nom est requis (2 caractères min.)' : null,
                        ),
                      ),
                      const SizedBox(height: 14),
                      _buildField(
                        label: "Nom d'utilisateur",
                        hint: 'Ce nom sera visible par tous.',
                        child: TextFormField(
                          controller: _usernameCtrl,
                          style: TextStyle(color: AppColors.textPrimary, fontSize: 14),
                          decoration: _inputDecoration(
                            hint: 'nomdutilisateur',
                            prefixText: '@  ',
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      _buildField(
                        label: 'Email',
                        child: TextFormField(
                          controller: _emailCtrl,
                          keyboardType: TextInputType.emailAddress,
                          style: TextStyle(color: AppColors.textPrimary, fontSize: 14),
                          decoration: _inputDecoration(
                            hint: 'email@exemple.com',
                            prefixIcon: Icons.email_outlined,
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      _buildField(
                        label: 'Bio',
                        child: TextFormField(
                          controller: _bioCtrl,
                          maxLines: 3,
                          minLines: 2,
                          style: TextStyle(color: AppColors.textPrimary, fontSize: 14),
                          decoration: _inputDecoration(hint: 'Parlez de vous...'),
                        ),
                      ),
                      const SizedBox(height: 14),
                      // Location (City + Region)
                      _buildField(
                        label: 'Localisation',
                        child: Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                value: _selectedRegion,
                                isExpanded: true,
                                dropdownColor: AppColors.bgCard,
                                style: TextStyle(color: AppColors.textPrimary, fontSize: 14),
                                decoration: _inputDecoration(hint: 'Région'),
                                items: _regions.map((r) => DropdownMenuItem(
                                  value: r,
                                  child: Text(r, style: const TextStyle(fontSize: 13)),
                                )).toList(),
                                onChanged: (v) => setState(() {
                                  _selectedRegion = v;
                                  _selectedCity = null;
                                }),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                value: _selectedCity,
                                isExpanded: true,
                                dropdownColor: AppColors.bgCard,
                                style: TextStyle(color: AppColors.textPrimary, fontSize: 14),
                                decoration: _inputDecoration(hint: 'Ville'),
                                items: _cities.map((c) => DropdownMenuItem(
                                  value: c,
                                  child: Text(c, style: const TextStyle(fontSize: 13)),
                                )).toList(),
                                onChanged: (v) => setState(() => _selectedCity = v),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  // ═══ PHONE SECTION ═══
                  _buildSection(
                    icon: Icons.phone,
                    title: 'Téléphone',
                    children: [
                      _buildField(
                        label: 'Numéro de téléphone',
                        hint: 'Pour changer votre numéro, contactez le support.',
                        child: TextFormField(
                          initialValue: user?.phoneNumber ?? '',
                          readOnly: true,
                          style: TextStyle(color: AppColors.textMuted, fontSize: 14),
                          decoration: _inputDecoration(
                            hint: '+221 ...',
                            prefixIcon: Icons.phone_outlined,
                          ).copyWith(
                            filled: true,
                            fillColor: AppColors.bgElevated.withValues(alpha: 0.5),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ═══ HELPERS ═══

  Widget _coverPlaceholder() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1E1B4B), Color(0xFF312E81), Color(0xFF1E1B4B)],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.add_photo_alternate,
                color: Colors.white.withValues(alpha: 0.4), size: 36),
            const SizedBox(height: 4),
            Text('Ajouter une bannière',
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.4), fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Widget _avatarFallback(String? name) {
    return Container(
      width: 80, height: 80,
      color: AppColors.bgElevated,
      child: Center(
        child: Text(
          (name ?? 'U')[0].toUpperCase(),
          style: const TextStyle(
              color: AppColors.accent, fontSize: 32, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }

  Widget _buildSection({
    required IconData icon,
    required String title,
    required List<Widget> children,
  }) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.accent, size: 20),
              const SizedBox(width: 8),
              Text(title,
                  style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 18),
          ...children,
        ],
      ),
    );
  }

  Widget _buildField({
    required String label,
    String? hint,
    required Widget child,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w500)),
        const SizedBox(height: 6),
        child,
        if (hint != null) ...[
          const SizedBox(height: 4),
          Text(hint, style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
        ],
      ],
    );
  }

  InputDecoration _inputDecoration({
    String? hint,
    IconData? prefixIcon,
    String? prefixText,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: AppColors.textMuted.withValues(alpha: 0.6), fontSize: 13),
      prefixIcon: prefixIcon != null
          ? Icon(prefixIcon, color: AppColors.textMuted, size: 20)
          : null,
      prefixText: prefixText,
      prefixStyle: TextStyle(color: AppColors.textMuted, fontSize: 14, fontWeight: FontWeight.w600),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      filled: true,
      fillColor: AppColors.bgInput,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: AppColors.accent, width: 1.5),
      ),
    );
  }
}
