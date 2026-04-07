import 'product.dart';

class Transaction {
  final int id;
  final String buyerId;
  final String sellerId;
  final String productId;
  final double amount;
  final String currency;
  final String paymentMethod;
  final String paymentStatus;
  final String? deliveryType;
  final double transactionFee;
  final Product? product;
  final TransactionParty? seller;
  final TransactionParty? buyer;
  final String createdAtStr;
  final String? completedAt;
  final String? description;

  Transaction({
    required this.id,
    required this.buyerId,
    required this.sellerId,
    required this.productId,
    required this.amount,
    this.currency = 'XOF',
    required this.paymentMethod,
    required this.paymentStatus,
    this.deliveryType,
    this.transactionFee = 0,
    this.product,
    this.seller,
    this.buyer,
    required this.createdAtStr,
    this.completedAt,
    this.description,
  });

  String get type => 'purchase'; // Override as needed
  String get status => paymentStatus;
  DateTime get createdAt => DateTime.tryParse(createdAtStr) ?? DateTime.now();

  String get statusLabel {
    switch (paymentStatus) {
      case 'pending':
        return 'En attente';
      case 'processing':
        return 'En cours';
      case 'completed':
        return 'Terminée';
      case 'failed':
        return 'Échouée';
      case 'refunded':
        return 'Remboursée';
      default:
        return paymentStatus;
    }
  }

  String get paymentMethodLabel {
    switch (paymentMethod) {
      case 'orange_money':
        return 'Orange Money';
      case 'wave':
        return 'Wave';
      case 'free_money':
        return 'Free Money';
      case 'cash_delivery':
        return 'Paiement à la livraison';
      default:
        return paymentMethod;
    }
  }

  factory Transaction.fromJson(Map<String, dynamic> json) {
    return Transaction(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      buyerId: json['buyer_id']?.toString() ?? '',
      sellerId: json['seller_id']?.toString() ?? '',
      productId: json['product_id']?.toString() ?? '',
      amount: (json['amount'] ?? 0).toDouble(),
      currency: json['currency'] ?? 'XOF',
      paymentMethod: json['payment_method'] ?? '',
      paymentStatus: json['payment_status'] ?? 'pending',
      deliveryType: json['delivery_type'],
      transactionFee: (json['transaction_fee'] ?? 0).toDouble(),
      product:
          json['product'] != null ? Product.fromJson(json['product']) : null,
      seller: json['seller'] != null
          ? TransactionParty.fromJson(json['seller'])
          : null,
      buyer: json['buyer'] != null
          ? TransactionParty.fromJson(json['buyer'])
          : null,
      createdAtStr: json['created_at'] ?? '',
      completedAt: json['completed_at'],
      description: json['description'],
    );
  }
}

class TransactionParty {
  final String id;
  final String? fullName;
  final String? username;
  final String? avatarUrl;

  TransactionParty({
    required this.id,
    this.fullName,
    this.username,
    this.avatarUrl,
  });

  factory TransactionParty.fromJson(Map<String, dynamic> json) {
    return TransactionParty(
      id: json['id']?.toString() ?? '',
      fullName: json['full_name'],
      username: json['username'],
      avatarUrl: json['avatar_url'],
    );
  }
}
