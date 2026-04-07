import { Injectable, signal, computed } from '@angular/core';
import { Router } from '@angular/router';
import { ApiService } from './api.service';
import { User, AuthResponse, LoginRequest, RegisterRequest } from '../models/user.model';
import { Observable, tap, catchError, of } from 'rxjs';

@Injectable({ providedIn: 'root' })
export class AuthService {
  private currentUser = signal<User | null>(null);
  private token = signal<string | null>(null);

  user = this.currentUser.asReadonly();
  isAuthenticated = computed(() => !!this.token());
  isAdmin = computed(() => this.currentUser()?.role === 'admin' || this.currentUser()?.role === 'super_admin');
  isClient = computed(() => this.currentUser()?.role === 'user');

  constructor(private api: ApiService, private router: Router) {
    this.loadFromStorage();
  }

  register(data: RegisterRequest): Observable<AuthResponse> {
    return this.api.post<AuthResponse>('auth/register', data).pipe(
      tap(res => this.handleAuth(res))
    );
  }

  login(data: LoginRequest): Observable<AuthResponse> {
    return this.api.post<AuthResponse>('auth/login', data).pipe(
      tap(res => {
        this.handleAuth(res);
        // Show welcome notification after login
        this.showWelcomeNotification(res.user);
      })
    );
  }

  private showWelcomeNotification(user: User): void {
    // Small delay to let the app initialize
    setTimeout(() => {
      const name = user.full_name || user.username || '';
      const welcomeMsg = `Bienvenue sur Quinch, ${name}! Découvrez les dernières offres.`;
      // Store in sessionStorage to avoid showing multiple times
      if (!sessionStorage.getItem('quinch_welcomed')) {
        sessionStorage.setItem('quinch_welcomed', '1');
        // We'll dispatch a custom event that the notification service can pick up
        window.dispatchEvent(new CustomEvent('quinch:welcome', { detail: welcomeMsg }));
      }
    }, 1000);
  }

  logout(): void {
    this.api.post('auth/logout').subscribe({ error: () => {} });
    this.clearAuth();
    sessionStorage.removeItem('quinch_welcomed');
    this.router.navigate(['/auth/login']);
  }

  /** Force-clear auth state (used by error interceptor on 401) — no API call */
  forceLogout(): void {
    this.clearAuth();
    sessionStorage.removeItem('quinch_welcomed');
  }

  getMe(): Observable<{ user: User }> {
    return this.api.get<{ user: User }>('auth/me').pipe(
      tap(res => this.currentUser.set(res.user)),
      catchError(() => {
        this.clearAuth();
        return of({ user: null as any });
      })
    );
  }

  getToken(): string | null {
    return this.token();
  }

  /** Update the current user in memory + localStorage (after avatar/cover upload, etc.) */
  updateUser(user: User): void {
    this.currentUser.set(user);
    localStorage.setItem('quinch_user', JSON.stringify(user));
  }

  private handleAuth(res: AuthResponse): void {
    this.currentUser.set(res.user);
    this.token.set(res.token);
    localStorage.setItem('quinch_token', res.token);
    localStorage.setItem('quinch_user', JSON.stringify(res.user));
  }

  private clearAuth(): void {
    this.currentUser.set(null);
    this.token.set(null);
    localStorage.removeItem('quinch_token');
    localStorage.removeItem('quinch_user');
  }

  private loadFromStorage(): void {
    const token = localStorage.getItem('quinch_token');
    const userStr = localStorage.getItem('quinch_user');
    if (token && userStr) {
      try {
        this.token.set(token);
        const user = JSON.parse(userStr);
        this.currentUser.set(user);

        // Refresh user data from backend to get updated full URLs
        this.getMe().subscribe({
          next: (res) => {
            if (res.user) {
              this.currentUser.set(res.user);
              localStorage.setItem('quinch_user', JSON.stringify(res.user));
            }
          },
        });
      } catch {
        this.clearAuth();
      }
    }
  }
}
