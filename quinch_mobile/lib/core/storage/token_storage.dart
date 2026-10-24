import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Stockage persistant du jeton. Seuls le jeton et sa date d'émission sont
/// conservés : aucun mot de passe, aucun profil, aucune donnée personnelle.
abstract interface class TokenStorage {
  Future<String?> readToken();
  Future<DateTime?> readIssuedAt();
  Future<void> writeToken(String token, {required DateTime issuedAt});
  Future<void> clear();
}

/// Implémentation Android : Keystore via flutter_secure_storage.
class SecureTokenStorage implements TokenStorage {
  SecureTokenStorage([FlutterSecureStorage? storage])
    : _storage =
          storage ??
          const FlutterSecureStorage(
            aOptions: AndroidOptions(encryptedSharedPreferences: true),
          );

  final FlutterSecureStorage _storage;

  static const _tokenKey = 'quinch.auth.token';
  static const _issuedAtKey = 'quinch.auth.issued_at';

  @override
  Future<String?> readToken() async {
    try {
      final value = await _storage.read(key: _tokenKey);
      return (value == null || value.isEmpty) ? null : value;
    } on Exception {
      // Stockage illisible (clé Keystore invalidée, restauration de sauvegarde…).
      // On repart d'une session vide plutôt que de bloquer l'application.
      await clear();
      return null;
    }
  }

  @override
  Future<DateTime?> readIssuedAt() async {
    try {
      final value = await _storage.read(key: _issuedAtKey);
      return value == null ? null : DateTime.tryParse(value);
    } on Exception {
      return null;
    }
  }

  @override
  Future<void> writeToken(String token, {required DateTime issuedAt}) async {
    await _storage.write(key: _tokenKey, value: token);
    await _storage.write(
      key: _issuedAtKey,
      value: issuedAt.toUtc().toIso8601String(),
    );
  }

  @override
  Future<void> clear() async {
    try {
      await _storage.delete(key: _tokenKey);
      await _storage.delete(key: _issuedAtKey);
    } on Exception {
      // Rien de plus à faire : le jeton en mémoire est déjà oublié par l'appelant.
    }
  }
}
