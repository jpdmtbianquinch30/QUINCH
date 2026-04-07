import { Injectable, signal } from '@angular/core';
import { Observable, tap } from 'rxjs';
import { ApiService } from './api.service';

export interface Badge {
  id: string;
  type: string;
  name: string;
  icon: string;
  color: string;
  level: string | null;
  reason: string | null;
  awarded_at: string;
  expires_at: string | null;
}

@Injectable({ providedIn: 'root' })
export class BadgeService {
  myBadges = signal<Badge[]>([]);

  constructor(private api: ApiService) {}

  getMyBadges(): Observable<any> {
    return this.api.get('my-badges').pipe(
      tap((res: any) => this.myBadges.set(res.badges || []))
    );
  }

  getUserBadges(userId: string): Observable<any> {
    return this.api.get(`users/${userId}/badges`);
  }

  getAllDefinitions(): Observable<any> {
    return this.api.get('badges/definitions');
  }
}
