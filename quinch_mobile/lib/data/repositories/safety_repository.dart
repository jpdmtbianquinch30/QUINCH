import '../../core/json/json_utils.dart';
import '../../core/network/api_client.dart';
import '../api/endpoints.dart';
import '../models/user.dart';

/// Signalements, blocage et support. Les valeurs de motif sont celles que le
/// serveur accepte (`in:` dans les contrôleurs) ; toute autre valeur est refusée.
enum ProductReportReason {
  fraud('fraud', 'Fraude ou arnaque'),
  inappropriate('inappropriate', 'Contenu inapproprié'),
  counterfeit('counterfeit', 'Contrefaçon'),
  spam('spam', 'Spam'),
  other('other', 'Autre');

  const ProductReportReason(this.value, this.label);
  final String value;
  final String label;
}

enum UserReportReason {
  harassment('harassment', 'Harcèlement'),
  spam('spam', 'Spam'),
  inappropriateContent('inappropriate_content', 'Contenu inapproprié'),
  fraud('fraud', 'Fraude'),
  impersonation('impersonation', "Usurpation d'identité"),
  other('other', 'Autre');

  const UserReportReason(this.value, this.label);
  final String value;
  final String label;
}

enum SupportCategory {
  bug('bug', 'Un bug'),
  suggestion('suggestion', 'Une suggestion'),
  security('security', 'Un problème de sécurité'),
  other('other', 'Autre');

  const SupportCategory(this.value, this.label);
  final String value;
  final String label;
}

class SafetyRepository {
  SafetyRepository(this._api);

  final ApiClient _api;

  /// Renvoie le message du serveur. 409 si un signalement est déjà en cours.
  Future<String?> reportProduct(
    String productId,
    ProductReportReason reason, {
    String? description,
  }) async {
    final body = await _api.post(
      Endpoints.reportProduct(productId),
      data: <String, Object?>{
        'reason': reason.value,
        if (description != null && description.trim().isNotEmpty)
          'description': description.trim(),
      },
    );
    return asStringOrNull(asMap(body)['message']);
  }

  Future<String?> reportUser(
    String userId,
    UserReportReason reason, {
    String? description,
  }) async {
    final body = await _api.post(
      Endpoints.reportUser(userId),
      data: <String, Object?>{
        'reason': reason.value,
        if (description != null && description.trim().isNotEmpty)
          'description': description.trim(),
      },
    );
    return asStringOrNull(asMap(body)['message']);
  }

  Future<String?> reportProblem(
    SupportCategory category,
    String description,
  ) async {
    final body = await _api.post(
      Endpoints.supportReport,
      data: <String, Object?>{
        'category': category.value,
        'description': description.trim(),
      },
    );
    return asStringOrNull(asMap(body)['message']);
  }

  Future<String?> blockUser(String userId) async {
    final body = await _api.post(Endpoints.blockUser(userId));
    return asStringOrNull(asMap(body)['message']);
  }

  Future<String?> unblockUser(String userId) async {
    final body = await _api.post(Endpoints.unblockUser(userId));
    return asStringOrNull(asMap(body)['message']);
  }

  Future<List<BlockedUser>> blockedUsers() async {
    final body = await _api.get(Endpoints.blockedUsers);
    return BlockedUser.listFromBody(body);
  }
}
