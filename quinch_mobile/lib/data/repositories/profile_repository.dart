import '../../core/json/json_utils.dart';
import '../../core/network/api_client.dart';
import '../api/endpoints.dart';
import '../models/paginated.dart';
import '../models/product.dart';
import '../models/user.dart';

/// Profil de l'utilisateur connecté, profils publics et abonnements.
class ProfileRepository {
  ProfileRepository(this._api);

  final ApiClient _api;

  /// `GET user/profile` : modèle utilisateur complet (bio, site, ville, région…).
  Future<AppUser> myProfile() async {
    final body = await _api.get(Endpoints.userProfile);
    return AppUser.fromJson(asMap(asMap(body)['user']));
  }

  /// `PUT user/profile` : seuls les champs renseignés sont envoyés. Changer
  /// l'email exige le mot de passe actuel (vérifié par le serveur).
  Future<AppUser> updateProfile({
    String? fullName,
    String? username,
    String? email,
    String? bio,
    String? website,
    String? city,
    String? region,
    String? currentPassword,
  }) async {
    final data = <String, Object?>{
      if (fullName != null) 'full_name': fullName,
      if (username != null) 'username': username,
      if (email != null) 'email': email,
      if (bio != null) 'bio': bio,
      if (website != null) 'website': website,
      if (city != null) 'city': city,
      if (region != null) 'region': region,
      if (currentPassword != null) 'current_password': currentPassword,
    };
    final body = await _api.put(Endpoints.userProfile, data: data);
    return AppUser.fromJson(asMap(asMap(body)['user']));
  }

  /// `PUT user/phone` : `+221` suivi de 9 chiffres, ou null pour supprimer.
  Future<AppUser> updatePhone(String? phoneNumber) async {
    final body = await _api.put(
      Endpoints.userPhone,
      data: <String, Object?>{'phone_number': phoneNumber},
    );
    return AppUser.fromJson(asMap(asMap(body)['user']));
  }

  Future<PublicProfile> publicProfile(String username) async {
    final body = await _api.get(Endpoints.publicProfile(username));
    return PublicProfile.fromJson(body);
  }

  /// Annonces actives d'un vendeur (12 par page par défaut).
  Future<Paginated<ProductCard>> sellerProducts(
    String username, {
    int page = 1,
  }) async {
    final body = await _api.get(
      Endpoints.sellerProducts(username),
      query: <String, Object?>{'page': page},
    );
    return Paginated<ProductCard>.fromJson(body, ProductCard.fromJson);
  }

  Future<FollowResult> follow(String userId) async {
    final body = await _api.post(Endpoints.follow(userId));
    return FollowResult.fromJson(body);
  }

  Future<FollowResult> unfollow(String userId) async {
    final body = await _api.delete(Endpoints.unfollow(userId));
    return FollowResult.fromJson(body);
  }
}
