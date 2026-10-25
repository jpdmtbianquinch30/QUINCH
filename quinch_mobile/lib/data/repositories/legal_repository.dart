import '../../core/network/api_client.dart';
import '../api/endpoints.dart';
import '../models/legal.dart';

/// Informations légales publiques (`GET legal/info`, sans authentification).
class LegalRepository {
  LegalRepository(this._api);

  final ApiClient _api;

  Future<LegalInfo> info() async =>
      LegalInfo.fromJson(await _api.get(Endpoints.legalInfo));
}
