import { Injectable, signal, inject } from '@angular/core';
import { Observable, tap } from 'rxjs';
import { ApiService } from './api.service';

export interface Negotiation {
  id: string;
  buyer_id: string;
  seller_id: string;
  product_id: string;
  proposed_price: number;
  counter_price?: number;
  status: 'pending' | 'accepted' | 'rejected' | 'countered' | 'expired';
  buyer_message?: string;
  seller_message?: string;
  expires_at: string;
  product?: any;
  buyer?: any;
  seller?: any;
}

@Injectable({ providedIn: 'root' })
export class NegotiationService {
  private api = inject(ApiService);
  negotiations = signal<Negotiation[]>([]);

  propose(productId: string, proposedPrice: number, message?: string): Observable<any> {
    return this.api.post<any>('negotiations/propose', {
      product_id: productId,
      proposed_price: proposedPrice,
      message,
    });
  }

  respond(negotiationId: string, action: 'accept' | 'reject' | 'counter', counterPrice?: number, message?: string): Observable<any> {
    return this.api.post<any>(`negotiations/${negotiationId}/respond`, {
      action,
      counter_price: counterPrice,
      message,
    });
  }

  getMyNegotiations(): Observable<any> {
    return this.api.get<any>('negotiations').pipe(
      tap(res => this.negotiations.set(res.data || []))
    );
  }
}
