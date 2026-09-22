import { Injectable, signal, computed } from '@angular/core';
import { Router } from '@angular/router';
import { ApiService } from './api.service';
import { User, AuthResponse, LoginRequest, RegisterRequest, ResendOtpResponse, VerifyOtpRequest } from '../models/user.model';
import { Observable, tap, catchError, of } from 'rxjs';
import { environment } from '../../../environments/environment';

const TOKEN_KEY = 'quinch_token';
const USER_KEY = 'quinch_user';
// SEC-05 : horodatage de l'émission du jeton actuel, utilisé uniquement pour
// décider quand le rafraîchir proactivement — jamais envoyé au backend, qui
// est seul juge de l'expiration réelle (config('sanctum.expiration')).
const TOKEN_ISSUED_AT_KEY = 'quinch_token_issued_at';

@Injectable({ providedIn: 'root' })
export class AuthService {
  private currentUser = signal<User | null>(null);
  private token = signal<string | null>(null);
  // Code OTP de démo (environnements local/testing uniquement, voir
  // AuthController::register/resendOtp) : transite ici en mémoire le temps
  // que l'écran /auth/verify-otp puisse l'afficher directement, sans quoi
  // l'utilisateur n'a aucun moyen de voir son code sans cliquer "Renvoyer".
  lastDemoOtp = signal<string | null>(null);

  user = this.currentUser.asReadonly();
  isAuthenticated = computed(() => !!this.token());
  isAdmin = computed(() => this.currentUser()?.role === 'admin' || this.currentUser()?.role === 'super_admin');
  isClient = computed(() => this.currentUser()?.role === 'user');

  constructor(private api: ApiService, private router: Router) {
    this.loadFromStorage();

    // SEC-05 — Les jetons expirent désormais côté serveur (14 jours par
    // défaut, voir config/sanctum.php). Plutôt que d'attendre un 401 en
    // pleine utilisation (mauvaise expérience : une action perdue, un
    // formulaire à retaper), on prolonge la session en tâche de fond tant
    // que l'utilisateur reste actif — bien avant l'échéance réelle.
    //
    // Vérifié au démarrage (ci-dessus, via loadFromStorage) ET à intervalle
    // régulier tant que l'onglet reste ouvert : une session ouverte plusieurs
    // jours dans le même onglet, sans rechargement, doit aussi être couverte.
    setInterval(() => this.maybeRefreshToken(), 60 * 60 * 1000); // toutes les heures
  }

