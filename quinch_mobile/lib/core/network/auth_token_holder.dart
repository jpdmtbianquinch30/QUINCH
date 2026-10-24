/// Jeton d'authentification en mémoire, lu de façon synchrone par l'intercepteur.
/// La persistance est assurée par `TokenStorage` ; la session met ce holder à jour.
class AuthTokenHolder {
  String? token;
}
