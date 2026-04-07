import 'api_service.dart';

class ReviewService {
  final ApiService _api;

  ReviewService(this._api);

  Future<Map<String, dynamic>> createReview({
    required String sellerId,
    required int rating,
    String? comment,
    String? transactionId,
  }) async {
    final response = await _api.post('/reviews', data: {
      'seller_id': sellerId,
      'rating': rating,
      if (comment != null) 'comment': comment,
      if (transactionId != null) 'transaction_id': transactionId,
    });
    return response.data;
  }

  Future<Map<String, dynamic>> getSellerReviews(String sellerId) async {
    final response = await _api.get('/reviews/seller/$sellerId');
    return response.data is Map<String, dynamic> ? response.data as Map<String, dynamic> : {};
  }

  Future<void> respondToReview(String reviewId, String response) async {
    await _api.post('/reviews/$reviewId/respond', data: {
      'response': response,
    });
  }
}
