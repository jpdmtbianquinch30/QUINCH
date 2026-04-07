import 'package:flutter/foundation.dart' show debugPrint;
import 'api_service.dart';

class FollowService {
  final ApiService _api;

  FollowService(this._api);

  /// Follow a user — POST /follow/{userId}
  /// Returns { following: true, is_mutual: bool, message: string, conversation_id?: string }
  Future<Map<String, dynamic>> follow(String userId) async {
    final response = await _api.post('/follow/$userId');
    return response.data;
  }

  /// Unfollow a user — DELETE /unfollow/{userId}
  Future<void> unfollow(String userId) async {
    await _api.delete('/unfollow/$userId');
  }

  /// Get follow counts for any user — GET /users/{userId}/follow-counts
  /// Returns { followers: int, following: int, is_following: bool, is_mutual: bool }
  Future<Map<String, dynamic>> getFollowCounts(String userId) async {
    final response = await _api.get('/users/$userId/follow-counts');
    return response.data;
  }

  /// Get authenticated user's followers — GET /my-followers
  Future<List<dynamic>> getMyFollowers() async {
    final response = await _api.get('/my-followers');
    final data = response.data;
    return data['data'] ?? data['followers'] ?? [];
  }

  /// Get users the authenticated user is following — GET /my-following
  Future<List<dynamic>> getMyFollowing() async {
    final response = await _api.get('/my-following');
    final data = response.data;
    return data['data'] ?? data['following'] ?? [];
  }

  /// Get a specific user's followers — GET /users/{userId}/followers
  Future<List<dynamic>> getUserFollowers(String userId) async {
    final response = await _api.get('/users/$userId/followers');
    final data = response.data;
    return data['data'] ?? data['followers'] ?? [];
  }

  /// Get users a specific user is following — GET /users/{userId}/following
  Future<List<dynamic>> getUserFollowing(String userId) async {
    final response = await _api.get('/users/$userId/following');
    final data = response.data;
    return data['data'] ?? data['following'] ?? [];
  }

  /// Get mutual friends — GET /my-friends
  Future<List<dynamic>> getFriends() async {
    final response = await _api.get('/my-friends');
    return response.data['friends'] ?? response.data['data'] ?? [];
  }

  /// Check friendship status — GET /users/{userId}/is-friend
  /// Returns { is_friend: bool, i_follow: bool, they_follow: bool }
  Future<Map<String, dynamic>> isFriend(String userId) async {
    final response = await _api.get('/users/$userId/is-friend');
    return response.data;
  }

  /// Optimized: check if the current user follows a specific user
  Future<bool> isFollowing(String userId) async {
    try {
      final counts = await getFollowCounts(userId);
      return counts['is_following'] == true;
    } catch (e) {
      debugPrint('[FollowService] isFollowing error: $e');
      return false;
    }
  }
}
