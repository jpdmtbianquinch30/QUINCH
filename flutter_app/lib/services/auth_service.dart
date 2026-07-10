import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';
import '../models/user.dart';
import 'api_service.dart';

class AuthService {
  final ApiService _api;

  AuthService(this._api);

  Future<AuthResponse> register({
    required String phoneNumber,
    required String fullName,
    required String username,
    required String password,
    required String passwordConfirmation,
  }) async {
    final response = await _api.post('/auth/register', data: {
      'phone_number': _normalizePhone(phoneNumber),
      'full_name': fullName,
      'username': username,
      'password': password,
      'password_confirmation': passwordConfirmation,
    });
    final authResponse = AuthResponse.fromJson(response.data);
    await _saveAuth(authResponse);
    return authResponse;
  }

  Future<AuthResponse> login({
    required String phoneNumber,
    required String password,
  }) async {
    final response = await _api.post('/auth/login', data: {
      'phone_number': _normalizePhone(phoneNumber),
      'password': password,
    });
    final authResponse = AuthResponse.fromJson(response.data);
    await _saveAuth(authResponse);
    return authResponse;
  }
  Future<Map<String, dynamic>> loginWithGoogle({
    required String idToken,
  }) async {
    final response = await _api.post('/auth/google', data: {
      'id_token': idToken,
    });
    final authResponse = AuthResponse.fromJson(response.data);
    await _saveAuth(authResponse);
    return response.data;
  }

  Future<void> addGooglePhone({required String phoneNumber}) async {
    await _api.post('/auth/google/add-phone', data: {
      'phone_number': phoneNumber,
    });
  }

  Future<void> logout() async {
    try {
      await _api.post('/auth/logout');
    } catch (_) {}
    await clearLocalData();
  }

  Future<User?> getMe() async {
    try {
      final response = await _api.get('/auth/me');
      final user = User.fromJson(response.data['user']);
      await _saveUser(user);
      return user;
    } catch (_) {
      return null;
    }
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
    required String newPasswordConfirmation,
  }) async {
    await _api.put('/auth/change-password', data: {
      'current_password': currentPassword,
      'new_password': newPassword,
      'new_password_confirmation': newPasswordConfirmation,
    });
  }

  Future<void> deleteAccount() async {
    await _api.delete('/auth/delete-account');
    await clearLocalData();
  }

  Future<User?> loadFromStorage() async {
    await _api.loadToken();
    if (_api.token == null) return null;

    final prefs = await SharedPreferences.getInstance();
    final userStr = prefs.getString(ApiConfig.userKey);
    if (userStr != null) {
      try {
        return User.fromJson(json.decode(userStr));
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  Future<void> _saveAuth(AuthResponse authResponse) async {
    await _api.saveToken(authResponse.token);
    await _saveUser(authResponse.user);
  }

  Future<void> _saveUser(User user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(ApiConfig.userKey, json.encode(user.toJson()));
  }

  Future<void> clearLocalData() async {
    await _api.clearToken();
    await _clearUser();
  }

  Future<void> _clearUser() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(ApiConfig.userKey);
  }

  String _normalizePhone(String phone) {
    phone = phone.replaceAll(RegExp(r'\s+'), '');
    if (!phone.startsWith('+221') && !phone.startsWith('00221')) {
      if (phone.startsWith('0')) {
        phone = '+221${phone.substring(1)}';
      } else if (phone.startsWith('7') || phone.startsWith('3')) {
        phone = '+221$phone';
      }
    }
    if (phone.startsWith('00221')) {
      phone = '+${phone.substring(2)}';
    }
    return phone;
  }
}
