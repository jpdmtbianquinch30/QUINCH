import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/premium.dart';
import '../premium/premium_providers.dart';

/// Configuration publique du serveur (bêta, frais de publication avec vidéo).
/// Sert seulement à informer : c'est le serveur qui décide des frais dus.
final publicConfigProvider = FutureProvider.autoDispose<PublicConfig>(
  (ref) => ref.watch(premiumRepositoryProvider).config(),
);
