import { Injectable, signal, computed, inject } from '@angular/core';
import { Observable, tap } from 'rxjs';
import { ApiService } from './api.service';

export interface CartItem {
  id: string;
  product_id: string;
  quantity: number;
  price_at_add: number;
  product: {
    id: string;
    title: string;
    slug: string;
    price: number;
    formatted_price: string;
    condition: string;
    status: string;
    type?: string;
    poster?: string;
    images?: string[];
    video?: { thumbnail: string };
    category?: { name: string };
    seller?: { id: string; full_name: string; username: string; avatar_url?: string };
    delivery_option?: string;   // 'fixed' | 'contact'
    delivery_fee?: number;      // F CFA
    payment_methods?: string[]; // e.g. ['orange_money', 'wave']
  };
}

@Injectable({ providedIn: 'root' })
export class CartService {
  private api = inject(ApiService);
  items = signal<CartItem[]>([]);
  count = signal(0);
  subtotal = signal(0);
  deliveryTotal = signal(0);
  total = signal(0);

  isEmpty = computed(() => this.items().length === 0);

  loadCart(): Observable<any> {
    return this.api.get<any>('cart').pipe(
      tap(res => {
        this.items.set(res.items || []);
        this.count.set(res.count || 0);
        this.subtotal.set(res.subtotal || 0);
        this.deliveryTotal.set(res.delivery_total || 0);
        this.total.set(res.total || 0);
      })
    );
  }

  addToCart(productId: string, quantity = 1): Observable<any> {
    return this.api.post<any>('cart/add', { product_id: productId, quantity }).pipe(
      tap(res => {
        this.count.set(res.cart_count);
        this.loadCart().subscribe();
      })
    );
  }

  updateQuantity(cartItemId: string, quantity: number): Observable<any> {
    return this.api.put<any>(`cart/${cartItemId}`, { quantity }).pipe(
      tap(() => this.loadCart().subscribe())
    );
  }

  removeItem(cartItemId: string): Observable<any> {
    return this.api.delete<any>(`cart/${cartItemId}`).pipe(
      tap(res => {
        this.count.set(res.cart_count);
        this.loadCart().subscribe();
      })
    );
  }

  clearCart(): Observable<any> {
    return this.api.delete<any>('cart').pipe(
      tap(() => {
        this.items.set([]);
        this.count.set(0);
        this.subtotal.set(0);
        this.deliveryTotal.set(0);
        this.total.set(0);
      })
    );
  }

  getCount(): Observable<any> {
    return this.api.get<any>('cart/count').pipe(tap(res => this.count.set(res.count)));
  }
}
