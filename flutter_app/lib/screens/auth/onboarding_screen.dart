import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/product_service.dart';
import '../../services/user_service.dart';
import '../../models/category.dart';
import '../../config/theme.dart';
import '../../widgets/quinch_logo.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with SingleTickerProviderStateMixin {
  int _step = 0;
  List<Category> _categories = [];
  final Set<String> _selectedCategories = {};
  final Set<String> _selectedInterests = {};
  String _selectedRegion = '';
  String _selectedCity = '';
  bool _loading = false;

  late AnimationController _fadeController;
  late Animation<double> _fadeAnim;

  // ═══════════════════════════════════════════════════════
  //  SÉNÉGAL : 14 régions → villes par région
  // ═══════════════════════════════════════════════════════
  static const Map<String, List<String>> _regionCities = {
    'Dakar': [
      'Dakar Plateau', 'Médina', 'Grand Dakar', 'Parcelles Assainies',
      'Guédiawaye', 'Pikine', 'Rufisque', 'Bargny', 'Diamniadio',
      'Sébikhotane', 'Keur Massar', 'Sangalkam', 'Yoff', 'Ngor',
      'Ouakam', 'Mermoz', 'Almadies', 'Gorée',
    ],
    'Thiès': [
      'Thiès', 'Mbour', 'Saly', 'Somone', 'Tivaouane',
      'Joal-Fadiouth', 'Kayar', 'Pout', 'Mboro', 'Nguekhokh',
      'Sindia', 'Popenguine', 'La Petite Côte',
    ],
    'Diourbel': [
      'Diourbel', 'Touba', 'Mbacké', 'Bambey', 'Dinguiraye',
      'Ndame', 'Lambaye',
    ],
    'Saint-Louis': [
      'Saint-Louis', 'Richard-Toll', 'Dagana', 'Podor', 'Ross-Béthio',
      'Gandon', 'Mpal', 'Thilogne',
    ],
    'Kaolack': [
      'Kaolack', 'Nioro du Rip', 'Guinguinéo', 'Ndoffane',
      'Keur Madiabel', 'Gandiaye', 'Sibassor',
    ],
    'Fatick': [
      'Fatick', 'Foundiougne', 'Sokone', 'Gossas', 'Diofior',
      'Passy', 'Toubacouta', 'Djilor',
    ],
    'Ziguinchor': [
      'Ziguinchor', 'Bignona', 'Oussouye', 'Cap Skirring',
      'Diouloulou', 'Thionk Essyl', 'Kafountine',
    ],
    'Kolda': [
      'Kolda', 'Vélingara', 'Médina Yoro Foulah', 'Dabo',
      'Salikégné', 'Kounkané',
    ],
    'Tambacounda': [
      'Tambacounda', 'Bakel', 'Kidira', 'Goudiry',
      'Koumpentoum', 'Missirah', 'Diankhe Makha',
    ],
    'Kédougou': [
      'Kédougou', 'Saraya', 'Salémata', 'Bandafassi',
      'Dindefelo', 'Fongolembi',
    ],
    'Louga': [
      'Louga', 'Linguère', 'Kébémer', 'Dahra',
      'Sakal', 'Coki', 'Ndande',
    ],
    'Matam': [
      'Matam', 'Kanel', 'Ranérou', 'Ourossogui',
      'Thilogne', 'Waoundé', 'Semme',
    ],
    'Kaffrine': [
      'Kaffrine', 'Koungheul', 'Birkelane', 'Malem Hodar',
      'Nganda', 'Diamagadio',
    ],
    'Sédhiou': [
      'Sédhiou', 'Bounkiling', 'Goudomp', 'Marsassoum',
      'Diattacounda', 'Tanaff',
    ],
  };

  // ═══════════════════════════════════════════════════════
  //  CENTRES D'INTÉRÊT (en plus des catégories du backend)
  // ═══════════════════════════════════════════════════════
  static const List<Map<String, dynamic>> _defaultInterests = [
    {'id': 'electronics', 'name': 'Électronique & Tech', 'icon': Icons.devices},
    {'id': 'phones', 'name': 'Téléphones & Tablettes', 'icon': Icons.smartphone},
    {'id': 'fashion_men', 'name': 'Mode Homme', 'icon': Icons.checkroom},
    {'id': 'fashion_women', 'name': 'Mode Femme', 'icon': Icons.dry_cleaning},
    {'id': 'shoes', 'name': 'Chaussures', 'icon': Icons.ice_skating},
    {'id': 'bags', 'name': 'Sacs & Accessoires', 'icon': Icons.shopping_bag},
    {'id': 'beauty', 'name': 'Beauté & Cosmétiques', 'icon': Icons.face_retouching_natural},
    {'id': 'jewelry', 'name': 'Bijoux & Montres', 'icon': Icons.watch},
    {'id': 'home', 'name': 'Maison & Décoration', 'icon': Icons.home},
    {'id': 'furniture', 'name': 'Meubles', 'icon': Icons.chair},
    {'id': 'appliances', 'name': 'Électroménager', 'icon': Icons.kitchen},
    {'id': 'auto', 'name': 'Auto & Moto', 'icon': Icons.directions_car},
    {'id': 'sports', 'name': 'Sports & Loisirs', 'icon': Icons.sports_soccer},
    {'id': 'health', 'name': 'Santé & Bien-être', 'icon': Icons.health_and_safety},
    {'id': 'food', 'name': 'Alimentation & Boissons', 'icon': Icons.restaurant},
    {'id': 'books', 'name': 'Livres & Éducation', 'icon': Icons.menu_book},
    {'id': 'kids', 'name': 'Enfants & Bébés', 'icon': Icons.child_care},
    {'id': 'gaming', 'name': 'Jeux Vidéo & Consoles', 'icon': Icons.sports_esports},
    {'id': 'music', 'name': 'Musique & Instruments', 'icon': Icons.music_note},
    {'id': 'photo', 'name': 'Photo & Vidéo', 'icon': Icons.camera_alt},
    {'id': 'agriculture', 'name': 'Agriculture & Élevage', 'icon': Icons.grass},
    {'id': 'construction', 'name': 'BTP & Matériaux', 'icon': Icons.construction},
    {'id': 'services', 'name': 'Services & Freelance', 'icon': Icons.handyman},
    {'id': 'immobilier', 'name': 'Immobilier', 'icon': Icons.apartment},
    {'id': 'artisanat', 'name': 'Artisanat Local', 'icon': Icons.palette},
    {'id': 'textile', 'name': 'Tissus & Couture', 'icon': Icons.cut},
    {'id': 'event', 'name': 'Événementiel', 'icon': Icons.celebration},
    {'id': 'transport', 'name': 'Transport & Logistique', 'icon': Icons.local_shipping},
  ];

  List<String> get _availableCities =>
      _regionCities[_selectedRegion] ?? [];

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fadeAnim = CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut);
    _fadeController.forward();
    _loadCategories();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    try {
      final productService = context.read<ProductService>();
      _categories = await productService.getCategories();
      setState(() {});
    } catch (_) {}
  }

  void _nextStep() {
    _fadeController.reverse().then((_) {
      setState(() => _step++);
      _fadeController.forward();
    });
  }

  void _prevStep() {
    _fadeController.reverse().then((_) {
      setState(() => _step--);
      _fadeController.forward();
    });
  }

  Future<void> _finish() async {
    setState(() => _loading = true);
    try {
      final userService = context.read<UserService>();
      await userService.savePreferences({
        'categories': [
          ..._selectedCategories.toList(),
          ..._selectedInterests.toList(),
        ],
        'location': {
          'city': _selectedCity,
          'region': _selectedRegion,
        },
      });

      final user = await userService.updateProfile(
        location: _selectedCity,
        extra: {
          'city': _selectedCity,
          'region': _selectedRegion,
        },
      );

      if (mounted) {
        context.read<AuthProvider>().updateUser(user);
        context.go('/feed');
      }
    } catch (_) {
      if (mounted) context.go('/feed');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      body: SafeArea(
        child: Column(
          children: [
            // ═══ PROGRESS BAR ═══
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: List.generate(3, (i) => Expanded(
                      child: Container(
                        height: 4,
                        margin: EdgeInsets.only(right: i < 2 ? 6 : 0),
                        decoration: BoxDecoration(
                          color: i <= _step ? AppColors.accent : AppColors.bgCard,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    )),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Étape ${_step + 1}/3',
                    style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                  ),
                ],
              ),
            ),

            // ═══ CONTENT ═══
            Expanded(
              child: FadeTransition(
                opacity: _fadeAnim,
                child: _step == 0
                    ? _buildWelcome()
                    : _step == 1
                        ? _buildInterests()
                        : _buildLocation(),
              ),
            ),

            // ═══ NAVIGATION ═══
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
              child: Row(
                children: [
                  if (_step > 0)
                    SizedBox(
                      height: 48,
                      child: OutlinedButton.icon(
                        onPressed: _prevStep,
                        icon: const Icon(Icons.arrow_back, size: 16),
                        label: const Text('Retour'),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: AppColors.border),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  const Spacer(),
                  if (_step == 0)
                    TextButton(
                      onPressed: () => context.go('/feed'),
                      child: Text('Passer', style: TextStyle(color: AppColors.textMuted)),
                    ),
                  const SizedBox(width: 8),
                  SizedBox(
                    height: 48,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: _step == 2
                            ? const LinearGradient(colors: [AppColors.success, Color(0xFF34D399)])
                            : AppColors.primaryGradient,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [BoxShadow(
                          color: (_step == 2 ? AppColors.success : AppColors.accent).withValues(alpha: 0.3),
                          blurRadius: 12, offset: const Offset(0, 4),
                        )],
                      ),
                      child: ElevatedButton.icon(
                        onPressed: _loading
                            ? null
                            : () {
                                if (_step < 2) {
                                  _nextStep();
                                } else {
                                  _finish();
                                }
                              },
                        icon: _loading
                            ? const SizedBox(width: 18, height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : Icon(_step == 2 ? Icons.check : Icons.arrow_forward, size: 18, color: Colors.white),
                        label: Text(
                          _step == 2 ? 'Commencer' : 'Suivant',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  //  STEP 0: BIENVENUE
  // ═══════════════════════════════════════════════════════
  Widget _buildWelcome() {
    final user = context.read<AuthProvider>().user;
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const QuinchLogo(size: 80),
          const SizedBox(height: 28),
          Text(
            'Bienvenue ${user?.fullName ?? ''} !',
            style: TextStyle(
              fontSize: 26, fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            'Personnalisons votre expérience QUINCH\npour vous proposer les meilleurs produits\net services près de chez vous.',
            style: TextStyle(fontSize: 15, color: AppColors.textSecondary, height: 1.5),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          // Features
          _WelcomeFeature(
            icon: Icons.interests, color: AppColors.accent,
            title: 'Centres d\'intérêt',
            subtitle: 'Choisissez ce qui vous plaît',
          ),
          const SizedBox(height: 12),
          _WelcomeFeature(
            icon: Icons.location_on, color: AppColors.secondary,
            title: 'Localisation',
            subtitle: 'Trouvez des offres près de vous',
          ),
          const SizedBox(height: 12),
          _WelcomeFeature(
            icon: Icons.rocket_launch, color: AppColors.warning,
            title: 'C\'est parti !',
            subtitle: 'Découvrez QUINCH en 30 secondes',
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  //  STEP 1: CENTRES D'INTÉRÊT
  // ═══════════════════════════════════════════════════════
  Widget _buildInterests() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          Text(
            'Vos centres d\'intérêt',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 6),
          Text(
            'Sélectionnez au moins 3 catégories (${_selectedInterests.length + _selectedCategories.length} sélectionnées)',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Backend categories first (if loaded)
                  if (_categories.isNotEmpty) ...[
                    Text('CATÉGORIES',
                      style: TextStyle(color: AppColors.textMuted, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 1)),
                    const SizedBox(height: 10),
                    Wrap(spacing: 8, runSpacing: 8, children: _categories.map((cat) {
                      final selected = _selectedCategories.contains(cat.id);
                      return _InterestChip(
                        label: cat.name,
                        icon: _iconForCategory(cat.name),
                        selected: selected,
                        onTap: () => setState(() {
                          selected ? _selectedCategories.remove(cat.id) : _selectedCategories.add(cat.id);
                        }),
                      );
                    }).toList()),
                    const SizedBox(height: 20),
                  ],

                  // Default rich interests
                  Text('PLUS D\'INTÉRÊTS',
                    style: TextStyle(color: AppColors.textMuted, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 1)),
                  const SizedBox(height: 10),
                  Wrap(spacing: 8, runSpacing: 8, children: _defaultInterests.map((item) {
                    final selected = _selectedInterests.contains(item['id']);
                    return _InterestChip(
                      label: item['name'] as String,
                      icon: item['icon'] as IconData,
                      selected: selected,
                      onTap: () => setState(() {
                        selected ? _selectedInterests.remove(item['id']) : _selectedInterests.add(item['id'] as String);
                      }),
                    );
                  }).toList()),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  //  STEP 2: LOCALISATION
  // ═══════════════════════════════════════════════════════
  Widget _buildLocation() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          Text(
            'Votre localisation',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 6),
          Text(
            'Pour vous proposer des offres près de chez vous',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 24),

          // Region
          Text('Région', style: TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            decoration: InputDecoration(
              hintText: 'Sélectionnez votre région',
              prefixIcon: Icon(Icons.map_outlined, color: AppColors.textMuted, size: 20),
            ),
            value: _selectedRegion.isEmpty ? null : _selectedRegion,
            dropdownColor: AppColors.bgElevated,
            style: TextStyle(color: AppColors.textPrimary, fontSize: 14),
            items: _regionCities.keys
                .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                .toList(),
            onChanged: (v) {
              setState(() {
                _selectedRegion = v ?? '';
                _selectedCity = ''; // Reset city when region changes
              });
            },
          ),

          const SizedBox(height: 20),

          // City (depends on region)
          Text('Ville', style: TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            decoration: InputDecoration(
              hintText: _selectedRegion.isEmpty
                  ? 'Choisissez d\'abord une région'
                  : 'Sélectionnez votre ville',
              prefixIcon: Icon(Icons.location_city_outlined, color: AppColors.textMuted, size: 20),
            ),
            value: _selectedCity.isEmpty ? null : _selectedCity,
            dropdownColor: AppColors.bgElevated,
            style: TextStyle(color: AppColors.textPrimary, fontSize: 14),
            items: _availableCities
                .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                .toList(),
            onChanged: _selectedRegion.isEmpty
                ? null
                : (v) => setState(() => _selectedCity = v ?? ''),
          ),

          const SizedBox(height: 24),

          // Map preview / info
          if (_selectedRegion.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.accentSubtle,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.accent.withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.accent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.location_on, color: AppColors.accent, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _selectedCity.isNotEmpty
                              ? '$_selectedCity, $_selectedRegion'
                              : 'Région de $_selectedRegion',
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          '${_availableCities.length} villes disponibles',
                          style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.check_circle, color: AppColors.success, size: 20),
                ],
              ),
            ),
        ],
      ),
    );
  }

  IconData _iconForCategory(String name) {
    final n = name.toLowerCase();
    if (n.contains('electr') || n.contains('tech')) return Icons.devices;
    if (n.contains('mode') || n.contains('vêt')) return Icons.checkroom;
    if (n.contains('maison') || n.contains('déco')) return Icons.home;
    if (n.contains('sport')) return Icons.sports_soccer;
    if (n.contains('auto') || n.contains('moto')) return Icons.directions_car;
    if (n.contains('alim') || n.contains('nourr')) return Icons.restaurant;
    if (n.contains('beauté')) return Icons.face;
    if (n.contains('service')) return Icons.handyman;
    if (n.contains('immob')) return Icons.apartment;
    return Icons.category;
  }
}

class _WelcomeFeature extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  const _WelcomeFeature({
    required this.icon, required this.color,
    required this.title, required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 14)),
                Text(subtitle, style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
              ],
            ),
          ),
          Icon(Icons.chevron_right, color: AppColors.textMuted, size: 18),
        ],
      ),
    );
  }
}

class _InterestChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  const _InterestChip({
    required this.label, required this.icon,
    required this.selected, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.accent.withValues(alpha: 0.15)
              : AppColors.bgCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected
                ? AppColors.accent.withValues(alpha: 0.5)
                : AppColors.border,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              selected ? Icons.check_circle : icon,
              size: 16,
              color: selected ? AppColors.accent : AppColors.textMuted,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: selected ? AppColors.accent : AppColors.textSecondary,
                fontSize: 13,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
