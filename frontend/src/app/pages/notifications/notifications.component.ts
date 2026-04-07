import { Component, inject, OnInit, signal } from '@angular/core';
import { Router } from '@angular/router';
import { NotificationService, AppNotification } from '../../core/services/notification.service';

type NotifTab = 'all' | 'interactions' | 'messages' | 'system';

@Component({
  selector: 'app-notifications',
  standalone: true,
  templateUrl: './notifications.component.html',
  styleUrl: './notifications.component.scss',
})
export class NotificationsComponent implements OnInit {
  notifService = inject(NotificationService);
  private router = inject(Router);

  loading = signal(false);
  activeTab = signal<NotifTab>('all');

  ngOnInit() {
    this.loadTab('all');
  }

  loadTab(tab: NotifTab) {
    this.activeTab.set(tab);
    this.loading.set(true);
    this.notifService.getNotifications(tab).subscribe({
      complete: () => this.loading.set(false),
    });
  }

  markAllRead() {
    const tab = this.activeTab();
    this.notifService.markAllRead(tab).subscribe(() => {
      this.notifService.getNotifications(tab).subscribe();
      this.notifService.getUnreadCount().subscribe();
    });
  }

  openNotification(notif: AppNotification) {
    // Mark as read
    if (!notif.is_read) {
      this.notifService.markRead(notif.id).subscribe(() => {
        this.notifService.getUnreadCount().subscribe();
      });
    }

    // Build the best redirect URL and navigate
    const url = this.resolveUrl(notif);
    if (url) {
      // Force navigation even if same URL (e.g. /messages → /messages with different state)
      this.router.navigateByUrl('/', { skipLocationChange: true }).then(() => {
        this.router.navigateByUrl(url);
      });
    }
  }

  /**
   * Resolve the best URL for a notification based on type, action_url and data.
   */
  private resolveUrl(notif: AppNotification): string | null {
    // For message notifications, always build URL with conversation_id
    if (notif.type === 'message') {
      const convId = notif.data?.conversation_id;
      return convId ? '/messages?conversation=' + convId : '/messages';
    }

    // If we have a direct action_url from the backend, use it
    if (notif.action_url) {
      return notif.action_url;
    }

    // Fallback: build URL from type and data
    switch (notif.type) {
      case 'like':
        // Like notifications → product detail
        if (notif.data?.product_slug) return '/product/' + notif.data.product_slug;
        return '/profile';

      case 'follow':
        // Follow → sender's profile
        if (notif.sender?.username) return '/seller/' + notif.sender.username;
        return '/profile';

      case 'friend':
        // Friendship → messages
        return '/messages';

      case 'purchase':
      case 'order':
      case 'transaction':
        // Transaction → transactions page
        return '/transactions';

      case 'negotiation':
        // Negotiation → transactions page
        return '/transactions';

      case 'review':
        // Review → own profile (reviews section)
        return '/profile';

      case 'welcome':
        // Welcome → edit profile
        return '/profile/edit';

      case 'system':
      case 'admin':
      case 'admin_message':
        return '/notifications';

      case 'badge':
        return '/profile';

      case 'kyc':
      case 'account':
        return '/settings';

      case 'price_drop':
        if (notif.data?.product_slug) return '/product/' + notif.data.product_slug;
        return '/marketplace';

      case 'comment':
        if (notif.data?.product_slug) return '/product/' + notif.data.product_slug;
        return '/feed';

      case 'report':
        return '/profile';

      default:
        return '/feed';
    }
  }

  deleteNotification(event: MouseEvent, notif: AppNotification) {
    event.stopPropagation();
    this.notifService.deleteNotification(notif.id).subscribe();
  }

  getTabCount(tab: NotifTab): number {
    const c = this.notifService.tabCounts();
    return c[tab] ?? 0;
  }

