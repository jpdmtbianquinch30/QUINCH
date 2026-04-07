import 'package:flutter/foundation.dart';
import '../models/cart_item.dart';
import '../services/cart_service.dart';

class CartProvider extends ChangeNotifier {
  final CartService _cartService;

  List<CartItem> _items = [];
  bool _isLoading = false;
  String? _error;

  CartProvider(this._cartService);

  List<CartItem> get items => _items;
  bool get isLoading => _isLoading;
  bool get isEmpty => _items.isEmpty;
  String? get error => _error;
  int get count => _items.length;

  double get subtotal =>
      _items.fold(0, (sum, item) => sum + item.total);

  double get deliveryTotal => _items.fold(0, (sum, item) {
    final fee = item.product?.deliveryFee ?? 0;
    return sum + fee;
  });

  double get total => subtotal + deliveryTotal;

  String get formattedSubtotal => '${subtotal.toStringAsFixed(0)} F CFA';
  String get formattedTotal => '${total.toStringAsFixed(0)} F CFA';

  Future<void> loadCart() async {
    _isLoading = true;
    notifyListeners();

    try {
      _items = await _cartService.getCart();
      _error = null;
    } catch (e) {
      _error = 'Erreur lors du chargement du panier';
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<bool> addToCart(String productId, {int quantity = 1}) async {
    try {
      await _cartService.addToCart(productId, quantity: quantity);
      await loadCart();
      return true;
    } catch (e) {
      _error = 'Erreur lors de l\'ajout au panier';
      notifyListeners();
      return false;
    }
  }

  Future<void> updateQuantity(String cartItemId, int quantity) async {
    try {
      await _cartService.updateQuantity(cartItemId, quantity);
      await loadCart();
    } catch (e) {
      _error = 'Erreur lors de la mise à jour';
      notifyListeners();
    }
  }

  Future<void> removeItem(String cartItemId) async {
    try {
      await _cartService.removeItem(cartItemId);
      _items.removeWhere((item) => item.id == cartItemId);
      notifyListeners();
    } catch (e) {
      _error = 'Erreur lors de la suppression';
      notifyListeners();
    }
  }

  Future<void> clearCart() async {
    try {
      await _cartService.clearCart();
      _items = [];
      notifyListeners();
    } catch (_) {}
  }
}
