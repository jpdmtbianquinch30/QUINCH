import { Injectable, signal, inject } from '@angular/core';
import { Observable, tap } from 'rxjs';
import { ApiService } from './api.service';

export interface FavoriteItem {
  id: string;
  product_id: string;
  collection_id?: string;
  price_at_save: number;
  product: any;
  collection?: { id: string; name: string };
}

export interface FavoriteCollection {
  id: string;
  name: string;
  is_public: boolean;
  items_count: number;
}

@Injectable({ providedIn: 'root' })
export class FavoriteService {
  private api = inject(ApiService);
  favorites = signal<FavoriteItem[]>([]);
  collections = signal<FavoriteCollection[]>([]);
  count = signal(0);

  getFavorites(): Observable<any> {
    return this.api.get<any>('favorites').pipe(
      tap(res => this.favorites.set(res.data || []))
    );
  }

  toggleFavorite(productId: string, collectionId?: string): Observable<any> {
    return this.api.post<any>('favorites/toggle', { product_id: productId, collection_id: collectionId }).pipe(
      tap(res => { if (res.favorites_count !== undefined) this.count.set(res.favorites_count); })
    );
  }

  getCollections(): Observable<any> {
    return this.api.get<any>('favorites/collections').pipe(
      tap(res => this.collections.set(res.collections || []))
    );
  }

  createCollection(name: string, isPublic = false): Observable<any> {
    return this.api.post<any>('favorites/collections', { name, is_public: isPublic });
  }

  getCount(): Observable<any> {
    return this.api.get<any>('favorites/count').pipe(tap(res => this.count.set(res.count)));
  }
}
