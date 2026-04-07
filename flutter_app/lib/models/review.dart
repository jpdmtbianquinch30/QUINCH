class Review {
  final String id;
  final String sellerId;
  final String reviewerId;
  final int rating;
  final String? comment;
  final String? sellerResponse;
  final ReviewUser? reviewer;
  final String createdAt;

  Review({
    required this.id,
    required this.sellerId,
    required this.reviewerId,
    required this.rating,
    this.comment,
    this.sellerResponse,
    this.reviewer,
    required this.createdAt,
  });

  factory Review.fromJson(Map<String, dynamic> json) {
    return Review(
      id: json['id']?.toString() ?? '',
      sellerId: json['seller_id']?.toString() ?? '',
      reviewerId: json['reviewer_id']?.toString() ?? '',
      rating: json['rating'] ?? 0,
      comment: json['comment'],
      sellerResponse: json['seller_response'],
      reviewer: json['reviewer'] != null
          ? ReviewUser.fromJson(json['reviewer'])
          : null,
      createdAt: json['created_at'] ?? '',
    );
  }
}

class ReviewUser {
  final String id;
  final String? fullName;
  final String? avatarUrl;

  ReviewUser({required this.id, this.fullName, this.avatarUrl});

  factory ReviewUser.fromJson(Map<String, dynamic> json) {
    return ReviewUser(
      id: json['id']?.toString() ?? '',
      fullName: json['full_name'],
      avatarUrl: json['avatar_url'],
    );
  }
}

class ReviewStats {
  final double average;
  final int total;
  final Map<int, int> distribution;

  ReviewStats({
    required this.average,
    required this.total,
    required this.distribution,
  });

  factory ReviewStats.fromJson(Map<String, dynamic> json) {
    final dist = <int, int>{};
    if (json['distribution'] != null) {
      (json['distribution'] as Map<String, dynamic>).forEach((k, v) {
        dist[int.tryParse(k) ?? 0] = v ?? 0;
      });
    }
    return ReviewStats(
      average: (json['average'] ?? 0).toDouble(),
      total: json['total'] ?? 0,
      distribution: dist,
    );
  }
}
