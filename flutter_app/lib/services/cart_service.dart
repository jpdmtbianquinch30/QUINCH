import '../models/cart_item.dart';
import 'api_service.dart';

class CartService {
  final ApiService _api;

  CartService(this._api);

  Future<List<CartItem>> getCart() async {
    final response = await _api.get('/cart');
    final list = response.data['items'] ?? response.data['data'] ?? [];
    return (list as List).map((e) => CartItem.fromJson(e)).toList();
  }

  Future<int> getCount() async {
    final response = await _api.get('/cart/count');
    return response.data['count'] ?? 0;
  }

  Future<CartItem> addToCart(String productId, {int quantity = 1}) async {
    final response = await _api.post('/cart/add', data: {
      'product_id': productId,
      'quantity': quantity,
    });
    return CartItem.fromJson(response.data['item'] ?? response.data);
  }

  Future<CartItem> updateQuantity(String cartItemId, int quantity) async {
    final response = await _api.put('/cart/$cartItemId', data: {
      'quantity': quantity,
    });
    return CartItem.fromJson(response.data['item'] ?? response.data);
  }

  Future<void> removeItem(String cartItemId) async {
    await _api.delete('/cart/$cartItemId');
  }

  Future<void> clearCart() async {
    await _api.delete('/cart');
  }
}