  register(data: RegisterRequest): Observable<AuthResponse> {
    return this.api.post<AuthResponse>('auth/register', data).pipe(
      tap(res => {
        this.handleAuth(res);
        this.lastDemoOtp.set(res.demo_otp ?? null);
      })
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

    /** Verify the OTP sent by SMS at registration. Does not issue a new
   *  token (already set by register()) — just refreshes phone_verified. */
  verifyOtp(data: VerifyOtpRequest): Observable<{ message: string; user: User }> {
    return this.api.post<{ message: string; user: User }>('auth/verify-otp', data).pipe(
      tap(res => {
        this.currentUser.set(res.user);
        localStorage.setItem(USER_KEY, JSON.stringify(res.user));
        this.lastDemoOtp.set(null);
      })
    );
  }

  /** Ask the backend for a fresh OTP (the previous one expires after 10 min). */
  resendOtp(phoneNumber: string): Observable<ResendOtpResponse> {
    return this.api.post<ResendOtpResponse>('auth/resend-otp', { phone_number: phoneNumber }).pipe(
      tap(res => this.lastDemoOtp.set(res.demo_otp ?? null))
    );
  }

  /** Force-clear auth state (used by error interceptor on 401) — no API call */
  forceLogout(): void {
    this.clearAuth();
    sessionStorage.removeItem('quinch_welcomed');
  }

    forgotPassword(phoneNumber: string): Observable<any> {
    return this.api.post('auth/forgot-password', { phone_number: phoneNumber });
  }

  resetPassword(phoneNumber: string, otp: string, password: string, passwordConfirmation: string): Observable<any> {
    return this.api.post('auth/reset-password', {
      phone_number: phoneNumber,
      otp,
      password,
      password_confirmation: passwordConfirmation,
    });
  }

  resetPasswordByEmail(phoneNumber: string, email: string, password: string, passwordConfirmation: string): Observable<any> {
    return this.api.post('auth/reset-password-email', {
      phone_number: phoneNumber,
      email,
      password,
      password_confirmation: passwordConfirmation,
    });
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
    localStorage.setItem(USER_KEY, JSON.stringify(user));
  }

  /**
   * Installe la session issue d'une connexion Google.
   *
   * La réponse de `auth/google` n'a pas la même forme que `AuthResponse`
   * (elle porte en plus `needs_phone` / `needs_username`), d'où ce point
   * d'entrée dédié plutôt qu'un cast forcé vers `handleAuth`.
   */
  applyGoogleSession(token: string, user: User): void {
    this.currentUser.set(user);
    this.token.set(token);
    localStorage.setItem(TOKEN_KEY, token);
    localStorage.setItem(USER_KEY, JSON.stringify(user));
    localStorage.setItem(TOKEN_ISSUED_AT_KEY, String(Date.now()));
    this.showWelcomeNotification(user);
  }

  /**
   * SEC-05 — Prolonge la session en tâche de fond si le jeton actuel
   * approche de son échéance côté serveur, sans attendre un 401.
   *
   * Ne connaît PAS la durée d'expiration exacte configurée côté backend
   * (`SANCTUM_TOKEN_EXPIRATION_MINUTES`) : les deux valeurs sont
   * volontairement indépendantes (voir config/sanctum.php). Ce seuil est
   * choisi confortablement plus court, pour qu'un utilisateur qui revient
   * au moins une fois par semaine ne voie jamais son jeton expirer. Un
   * jeton abandonné plus longtemps que ça expirera normalement côté
   * serveur — c'est précisément l'effet recherché par SEC-05.
   */
  private maybeRefreshToken(): void {
    const token = this.token();
    if (!token) return;

    const issuedAtRaw = localStorage.getItem(TOKEN_ISSUED_AT_KEY);

    // Session existante d'avant ce correctif, sans horodatage connu : on en
    // pose un maintenant plutôt que de rafraîchir immédiatement au hasard.
    if (!issuedAtRaw) {
      localStorage.setItem(TOKEN_ISSUED_AT_KEY, String(Date.now()));
      return;
    }

    const ageMinutes = (Date.now() - Number(issuedAtRaw)) / 60000;
    if (ageMinutes < environment.tokenRefreshThresholdMinutes) return;

    this.api.post<{ token: string; user: User }>('auth/refresh').subscribe({
      next: (res) => {
        this.token.set(res.token);
        localStorage.setItem(TOKEN_KEY, res.token);
        localStorage.setItem(TOKEN_ISSUED_AT_KEY, String(Date.now()));
        if (res.user) this.updateUser(res.user);
      },
      // Échec silencieux : si le jeton est déjà expiré, cet appel renverra
      // 401 et l'intercepteur d'erreurs se charge déjà de la déconnexion
      // propre. Pas besoin de dupliquer cette logique ici.
      error: () => {},
    });
  }

  private handleAuth(res: AuthResponse): void {
    this.currentUser.set(res.user);
    this.token.set(res.token);
    localStorage.setItem(TOKEN_KEY, res.token);
    localStorage.setItem(USER_KEY, JSON.stringify(res.user));
    localStorage.setItem(TOKEN_ISSUED_AT_KEY, String(Date.now()));
  }

  private clearAuth(): void {
    this.currentUser.set(null);
    this.token.set(null);
    localStorage.removeItem(TOKEN_KEY);
    localStorage.removeItem(USER_KEY);
    localStorage.removeItem(TOKEN_ISSUED_AT_KEY);
  }

  private loadFromStorage(): void {
    const token = localStorage.getItem(TOKEN_KEY);
    const userStr = localStorage.getItem(USER_KEY);
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
              localStorage.setItem(USER_KEY, JSON.stringify(res.user));
            }
          },
        });

        // SEC-05 : prolonge la session dès le démarrage si nécessaire,
        // plutôt que d'attendre la prochaine heure pleine.
        this.maybeRefreshToken();
      } catch {
        this.clearAuth();
      }
    }
  }
}
