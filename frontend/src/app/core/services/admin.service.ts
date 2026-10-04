import { Injectable, inject, signal, computed } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { Observable, tap } from 'rxjs';
import { ApiService } from './api.service';
import { environment } from '../../../environments/environment';

export interface AdminMetrics {
  users: { total: number; active: number; clients: number; admins: number; verified: number; new_today: number; new_this_week: number; new_this_month: number; suspended: number; banned: number; premium: number };
  products: { total: number; active: number; sold: number; hidden: number; new_today: number };
  transactions: { total: number; completed: number; pending: number; disputed: number; revenue: number; total_fees: number; today_volume: number; today_count: number; week_volume: number; month_volume: number; avg_basket: number; success_rate: number };
  moderation: { pending_videos: number; flagged_videos: number; reports: number; user_reports: number; tickets: number; appeals: number };
  security: { fraud_alerts: number; suspicious_users: number };
  social: { total_reviews: number; total_badges: number; total_follows: number };
}

export interface AdminUser {
  id: string; full_name: string; username: string; email: string; phone_number: string; avatar_url: string;
  role: string; account_status: string; kyc_status: string; trust_score: number; city: string; region: string;
  created_at: string; last_seen_at?: string; suspended_until?: string; ban_reason?: string;
  products_count?: number; purchased_transactions_count?: number; sold_transactions_count?: number;
  active_strikes_count?: number; is_premium?: boolean; badges?: { badge_type: string }[];
}

export interface AdminMe {
  user: { id: string; full_name: string; username: string; avatar_url: string };
  role: 'moderator' | 'admin' | 'super_admin';
  level: number;
  permissions: string[];
  moderator_max_suspension_days: number;
}

/** Accès aux endpoints /admin/*. Les actions sensibles reçoivent `admin_password` dans le corps. */
@Injectable({ providedIn: 'root' })
export class AdminService {
  private api = inject(ApiService);
  private http = inject(HttpClient);

  /** Permissions du staff connecté : sert à masquer ce qu'il n'a pas le droit de faire. */
  me = signal<AdminMe | null>(null);
  permissions = computed(() => new Set(this.me()?.permissions ?? []));
  can = (perm: string) => this.permissions().has(perm);
  canAny = (...perms: string[]) => perms.some(p => this.permissions().has(p));

  loadMe(): Observable<AdminMe> {
    return this.api.get<AdminMe>('admin/me').pipe(tap(m => this.me.set(m)));
  }

  // ── Dashboard ──
  getMetrics() { return this.api.get<AdminMetrics>('admin/dashboard/metrics'); }
  getRealTime() { return this.api.get<any>('admin/dashboard/real-time'); }
  getOverview(days = 7) { return this.api.get<any>('admin/reports/overview', { days }); }
  getUserReport(days = 30) { return this.api.get<any>('admin/reports/users', { days }); }
  getTransactionReport(days = 30) { return this.api.get<any>('admin/reports/transactions', { days }); }
  getFinance(days = 30) { return this.api.get<any>('admin/reports/finance', { days }); }

  // ── Boîte « À traiter » ──
  getInbox(type = 'all', mine = false) { return this.api.get<any>('admin/inbox', { type, mine: mine ? 1 : 0 }); }
  getProductReports(status = 'pending', page = 1) { return this.api.get<any>('admin/reports/products', { status, page }); }
  resolveProductReport(id: string, body: any) { return this.api.post(`admin/reports/products/${id}/resolve`, body); }
  getUserReports(status = 'pending', page = 1) { return this.api.get<any>('admin/reports/reported-users', { status, page }); }
  resolveUserReport(id: string, body: any) { return this.api.post(`admin/reports/reported-users/${id}/resolve`, body); }
  getTickets(status = 'pending', page = 1) { return this.api.get<any>('admin/reports/support-tickets', { status, page }); }
  resolveTicket(id: string, body: any) { return this.api.post(`admin/reports/support-tickets/${id}/resolve`, body); }
  assign(type: 'product-report' | 'user-report' | 'ticket', id: string, assignedTo?: string) {
    return this.api.post(`admin/reports/assign/${type}/${id}`, { assigned_to: assignedTo ?? null });
  }
  getAppeals(status = 'pending', page = 1) { return this.api.get<any>('admin/moderation/appeals', { status, page }); }
  handleAppeal(id: string, decision: 'accepted' | 'rejected', response: string) {
    return this.api.post(`admin/moderation/appeals/${id}/handle`, { decision, response });
  }
  getFraud(status = 'pending_review', page = 1) { return this.api.get<any>('admin/reports/fraud', { status, page }); }
  runFraudScan() { return this.api.post<any>('admin/reports/fraud/scan'); }
  resolveFraud(id: number | string, body: any) { return this.api.post(`admin/reports/fraud/${id}/resolve`, body); }

