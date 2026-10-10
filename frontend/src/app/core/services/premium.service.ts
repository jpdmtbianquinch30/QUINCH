import { Injectable, inject } from '@angular/core';
import { Observable } from 'rxjs';
import { ApiService } from './api.service';

export interface PremiumPlan {
  id: 'monthly' | 'annual';
  label: string;
  price: number;
  currency: string;
}

export interface PremiumStatus {
  is_premium: boolean;
  plan: 'monthly' | 'annual' | null;
  expires_at: string | null;
  days_remaining: number | null;
  pending_subscription: { id: string; plan: string; status: string } | null;
}

export interface PremiumOffer {
  slots_total: number;
  slots_left: number;
  days: number;
  my_status: 'pending' | 'granted' | 'rejected' | null;
}

@Injectable({ providedIn: 'root' })
export class PremiumService {
  private api = inject(ApiService);

  getPlans(): Observable<{ plans: PremiumPlan[] }> {
    return this.api.get('premium/plans');
  }

  getStatus(): Observable<PremiumStatus> {
    return this.api.get('premium/status');
  }

  subscribe(plan: 'monthly' | 'annual', paymentMethod: string = 'wave'): Observable<{ payment_url: string }> {
    return this.api.post('premium/subscribe', { plan, payment_method: paymentMethod });
  }

  getOffer(): Observable<PremiumOffer> {
    return this.api.get('premium/offer');
  }

  applyOffer(): Observable<{ message: string; my_status: string }> {
    return this.api.post('premium/offer/apply', {});
  }
}
