import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../data/models/legal.dart';
import '../../data/repositories/legal_repository.dart';

final legalRepositoryProvider = Provider<LegalRepository>(
  (ref) => LegalRepository(ref.watch(apiClientProvider)),
);

/// Informations de l'éditeur, relues à chaque ouverture d'un texte juridique.
final legalInfoProvider = FutureProvider.autoDispose<LegalInfo>(
  (ref) => ref.watch(legalRepositoryProvider).info(),
);