  // ── Modération vidéo ──
  getVideoQueue(status = 'pending', page = 1, search = '') { return this.api.get<any>('admin/moderation/pending', { status, page, search: search || null }); }
  getRejectionReasons() { return this.api.get<any>('admin/moderation/reasons'); }
  moderateVideo(id: string, body: { status: string; reason?: string; action?: string; strike?: boolean }) {
    return this.api.post(`admin/videos/${id}/moderate`, body);
  }
  bulkModerate(ids: string[], action: 'approved' | 'rejected', reason?: string) {
    return this.api.post('admin/moderation/bulk-action', { video_ids: ids, action, reason });
  }

  // ── Produits ──
  getProducts(params: Record<string, any>) { return this.api.get<any>('admin/products', params); }
  getProduct(id: string) { return this.api.get<any>(`admin/products/${id}`); }
  hideProduct(id: string, reason: string) { return this.api.post(`admin/products/${id}/hide`, { reason }); }
  restoreProduct(id: string, note?: string) { return this.api.post(`admin/products/${id}/restore`, { note }); }
  deleteProduct(id: string, reason: string) { return this.api.post(`admin/products/${id}/delete`, { reason }); }
  updateProduct(id: string, body: any) { return this.api.put(`admin/products/${id}`, body); }
  forceProductStatus(id: string, status: string, reason: string) { return this.api.post(`admin/products/${id}/force-status`, { status, reason }); }
  pinProduct(id: string, pinned: boolean) { return this.api.post(`admin/products/${id}/pin`, { pinned }); }
  removeMedia(id: string, target: 'image' | 'poster', reason: string, index?: number) {
    return this.api.post(`admin/products/${id}/media/remove`, { target, index, reason });
  }
  replaceMedia(id: string, target: 'image' | 'poster', reason: string, file: File, index?: number) {
    const fd = new FormData();
    fd.append('target', target);
    fd.append('reason', reason);
    fd.append('file', file);
    if (index !== undefined) fd.append('index', String(index));
    return this.api.upload(`admin/products/${id}/media/replace`, fd);
  }
  removeProductVideo(id: string, reason: string, strike = false) { return this.api.post(`admin/products/${id}/video/remove`, { reason, strike }); }
  bulkProducts(ids: string[], action: 'hide' | 'restore' | 'delete', reason: string) { return this.api.post('admin/products/bulk', { ids, action, reason }); }

  // ── Utilisateurs ──
  getUsers(params: Record<string, any>) { return this.api.get<any>('admin/users', params); }
  getUser(id: string) { return this.api.get<any>(`admin/users/${id}`); }
  suspendUser(id: string, reason: string, duration?: number) { return this.api.post(`admin/users/${id}/suspend`, { reason, duration }); }
  liftSuspension(id: string, reason?: string) { return this.api.post(`admin/users/${id}/activate`, { reason }); }
  warnUser(id: string, reason: string) { return this.api.post(`admin/users/${id}/warn`, { reason }); }
  banUser(id: string, reason: string, admin_password: string) { return this.api.post(`admin/users/${id}/ban`, { reason, admin_password }); }
  unbanUser(id: string, reason: string, admin_password: string) { return this.api.post(`admin/users/${id}/unban`, { reason, admin_password }); }
  deleteUser(id: string, reason: string, admin_password: string) { return this.api.post(`admin/users/${id}/delete`, { reason, admin_password }); }
  setRole(id: string, role: string, reason: string, admin_password: string) { return this.api.post(`admin/users/${id}/role`, { role, reason, admin_password }); }
  verifyKyc(id: string, status: string, reason?: string) { return this.api.post(`admin/users/${id}/verify-kyc`, { status, reason }); }
  adjustTrust(id: string, score: number, reason: string) { return this.api.post(`admin/users/${id}/adjust-trust`, { score, reason }); }
  sendNotification(id: string, title: string, body: string) { return this.api.post(`admin/users/${id}/send-notification`, { title, body }); }
  awardBadge(id: string, badge_type: string, reason?: string) { return this.api.post(`admin/users/${id}/badges`, { badge_type, reason }); }
  revokeBadge(id: string, badgeType: string) { return this.api.delete(`admin/users/${id}/badges/${badgeType}`); }
  grantPremium(id: string, days: number, reason: string) { return this.api.post(`admin/users/${id}/premium/grant`, { days, reason }); }
  revokePremium(id: string, reason: string) { return this.api.post(`admin/users/${id}/premium/revoke`, { reason }); }
  revokeStrike(userId: string, strikeId: string) { return this.api.delete(`admin/users/${userId}/strikes/${strikeId}`); }
  exportUser(id: string, admin_password: string): Observable<Blob> {
    return this.http.post(`${environment.apiUrl}/admin/users/${id}/export`, { admin_password }, { responseType: 'blob' });
  }

