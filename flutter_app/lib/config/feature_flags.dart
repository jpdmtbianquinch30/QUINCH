/// Feature flags V1 — doivent rester synchronisés avec
/// `backend/config/quinch.php`. Le serveur reste la source de vérité (ces
/// routes renvoient 404 côté API si désactivées) : ces flags ici servent
/// uniquement à masquer les boutons/écrans correspondants dans l'UI pour ne
/// pas qu'un utilisateur tombe sur une erreur en cliquant sur une
/// fonctionnalité non disponible en V1.
class FeatureFlags {
  static const bool negotiation = false;
  static const bool follow = false;
  static const bool reviews = false;
  static const bool badges = false;
  static const bool sharing = false;
  static const bool chatAudio = false;
  static const bool chatFile = false;
  static const bool favoritesCollections = false;

  /// Doit rester synchronisé avec QUINCH_PAYMENT_METHODS / config/quinch.php
  /// côté backend. V1 : uniquement le paiement à la livraison.
  static const List<String> enabledPaymentMethods = ['cash_delivery'];
}