  getIcon(type: string): string {
    const icons: Record<string, string> = {
      message: 'chat',
      purchase: 'shopping_cart',
      like: 'favorite',
      follow: 'person_add',
      friend: 'people',
      system: 'info',
      negotiation: 'local_offer',
      price_drop: 'trending_down',
      welcome: 'waving_hand',
      review: 'star',
      order: 'local_shipping',
      transaction: 'receipt_long',
      badge: 'military_tech',
      admin: 'admin_panel_settings',
      account: 'manage_accounts',
      kyc: 'verified_user',
      admin_message: 'campaign',
      comment: 'comment',
      report: 'flag',
    };
    return icons[type] || 'notifications';
  }

  getIconColor(type: string): string {
    const colors: Record<string, string> = {
      message: '#3b82f6',
      purchase: '#22c55e',
      like: '#ef4444',
      follow: '#6366f1',
      friend: '#8b5cf6',
      system: '#f59e0b',
      welcome: '#10b981',
      review: '#f59e0b',
      order: '#3b82f6',
      transaction: '#22c55e',
      badge: '#a855f7',
      admin: '#ef4444',
      account: '#ef4444',
      kyc: '#3b82f6',
      admin_message: '#ef4444',
      negotiation: '#f97316',
      comment: '#6366f1',
    };
    return colors[type] || '#6366f1';
  }

  /**
   * Get a descriptive label for where clicking this notification will go.
   */
  getActionLabel(notif: AppNotification): string {
    const labels: Record<string, string> = {
      message: 'Voir les messages',
      like: 'Voir le produit',
      follow: 'Voir le profil',
      friend: 'Envoyer un message',
      purchase: 'Voir la commande',
      order: 'Voir la commande',
      transaction: 'Voir les transactions',
      negotiation: 'Voir la negociation',
      review: 'Voir mon profil',
      welcome: 'Completer mon profil',
      system: 'En savoir plus',
      admin: 'En savoir plus',
      badge: 'Voir mon profil',
      kyc: 'Voir les parametres',
      account: 'Voir les parametres',
      comment: 'Voir le produit',
      price_drop: 'Voir le produit',
    };
    return labels[notif.type] || '';
  }

  getGroupedLabel(notif: AppNotification): string | null {
    if (!notif.group_count || notif.group_count <= 1) return null;
    return `+${notif.group_count - 1}`;
  }

  formatTime(dateStr: string): string {
    const d = new Date(dateStr);
    const now = new Date();
    const diff = now.getTime() - d.getTime();
    if (diff < 60000) return "A l'instant";
    if (diff < 3600000) return Math.floor(diff / 60000) + ' min';
    if (diff < 86400000) return Math.floor(diff / 3600000) + ' h';
    if (diff < 604800000) {
      const days = ['dim', 'lun', 'mar', 'mer', 'jeu', 'ven', 'sam'];
      return days[d.getDay()];
    }
    return d.toLocaleDateString('fr-FR', { day: 'numeric', month: 'short' });
  }

  /**
   * Group notifications by time period for TikTok-style sections.
   */
  getTimeSections(): { label: string; notifications: AppNotification[] }[] {
    const now = new Date();
    const today: AppNotification[] = [];
    const yesterday: AppNotification[] = [];
    const thisWeek: AppNotification[] = [];
    const older: AppNotification[] = [];

    for (const n of this.notifService.notifications()) {
      const d = new Date(n.created_at);
      const diff = now.getTime() - d.getTime();
      if (diff < 86400000 && d.getDate() === now.getDate()) {
        today.push(n);
      } else if (diff < 172800000) {
        yesterday.push(n);
      } else if (diff < 604800000) {
        thisWeek.push(n);
      } else {
        older.push(n);
      }
    }

    const sections: { label: string; notifications: AppNotification[] }[] = [];
    if (today.length) sections.push({ label: "Aujourd'hui", notifications: today });
    if (yesterday.length) sections.push({ label: 'Hier', notifications: yesterday });
    if (thisWeek.length) sections.push({ label: 'Cette semaine', notifications: thisWeek });
    if (older.length) sections.push({ label: 'Plus ancien', notifications: older });
    return sections;
  }
}
