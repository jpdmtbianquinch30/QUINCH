import { Injectable, inject, signal } from '@angular/core';
import { Observable, tap } from 'rxjs';
import { ApiService } from './api.service';

export interface RankingUserEntry {
  rank: number;
  anonymous: boolean;
  username?: string | null;
  full_name?: string | null;
  avatar_url?: string | null;
  total_amount?: number;
  sales_count?: number;
  purchases_count?: number;
  profile_views_count?: number;
  badges?: import('./badge.service').Badge[];
}

export interface RankingProductEntry {
  rank: number;
  product_id: string;
  product_slug: string;
  product_title: string;
  product_image?: string | null;
  view_count: number;
  anonymous: boolean;
  seller_username?: string | null;
  seller_name?: string | null;
}

export interface RankingPreferences {
  is_premium: boolean;
  ranking_opt_in: boolean;
  ranking_anonymous: boolean;
}

export type RankingKind = 'sellers' | 'buyers' | 'products' | 'profiles';

@Injectable({ providedIn: 'root' })
export class RankingService {
  private api = inject(ApiService);

  /** Preferences de l'utilisateur courant vis-a-vis des classements (chargees une fois, reutilisees partout). */
  preferences = signal<RankingPreferences | null>(null);

  getSellers(): Observable<{ month: string; ranking: RankingUserEntry[] }> {
    return this.api.get<{ month: string; ranking: RankingUserEntry[] }>('rankings/sellers');
  }

  getBuyers(): Observable<{ month: string; ranking: RankingUserEntry[] }> {
    return this.api.get<{ month: string; ranking: RankingUserEntry[] }>('rankings/buyers');
  }

  getProducts(): Observable<{ ranking: RankingProductEntry[] }> {
    return this.api.get<{ ranking: RankingProductEntry[] }>('rankings/products');
  }

  getProfiles(): Observable<{ ranking: RankingUserEntry[] }> {
    return this.api.get<{ ranking: RankingUserEntry[] }>('rankings/profiles');
  }

  /** Accessible meme hors Premium : sert a afficher l'ecran cadenas plutot qu'une 403 brute. */
  getPreferences(): Observable<RankingPreferences> {
    return this.api.get<RankingPreferences>('rankings/preferences').pipe(
      tap(res => this.preferences.set(res))
    );
  }

  updatePreferences(attrs: { opt_in: boolean; anonymous?: boolean }): Observable<{ ranking_opt_in: boolean; ranking_anonymous: boolean }> {
    return this.api.patch<{ ranking_opt_in: boolean; ranking_anonymous: boolean }>('rankings/preferences', attrs).pipe(
      tap(res => this.preferences.update(p => p ? { ...p, ...res } : p))
    );
  }
}
