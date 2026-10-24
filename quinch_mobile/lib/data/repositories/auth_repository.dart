import '../../core/json/json_utils.dart';
import '../../core/network/api_client.dart';
import '../api/endpoints.dart';
import '../models/user.dart';

/// Accès aux endpoints d'authentification vérifiés à l'étape 3.
/// Aucun mot de passe n'est conservé : les valeurs ne font que transiter.
class AuthRepository {
  AuthRepository(this._api);

  final ApiClient _api;

  Future<AuthSession> login({
    required String email,
    required String password,
  }) async {
    final body = await _api.post(
      Endpoints.login,
      data: <String, Object?>{'email': email, 'password': password},
    );
    return AuthSession.fromJson(body);
  }

  Future<AuthSession> register({
    required String email,
    required String fullName,
    required String username,
    required String password,
    required String passwordConfirmation,
  }) async {
    final body = await _api.post(
      Endpoints.register,
      data: <String, Object?>{
        'email': email,
        'full_name': fullName,
        'username': username,
        'password': password,
        'password_confirmation': passwordConfirmation,
        'accept_terms': true,
      },
    );
    return AuthSession.fromJson(body);
  }

  Future<AppUser> me() async {
    final body = await _api.get(Endpoints.me);
    return AppUser.fromJson(asMap(asMap(body)['user']));
  }

  /// `POST auth/refresh` : le serveur remplace le jeton courant.
  Future<AuthSession> refresh() async {
    final body = await _api.post(Endpoints.refresh);
    return AuthSession.fromJson(body);
  }

  Future<void> logout() async {
    await _api.post(Endpoints.logout);
  }

  /// Renvoie le message du serveur (identique que le compte existe ou non).
  Future<String?> requestPasswordReset(String email) async {
    final body = await _api.post(
      Endpoints.forgotPassword,
      data: <String, Object?>{'email': email},
    );
    return asStringOrNull(asMap(body)['message']);
  }

  Future<String?> resetPassword({
    required String email,
    required String otp,
    required String password,
    required String passwordConfirmation,
  }) async {
    final body = await _api.post(
      Endpoints.resetPassword,
      data: <String, Object?>{
        'email': email,
        'otp': otp,
        'password': password,
        'password_confirmation': passwordConfirmation,
      },
    );
    return asStringOrNull(asMap(body)['message']);
  }

  /// `PUT auth/change-password` : les autres sessions du compte sont révoquées
  /// par le serveur ; celle-ci reste ouverte.
  Future<String?> changePassword({
    required String currentPassword,
    required String newPassword,
    required String confirmation,
  }) async {
    final body = await _api.put(
      Endpoints.changePassword,
      data: <String, Object?>{
        'current_password': currentPassword,
        'new_password': newPassword,
        'new_password_confirmation': confirmation,
      },
    );
    return asStringOrNull(asMap(body)['message']);
  }

  /// `POST auth/delete-account` : anonymisation du compte, mot de passe exigé.
  Future<String?> deleteAccount(String password) async {
    final body = await _api.post(
      Endpoints.deleteAccount,
      data: <String, Object?>{'password': password},
    );
    return asStringOrNull(asMap(body)['message']);
  }
}
