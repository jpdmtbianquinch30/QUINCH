import 'api_service.dart';

class NegotiationService {
  final ApiService _api;

  NegotiationService(this._api);

  Future<List<dynamic>> getNegotiations() async {
    final response = await _api.get('/negotiations');
    return response.data['negotiations'] ?? response.data['data'] ?? [];
  }

  Future<Map<String, dynamic>> propose({
    required String productId,
    required double proposedPrice,
    String? message,
  }) async {
    final response = await _api.post('/negotiations/propose', data: {
      'product_id': productId,
      'proposed_price': proposedPrice,
      if (message != null) 'message': message,
    });
    return response.data;
  }

  Future<Map<String, dynamic>> respond({
    required String negotiationId,
    required String action,
    double? counterPrice,
  }) async {
    final response =
        await _api.post('/negotiations/$negotiationId/respond', data: {
      'action': action,
      if (counterPrice != null) 'counter_price': counterPrice,
    });
    return response.data;
  }
}
