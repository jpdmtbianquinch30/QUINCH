import { Injectable, signal, inject } from '@angular/core';
import { Observable, tap } from 'rxjs';
import { ApiService } from './api.service';

export interface AppNotification {
  id: string;
  type: string;
  title: string;
  body: string;
  icon?: string;
  action_url?: string;
  data?: any;
  is_read: boolean;
  created_at: string;
  group_key?: string;
  group_count?: number;
  priority?: string;
  image_url?: string;
  sender_id?: string;
  sender?: { id: string; full_name: string; avatar_url?: string; username?: string };
}

export interface NotifCounts {
  all: number;
  interactions: number;
  messages: number;
  system: number;
}

export interface NotifPreference {
  type: string;
  label: string;
  push_enabled: boolean;
  in_app_enabled: boolean;
  email_enabled: boolean;
}

@Injectable({ providedIn: 'root' })
export class NotificationService {
  private api = inject(ApiService);

  notifications = signal<AppNotification[]>([]);
  unreadCount = signal(0);
  tabCounts = signal<NotifCounts>({ all: 0, interactions: 0, messages: 0, system: 0 });
  preferences = signal<NotifPreference[]>([]);

  // Toast notifications (client-side)
  toasts = signal<Toast[]>([]);

  /**
   * Fetch notifications with optional tab filter.
   */
  getNotifications(tab: string = 'all'): Observable<any> {
    return this.api.get<any>('notifications', { tab }).pipe(
      tap(res => {
        this.notifications.set(res.data || []);
        if (res.counts) {
          this.tabCounts.set(res.counts);
          this.unreadCount.set(res.counts.all ?? 0);
        }
      })
    );
  }

  /**
   * Get unread count (overall + per tab).
   */
  getUnreadCount(): Observable<any> {
    return this.api.get<any>('notifications/unread-count').pipe(
      tap(res => {
        this.unreadCount.set(res.count);
        if (res.tabs) {
          this.tabCounts.set({
            all: res.count,
            interactions: res.tabs.interactions ?? 0,
            messages: res.tabs.messages ?? 0,
            system: res.tabs.system ?? 0,
          });
        }
      })
    );
  }

  markRead(id: string): Observable<any> {
    return this.api.post<any>(`notifications/${id}/read`).pipe(
      tap(() => {
        this.notifications.update(list =>
          list.map(n => n.id === id ? { ...n, is_read: true } : n)
        );
        this.unreadCount.update(c => Math.max(0, c - 1));
      })
    );
  }

  markAllRead(tab: string = 'all'): Observable<any> {
    return this.api.post<any>(`notifications/read-all?tab=${tab}`, {}).pipe(
      tap(() => {
        this.notifications.update(list =>
          list.map(n => ({ ...n, is_read: true }))
        );
        if (tab === 'all') {
          this.unreadCount.set(0);
          this.tabCounts.set({ all: 0, interactions: 0, messages: 0, system: 0 });
        }
      })
    );
  }

  deleteNotification(id: string): Observable<any> {
    return this.api.delete<any>(`notifications/${id}`).pipe(
      tap(() => {
        this.notifications.update(list => list.filter(n => n.id !== id));
      })
    );
  }

  // ─── Preferences ──────────────────────────────────

  getPreferences(): Observable<any> {
    return this.api.get<any>('notifications/preferences').pipe(
      tap(res => this.preferences.set(res.preferences || []))
    );
  }

  updatePreferences(prefs: NotifPreference[]): Observable<any> {
    return this.api.put<any>('notifications/preferences', { preferences: prefs }).pipe(
      tap(() => this.preferences.set(prefs))
    );
  }

  // ─── Client-side toast system ─────────────────────

  showToast(type: 'success' | 'error' | 'info' | 'warning', message: string, duration = 3000) {
    const toast: Toast = { id: Date.now().toString(), type, message, duration };
    this.toasts.update(t => [...t, toast]);
    setTimeout(() => this.removeToast(toast.id), duration);
  }

  removeToast(id: string) {
    this.toasts.update(t => t.filter(x => x.id !== id));
  }

  success(message: string) { this.showToast('success', message); }
  error(message: string) { this.showToast('error', message); }
  info(message: string) { this.showToast('info', message); }
  warning(message: string) { this.showToast('warning', message); }
}

export interface Toast {
  id: string;
  type: 'success' | 'error' | 'info' | 'warning';
  message: string;
  duration: number;
}