  // ── Transactions & litiges ──
  getTransactions(params: Record<string, any>) { return this.api.get<any>('admin/transactions', params); }
  getTransaction(id: string) { return this.api.get<any>(`admin/transactions/${id}`); }
  getDisputeConversation(id: string) { return this.api.get<any>(`admin/transactions/${id}/conversation`); }
  resolveDispute(id: string, decision: string, reason: string, admin_password: string) {
    return this.api.post(`admin/transactions/${id}/resolve-dispute`, { decision, reason, admin_password });
  }
  exportTransactions(params: Record<string, any>): Observable<Blob> {
    return this.http.get(`${environment.apiUrl}/admin/transactions/export`, { params, responseType: 'blob' });
  }

  // ── Sécurité ──
  getAdminLogs(params: Record<string, any>) { return this.api.get<any>('admin/security/admin-logs', params); }
  exportAdminLogs(params: Record<string, any>): Observable<Blob> {
    return this.http.get(`${environment.apiUrl}/admin/security/admin-logs/export`, { params, responseType: 'blob' });
  }
  getTechLogs(params: Record<string, any>) { return this.api.get<any>('admin/security/logs', params); }
  getBannedIps() { return this.api.get<any[]>('admin/security/banned-ips'); }
  banIp(ip_address: string, reason: string, duration_hours: number | null, admin_password: string) {
    return this.api.post<any>('admin/security/ip-ban', { ip_address, reason, duration_hours, admin_password });
  }
  unbanIp(id: string, admin_password: string) { return this.api.post(`admin/security/banned-ips/${id}/remove`, { admin_password }); }

  // ── Catégories ──
  getCategories() { return this.api.get<any>('admin/categories'); }
  createCategory(body: any) { return this.api.post('admin/categories', body); }
  updateCategory(id: string, body: any) { return this.api.put(`admin/categories/${id}`, body); }
  deleteCategory(id: string) { return this.api.delete(`admin/categories/${id}`); }
  reorderCategories(ids: string[]) { return this.api.post('admin/categories/reorder', { ids }); }

  // ── Réglages, bannières, notifications ──
  getSettings() { return this.api.get<any>('admin/settings'); }
  saveSettings(settings: Record<string, any>) { return this.api.put('admin/settings', { settings }); }
  saveSystemSettings(settings: Record<string, any>, admin_password: string) { return this.api.put('admin/settings/system', { settings, admin_password }); }
  getBanners() { return this.api.get<any>('admin/feed/banners'); }
  saveBanner(fd: FormData, id?: string) { return this.api.upload(id ? `admin/feed/banners/${id}` : 'admin/feed/banners', fd); }
  deleteBanner(id: string) { return this.api.delete(`admin/feed/banners/${id}`); }
  countAudience(audience: string, city: string | null) { return this.api.post<any>('admin/notifications/broadcast/count', { audience, city }); }
  broadcast(body: any) { return this.api.post<any>('admin/notifications/broadcast', body); }
  getBroadcastHistory() { return this.api.get<any[]>('admin/notifications/broadcast-history'); }

  // ── Équipe, Premium, avis ──
  getStaff() { return this.api.get<any>('admin/staff'); }
  getPremium(params: Record<string, any> = {}) { return this.api.get<any>('admin/premium', params); }
  getReviews(params: Record<string, any> = {}) { return this.api.get<any>('admin/reviews', params); }
  deleteReview(id: string, reason: string) { return this.api.post(`admin/reviews/${id}/delete`, { reason }); }

  /** Télécharge un Blob sous un nom de fichier. */
  saveBlob(blob: Blob, filename: string) {
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url; a.download = filename; a.click();
    URL.revokeObjectURL(url);
  }
}
