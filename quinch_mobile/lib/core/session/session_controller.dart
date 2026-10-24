import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/user.dart';
import '../network/api_error.dart';
import '../providers.dart';
import 'session_state.dart';

/// Gère la session : restauration, connexion, inscription, déconnexion,
/// expiration. Source de vérité = le serveur (`auth/me`).
class SessionController extends Notifier<SessionState> {
  /// Même seuil qu'Angular (`tokenRefreshThresholdMinutes: 10080`, soit 7 jours).
  static const refreshThreshold = Duration(minutes: 10080);

  @override
  SessionState build() => const SessionStarting();

  /// Appelé une fois au lancement de l'application.
  Future<void> start() async {
    state = const SessionStarting();
    final storage = ref.read(tokenStorageProvider);
    final token = await storage.readToken();
    if (token == null) {
      state = const SessionUnauthenticated();
      return;
    }
    ref.read(authTokenHolderProvider).token = token;
    try {
      final repo = ref.read(authRepositoryProvider);
      var user = await repo.me();
      user = await _refreshIfDue(user);
      state = SessionAuthenticated(user);
    } on ApiError catch (e) {
      if (state is SessionUnauthenticated) {
        return; // déjà traité par le client HTTP
      }
      if (_endsSession(e)) {
        await _endSession(_reasonFor(e));
      } else {
        state = SessionUnavailable(e);
      }
    }
  }

  Future<void> login({required String email, required String password}) async {
    final session = await ref
        .read(authRepositoryProvider)
        .login(email: email, password: password);
    await _establish(session);
  }

  Future<void> register({
    required String email,
    required String fullName,
    required String username,
    required String password,
    required String passwordConfirmation,
  }) async {
    final session = await ref
        .read(authRepositoryProvider)
        .register(
          email: email,
          fullName: fullName,
          username: username,
          password: password,
          passwordConfirmation: passwordConfirmation,
        );
    await _establish(session);
  }

  /// Déconnexion : le jeton local est effacé même si l'appel serveur échoue.
  Future<void> logout() async {
    try {
      await ref.read(authRepositoryProvider).logout();
    } on ApiError {
      // Meilleur effort : la session locale est fermée dans tous les cas.
    }
    await _endSession(SessionEndReason.loggedOut);
  }

  /// Ferme la session localement sans appeler le serveur (ex. compte supprimé).
  Future<void> closeLocally(SessionEndReason reason) => _endSession(reason);

  /// Appelé par le client HTTP quand le serveur invalide la session.
  void handleSessionInvalid(ApiError error) {
    if (state is SessionUnauthenticated) return;
    unawaited(_endSession(_reasonFor(error)));
  }

  /// Relit l'utilisateur auprès du serveur (ex. après un changement de statut Premium).
  /// Une panne réseau laisse l'utilisateur affiché tel quel.
  Future<void> refreshUser() async {
    if (state is! SessionAuthenticated) {
      return;
    }
    try {
      final user = await ref.read(authRepositoryProvider).me();
      updateUser(user);
    } on ApiError {
      // Les erreurs de session sont déjà traitées par le client HTTP.
    }
  }

  /// Met à jour l'utilisateur affiché (après modification du profil, par exemple).
  void updateUser(AppUser user) {
    if (state is SessionAuthenticated) {
      state = SessionAuthenticated(user);
    }
  }

  Future<void> _establish(AuthSession session) async {
    ref.read(authTokenHolderProvider).token = session.token;
    try {
      await ref
          .read(tokenStorageProvider)
          .writeToken(session.token, issuedAt: ref.read(clockProvider)());
    } on Exception {
      // Écriture impossible : la session reste valable pour cette exécution,
      // mais ne sera pas restaurée au prochain lancement.
    }
    state = SessionAuthenticated(session.user);
  }

  Future<AppUser> _refreshIfDue(AppUser current) async {
    final storage = ref.read(tokenStorageProvider);
    final now = ref.read(clockProvider)();
    final token = ref.read(authTokenHolderProvider).token;
    final issuedAt = await storage.readIssuedAt();
    if (token == null) return current;
    if (issuedAt == null) {
      // Date inconnue : on en pose une maintenant plutôt que de rafraîchir au hasard
      // (même logique qu'Angular).
      await _tryWrite(token, now);
      return current;
    }
    if (now.difference(issuedAt) < refreshThreshold) return current;
    try {
      final refreshed = await ref.read(authRepositoryProvider).refresh();
      ref.read(authTokenHolderProvider).token = refreshed.token;
      await _tryWrite(refreshed.token, now);
      return refreshed.user;
    } on ApiError {
      // Échec silencieux (comme Angular). Une session réellement invalide est
      // gérée par le client HTTP via handleSessionInvalid.
      return current;
    }
  }

  Future<void> _tryWrite(String token, DateTime issuedAt) async {
    try {
      await ref
          .read(tokenStorageProvider)
          .writeToken(token, issuedAt: issuedAt);
    } on Exception {
      // Voir _establish.
    }
  }

  Future<void> _endSession(SessionEndReason reason) async {
    ref.read(authTokenHolderProvider).token = null;
    state = SessionUnauthenticated(reason);
    await ref.read(tokenStorageProvider).clear();
  }

  static bool _endsSession(ApiError e) =>
      e.kind == ApiErrorKind.unauthorized ||
      e.kind == ApiErrorKind.accountBanned ||
      e.kind == ApiErrorKind.accountSuspended;

  static SessionEndReason _reasonFor(ApiError e) => switch (e.kind) {
    ApiErrorKind.accountBanned => SessionEndReason.accountBanned,
    ApiErrorKind.accountSuspended => SessionEndReason.accountSuspended,
    _ => SessionEndReason.expired,
  };
}

final sessionControllerProvider =
    NotifierProvider<SessionController, SessionState>(SessionController.new);
