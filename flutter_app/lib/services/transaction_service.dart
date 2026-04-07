import '../models/transaction.dart';
import 'api_service.dart';

class TransactionService {
  final ApiService _api;

  TransactionService(this._api);

  Future<Transaction> initiate({
    required String productId,
    required String paymentMethod,
    required String deliveryType,
    Map<String, dynamic>? deliveryAddress,
  }) async {
    final response = await _api.post('/transactions/initiate', data: {
      'product_id': productId,
      'payment_method': paymentMethod,
      'delivery_type': deliveryType,
      if (deliveryAddress != null) 'delivery_address': deliveryAddress,
    });
    return Transaction.fromJson(
        response.data['transaction'] ?? response.data);
  }

  Future<Transaction> confirm(String transactionId) async {
    final response =
        await _api.post('/transactions/$transactionId/confirm');
    return Transaction.fromJson(
        response.data['transaction'] ?? response.data);
  }

  Future<List<Transaction>> getTransactions({int page = 1}) async {
    final response = await _api
        .get('/transactions/history', queryParameters: {'page': page});
    final list = response.data['data'] ?? response.data['transactions'] ?? [];
    return (list as List).map((e) => Transaction.fromJson(e)).toList();
  }

  Future<Map<String, dynamic>> getHistory({int page = 1}) async {
    final response = await _api
        .get('/transactions/history', queryParameters: {'page': page});
    return response.data;
  }

  Future<Transaction> getTransaction(String id) async {
    final response = await _api.get('/transactions/$id');
    return Transaction.fromJson(
        response.data['transaction'] ?? response.data);
  }

  Future<void> updateStatus(String id, String status) async {
    await _api.put('/transactions/$id/status', data: {'status': status});
  }

  Future<void> dispute(String id, String reason) async {
    await _api.post('/transactions/$id/dispute', data: {'reason': reason});
  }
}
