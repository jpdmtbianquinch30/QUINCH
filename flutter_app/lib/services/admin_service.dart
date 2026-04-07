import 'api_service.dart';

class AdminService {
  final ApiService _api;
  AdminService(this._api);

  Future<Map<String, dynamic>> getMetrics() async {
    final res = await _api.get('/admin/metrics');
    return res.data is Map<String, dynamic> ? res.data : {};
  }

  Future<Map<String, dynamic>> getRealTimeData() async {
    final res = await _api.get('/admin/realtime');
    return res.data is Map<String, dynamic> ? res.data : {};
  }

  Future<Map<String, dynamic>> getSecurityAlerts() async {
    final res = await _api.get('/admin/security/alerts');
    return res.data is Map<String, dynamic> ? res.data : {};
  }

  Future<Map<String, dynamic>> getUsers(Map<String, dynamic> params) async {
    final res = await _api.get('/admin/users', queryParameters: params);
    return res.data is Map<String, dynamic> ? res.data : {};
  }

  Future<Map<String, dynamic>> getUser(dynamic id) async {
    final res = await _api.get('/admin/users/$id');
    return res.data is Map<String, dynamic> ? res.data : {};
  }

  Future<void> suspendUser(dynamic id, String reason, int days) async {
    await _api.post('/admin/users/$id/suspend', data: {'reason': reason, 'days': days});
  }

  Future<void> activateUser(dynamic id) async {
    await _api.post('/admin/users/$id/activate');
  }

  Future<void> banUser(dynamic id, String reason) async {
    await _api.post('/admin/users/$id/ban', data: {'reason': reason});
  }

  Future<void> deleteUser(dynamic id, String reason) async {
    await _api.delete('/admin/users/$id', data: {'reason': reason});
  }

  Future<void> verifyKyc(dynamic id, String status) async {
    await _api.post('/admin/users/$id/kyc', data: {'status': status});
  }

  Future<void> adjustTrust(dynamic id, double score, String reason) async {
    await _api.post('/admin/users/$id/trust', data: {'score': score, 'reason': reason});
  }

  Future<void> awardBadge(dynamic id, String type, String reason) async {
    await _api.post('/admin/users/$id/badge', data: {'type': type, 'reason': reason});
  }

  Future<void> sendNotification(dynamic id, String title, String body) async {
    await _api.post('/admin/users/$id/notify', data: {'title': title, 'body': body});
  }

  Future<Map<String, dynamic>> getPendingModeration() async {
    final res = await _api.get('/admin/moderation/pending');
    return res.data is Map<String, dynamic> ? res.data : {};
  }

  Future<void> moderateVideo(dynamic id, String status) async {
    await _api.post('/admin/moderation/$id', data: {'status': status});
  }

  Future<void> bulkModerate(List<String> ids, String status) async {
    await _api.post('/admin/moderation/bulk', data: {'ids': ids, 'status': status});
  }

  Future<Map<String, dynamic>> getOverviewReport(int days) async {
    final res = await _api.get('/admin/reports/overview', queryParameters: {'days': days});
    return res.data is Map<String, dynamic> ? res.data : {};
  }

  Future<Map<String, dynamic>> getTransactionReport(int days) async {
    final res = await _api.get('/admin/reports/transactions', queryParameters: {'days': days});
    return res.data is Map<String, dynamic> ? res.data : {};
  }

  Future<Map<String, dynamic>> getUserReport(int days) async {
    final res = await _api.get('/admin/reports/users', queryParameters: {'days': days});
    return res.data is Map<String, dynamic> ? res.data : {};
  }

  Future<Map<String, dynamic>> getAuditLogs(Map<String, dynamic> params) async {
    final res = await _api.get('/admin/audit-logs', queryParameters: params);
    return res.data is Map<String, dynamic> ? res.data : {};
  }

  Future<void> deleteAllVideos() async {
    await _api.post('/admin/moderation/delete-all-videos');
  }

  Future<void> resetSystem() async {
    await _api.post('/admin/system/reset');
  }
}
