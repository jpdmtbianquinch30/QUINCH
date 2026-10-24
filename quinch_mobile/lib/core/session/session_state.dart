import '../../data/models/user.dart';
import '../network/api_error.dart';

/// Pourquoi on se retrouve sans session (affiché sur l'écran de connexion).
enum SessionEndReason {
  none,
  loggedOut,
  expired,
  accountBanned,
  accountSuspended,
  accountDeleted,
}

extension SessionEndReasonMessage on SessionEndReason {
  String? get message => switch (this) {
    SessionEndReason.none => null,
    SessionEndReason.loggedOut => 'Vous avez été déconnecté.',
    SessionEndReason.expired => 'Votre session a expiré. Reconnectez-vous.',
    SessionEndReason.accountBanned => 'Ce compte a été banni.',
    SessionEndReason.accountSuspended => 'Ce compte est suspendu.',
    SessionEndReason.accountDeleted => 'Votre compte a été supprimé.',
  };
}

sealed class SessionState {
  const SessionState();
}

/// Démarrage : lecture du jeton et vérification auprès du serveur.
final class SessionStarting extends SessionState {
  const SessionStarting();
}

final class SessionAuthenticated extends SessionState {
  const SessionAuthenticated(this.user);

  final AppUser user;
}

final class SessionUnauthenticated extends SessionState {
  const SessionUnauthenticated([this.reason = SessionEndReason.none]);

  final SessionEndReason reason;
}

/// Jeton présent mais serveur injoignable ou en erreur : on ne déconnecte pas
/// l'utilisateur pour une panne passagère ; l'écran propose de réessayer.
final class SessionUnavailable extends SessionState {
  const SessionUnavailable(this.error);

  final ApiError error;
}
