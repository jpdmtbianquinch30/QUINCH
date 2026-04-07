import 'package:dio/dio.dart';
import '../models/user.dart';
import 'api_service.dart';

class UserService {
  final ApiService _api;

  UserService(this._api);

  Future<User> getProfile() async {
    final response = await _api.get('/user/profile');
    return User.fromJson(response.data['user'] ?? response.data);
  }

  Future<User> updateProfile({
    String? fullName,
    String? username,
    String? bio,
    String? location,
    Map<String, dynamic>? extra,
  }) async {
    final data = <String, dynamic>{};
    if (fullName != null) data['full_name'] = fullName;
    if (username != null) data['username'] = username;
    if (bio != null) data['bio'] = bio;
    if (location != null) data['location'] = location;
    if (extra != null) data.addAll(extra);
    final response = await _api.put('/user/profile', data: data);
    return User.fromJson(response.data['user'] ?? response.data);
  }

  Future<void> savePreferences(Map<String, dynamic> preferences) async {
    await _api.post('/user/preferences', data: preferences);
  }

  Future<User> updateAvatar(String filePath) async {
    final data = FormData.fromMap({
      'avatar': await MultipartFile.fromFile(filePath),
    });
    final response = await _api.upload('/user/upload-avatar', data: data);
    return User.fromJson(response.data['user'] ?? response.data);
  }

  Future<User> uploadCover(FormData data) async {
    final response = await _api.upload('/user/upload-cover', data: data);
    return User.fromJson(response.data['user'] ?? response.data);
  }

  // Public profiles
  Future<Map<String, dynamic>> getSellerProfile(String username) async {
    final response = await _api.get('/users/$username/profile');
    return response.data;
  }

  Future<List<dynamic>> getSellerProducts(String username) async {
    final response = await _api.get('/users/$username/products');
    return response.data['products'] ?? response.data['data'] ?? [];
  }

  Future<List<dynamic>> getSellerReviews(String userId) async {
    final response = await _api.get('/users/$userId/reviews');
    return response.data['reviews'] ?? response.data['data'] ?? [];
  }

  /// Report a user for violating app rules.
  Future<Map<String, dynamic>> reportUser({
    required String userId,
    required String reason,
    String? description,
  }) async {
    final response = await _api.post('/users/$userId/report', data: {
      'reason': reason,
      if (description != null && description.isNotEmpty) 'description': description,
    });
    return response.data;
  }
}
