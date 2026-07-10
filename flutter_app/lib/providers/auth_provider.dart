import 'package:flutter/foundation.dart';
import '../models/user.dart';
import '../services/auth_service.dart';
import '../services/api_service.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _authService;
  final ApiService _apiService;

  User? _user;
  bool _isLoading = false;
  String? _error;
  bool _initialized = false;

  AuthProvider(this._authService, this._apiService) {
    _apiService.setOnUnauthorized(_forceLogout);
  }

  User? get user => _user;
  bool get isAuthenticated => _user != null;
  bool get isAdmin => _user?.isAdmin ?? false;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get initialized => _initialized;

  Future<void> initialize() async {
    _isLoading = true;
    notifyListeners();

    try {
      _user = await _authService.loadFromStorage();
      if (_user != null) {
        // Refresh user data from backend
        final freshUser = await _authService.getMe();
        if (freshUser != null) {
          _user = freshUser;
        }
      }
    } catch (_) {
      _user = null;
    }

    _initialized = true;
    _isLoading = false;
    notifyListeners();
  }

  Future<bool> login({
    required String phoneNumber,
    required String password,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _authService.login(
        phoneNumber: phoneNumber,
        password: password,
      );
      _user = response.user;
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = _extractError(e);
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> register({
    required String phoneNumber,
    required String fullName,
    required String username,
    required String password,
    required String passwordConfirmation,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _authService.register(
        phoneNumber: phoneNumber,
        fullName: fullName,
        username: username,
        password: password,
        passwordConfirmation: passwordConfirmation,
      );
      _user = response.user;
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = _extractError(e);
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }
   Future<Map<String, dynamic>> loginWithGoogle({required String idToken}) async {
     _isLoading = true;
     _error = null;
     notifyListeners();

     try {
       final result = await _authService.loginWithGoogle(idToken: idToken);
       _user = result['user'] != null ? User.fromJson(result['user']) : null;
       _isLoading = false;
       notifyListeners();
       return {
         'success': true,
         'needs_phone': result['needs_phone'] ?? false,
         'needs_username': result['needs_username'] ?? false,
       };
     } catch (e) {
       _error = _extractError(e);
       _isLoading = false;
       notifyListeners();
       return {'success': false, 'error': _error};
     }
   }

   Future<void> addGooglePhone({required String phoneNumber}) async {
     await _authService.addGooglePhone(phoneNumber: phoneNumber);
   }

  Future<void> refreshUser() async {
    try {
      _user = await _authService.getMe();
      notifyListeners();
    } catch (_) {}
  }

  Future<void> logout() async {
    await _authService.logout();
    _user = null;
    notifyListeners();
  }

  void updateUser(User user) {
    _user = user;
    notifyListeners();
  }

  void _forceLogout() {
    _user = null;
    _authService.clearLocalData();
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  String _extractError(dynamic e) {
    if (e is Exception) {
      try {
        final dioError = e as dynamic;
        final data = dioError.response?.data;
        if (data is Map) {
          return data['message'] ?? data['error'] ?? 'Une erreur est survenue';
        }
      } catch (_) {}
    }
    return 'Une erreur est survenue. Vérifiez votre connexion.';
  }
}
