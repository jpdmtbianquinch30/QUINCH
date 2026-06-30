import { Injectable, signal } from '@angular/core';
import { Observable, tap } from 'rxjs';
import { ApiService } from './api.service';

export interface AdminMetrics {
  users: { total: number; active: number; clients: number; admins: number; verified: number; new_today: number; new_this_week: number; new_this_month: number; suspended: number };
  products: { total: number; active: number; sold: number; new_today: number };
  transactions: { total: number; completed: number; pending: number; disputed: number; revenue: number; total_fees: number; today_volume: number; today_count: number; week_volume: number; month_volume: number; avg_basket: number; success_rate: number };
  moderation: { pending_videos: number; flagged_videos: number; reports: number };
  security: { fraud_alerts: number; suspicious_users: number };
  social: { total_reviews: number; total_badges: number; total_follows: number };
}

export interface AdminUser {
  id: string;
  full_name: string;
  username: string;
  email: string;
  phone_number: string;
  avatar_url: string;
  role: string;
  account_status: string;
  kyc_status: string;
  trust_score: number;
  city: string;
  region: string;
  created_at: string;
  products_count?: number;
  purchased_transactions_count?: number;
  sold_transactions_count?: number;
  badges?: { badge_type: string }[];
}

export interface ModerationItem {
  id: string;
  product?: { title: string; slug: string };
  moderation_status: string;
  created_at: string;
  user?: { full_name: string };
}

@Injectable({ providedIn: 'root' })
export class AdminService {
  metrics = signal<AdminMetrics | null>(null);
  users = signal<AdminUser[]>([]);
  totalUsers = signal(0);
  moderationQueue = signal<ModerationItem[]>([]);
  auditLogs = signal<any[]>([]);

  constructor(private api: ApiService) {}

  getMetrics(): Observable<AdminMetrics> {
    return this.api.get<AdminMetrics>('admin/dashboard/metrics').pipe(
      tap(m => this.metrics.set(m))
    );
  }

  getRealTimeData(): Observable<any> {
    return this.api.get('admin/dashboard/real-time');
  }

  getUsers(params?: Record<string, any>): Observable<any> {
    return this.api.get('admin/users', params).pipe(
      tap((res: any) => {
        this.users.set(res.data || []);
        this.totalUsers.set(res.total || 0);
      })
    );
  }

  getUser(id: string): Observable<any> {
    return this.api.get(`admin/users/${id}`);
  }

  suspendUser(id: string, reason: string, duration?: number): Observable<any> {
    return this.api.post(`admin/users/${id}/suspend`, { reason, duration });
  }

  activateUser(id: string): Observable<any> {
    return this.api.post(`admin/users/${id}/activate`, {});
  }

  deleteUser(id: string, reason: string): Observable<any> {
    return this.api.delete(`admin/users/${id}`);
  }

  banUser(id: string, reason: string): Observable<any> {
    return this.api.post(`admin/users/${id}/suspend`, { reason, duration: 3650, permanent: true });
  }

  verifyKyc(id: string, status: string, reason?: string): Observable<any> {
    return this.api.post(`admin/users/${id}/verify-kyc`, { status, reason });
  }

  adjustTrust(id: string, score: number, reason: string): Observable<any> {
    return this.api.post(`admin/users/${id}/adjust-trust`, { score, reason });
  }

  sendNotification(id: string, title: string, body: string): Observable<any> {
    return this.api.post(`admin/users/${id}/send-notification`, { title, body });
  }

  awardBadge(userId: string, badgeType: string, reason?: string): Observable<any> {
    return this.api.post(`admin/users/${userId}/badges`, { badge_type: badgeType, reason });
  }

  revokeBadge(userId: string, badgeType: string): Observable<any> {
    return this.api.delete(`admin/users/${userId}/badges/${badgeType}`);
  }

  getPendingModeration(): Observable<any> {
    return this.api.get('admin/moderation/pending').pipe(
      tap((res: any) => this.moderationQueue.set(res.data || []))
    );
  }

  moderateVideo(videoId: string, status: string, reason?: string): Observable<any> {
    return this.api.post(`admin/videos/${videoId}/moderate`, { status, reason });
  }

  bulkModerate(ids: string[], action: string, reason?: string): Observable<any> {
    return this.api.post('admin/moderation/bulk-action', { video_ids: ids, action, reason });
  }

  getSecurityAlerts(): Observable<any> {
    return this.api.get('admin/security/alerts');
  }

  getAuditLogs(params?: Record<string, any>): Observable<any> {
    return this.api.get('admin/security/logs', params).pipe(
      tap((res: any) => this.auditLogs.set(res.data || []))
    );
  }

  banIp(ip: string, reason: string): Observable<any> {
    return this.api.post('admin/security/ip-ban', { ip_address: ip, reason });
  }

  getTransactionReport(days: number = 30): Observable<any> {
    return this.api.get('admin/reports/transactions', { days });
  }

  getUserReport(days: number = 30): Observable<any> {
    return this.api.get('admin/reports/users', { days });
  }

  getOverviewReport(days: number = 7): Observable<any> {
    return this.api.get('admin/reports/overview', { days });
  }

  getFraudReport(): Observable<any> {
    return this.api.get('admin/reports/fraud');
  }
}
