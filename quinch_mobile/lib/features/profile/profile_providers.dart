import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../data/models/paginated.dart';
import '../../data/models/product.dart';
import '../../data/models/user.dart';
import '../../data/repositories/profile_repository.dart';
import '../../data/repositories/safety_repository.dart';
import '../../shared/paging/paged_notifier.dart';
import '../product/product_providers.dart';

final profileRepositoryProvider = Provider<ProfileRepository>(
  (ref) => ProfileRepository(ref.watch(apiClientProvider)),
);

final safetyRepositoryProvider = Provider<SafetyRepository>(
  (ref) => SafetyRepository(ref.watch(apiClientProvider)),
);

/// Profil complet de l'utilisateur connecté (pour le formulaire de modification).
final myProfileProvider = FutureProvider.autoDispose<AppUser>(
  (ref) => ref.watch(profileRepositoryProvider).myProfile(),
);

final publicProfileProvider = FutureProvider.autoDispose
    .family<PublicProfile, String>(
      (ref, username) =>
          ref.watch(profileRepositoryProvider).publicProfile(username),
    );

class SellerProductsController
    extends PagedFamilyNotifier<ProductCard, String> {
  @override
  Future<Paginated<ProductCard>> fetchPage(int page) =>
      ref.read(profileRepositoryProvider).sellerProducts(arg, page: page);
}

final sellerProductsProvider = NotifierProvider.autoDispose
    .family<SellerProductsController, PagedState<ProductCard>, String>(
      SellerProductsController.new,
    );

class MyProductsController extends PagedNotifier<ProductCard> {
  @override
  Future<Paginated<ProductCard>> fetchPage(int page) =>
      ref.read(productRepositoryProvider).myProducts(page: page);

  /// Supprime l'annonce côté serveur puis la retire de la liste.
  Future<void> delete(String productId) async {
    await ref.read(productRepositoryProvider).deleteProduct(productId);
    removeWhere((card) => card.id == productId);
  }
}

final myProductsProvider =
    NotifierProvider<MyProductsController, PagedState<ProductCard>>(
      MyProductsController.new,
    );

final blockedUsersProvider = FutureProvider.autoDispose<List<BlockedUser>>(
  (ref) => ref.watch(safetyRepositoryProvider).blockedUsers(),
);
