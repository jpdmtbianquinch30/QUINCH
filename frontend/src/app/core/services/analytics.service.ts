import { Injectable, inject } from '@angular/core';
import { AuthService } from './auth.service';

export interface AnalyticsEvent {
  action: string;
  category: string;
  label?: string;
  value?: number;
  metadata?: Record<string, any>;
  timestamp: string;
}

@Injectable({ providedIn: 'root' })
export class AnalyticsService {
  private auth = inject(AuthService);
  private events: AnalyticsEvent[] = [];

  trackAction(action: string, category: string, metadata?: Record<string, any>) {
    const event: AnalyticsEvent = {
      action,
      category,
      metadata: {
        ...metadata,
        userId: this.auth.user()?.id,
        sessionId: this.getSessionId(),
        device: this.getDeviceInfo(),
      },
      timestamp: new Date().toISOString(),
    };
    this.events.push(event);
    this.flushIfNeeded();
  }

  trackProductView(productId: string) {
    this.trackAction('view', 'product', { productId });
  }

  trackProductLike(productId: string) {
    this.trackAction('like', 'product', { productId });
  }

  trackAddToCart(productId: string, price: number) {
    this.trackAction('add_to_cart', 'commerce', { productId, price });
  }

  trackPurchase(transactionId: string, amount: number) {
    this.trackAction('purchase', 'commerce', { transactionId, amount });
  }

  trackShare(productId: string, platform: string) {
    this.trackAction('share', 'social', { productId, platform });
  }

  trackSearch(query: string, resultsCount: number) {
    this.trackAction('search', 'discovery', { query, resultsCount });
  }

  private getSessionId(): string {
    let sid = sessionStorage.getItem('q_session_id');
    if (!sid) {
      sid = 'sess_' + Date.now() + '_' + Math.random().toString(36).substring(7);
      sessionStorage.setItem('q_session_id', sid);
    }
    return sid;
  }

  private getDeviceInfo() {
    return {
      platform: navigator.platform,
      screen: `${window.screen.width}x${window.screen.height}`,
      language: navigator.language,
    };
  }

  private flushIfNeeded() {
    // In production, batch send events to analytics API every 10 events
    if (this.events.length >= 10) {
      console.log('[Analytics] Flushing', this.events.length, 'events');
      this.events = [];
    }
  }
}
