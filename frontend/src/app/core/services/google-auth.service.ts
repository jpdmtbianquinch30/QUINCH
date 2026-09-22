import { Injectable, inject, signal } from '@angular/core';
import { Observable } from 'rxjs';
import { tap } from 'rxjs/operators';
import { ApiService } from './api.service';
import { AuthService } from './auth.service';
import { environment } from '../../../environments/environment';

/**
 * Connexion Google via Google Identity Services (GIS).
 *
 * Le SDK est chargé à la demande (et une seule fois) plutôt qu'inclus dans
 * index.html : inutile de pénaliser le chargement de toute l'application
 * pour un bouton qui n'apparaît que sur deux écrans.
 *
 * Côté backend, le token est vérifié par `POST api/v1/auth/google`
 * (GoogleAuthController) : audience, émetteur, expiration et e-mail vérifié.
 * Le frontend ne fait jamais confiance au profil renvoyé par le SDK.
 */

declare const google: any;

const GIS_SRC = 'https://accounts.google.com/gsi/client';

export interface GoogleAuthResult {
  message: string;
  user: any;
  token: string;
  is_new_user: boolean;
  needs_phone: boolean;
  needs_username: boolean;
}

@Injectable({ providedIn: 'root' })
export class GoogleAuthService {
  private api = inject(ApiService);
  private auth = inject(AuthService);

  private scriptPromise: Promise<void> | null = null;

  /** `false` si aucun GOOGLE_CLIENT_ID n'est configuré : on masque le bouton. */
  readonly isConfigured = signal<boolean>(!!environment.googleClientId);

  /**
   * Charge le SDK Google une seule fois pour toute la session.
   */
  private loadSdk(): Promise<void> {
    if (this.scriptPromise) return this.scriptPromise;

    this.scriptPromise = new Promise<void>((resolve, reject) => {
      if (typeof google !== 'undefined' && google?.accounts?.id) {
        resolve();
        return;
      }

      const existing = document.querySelector<HTMLScriptElement>(`script[src="${GIS_SRC}"]`);
      if (existing) {
        existing.addEventListener('load', () => resolve());
        existing.addEventListener('error', () => reject(new Error('Google SDK indisponible.')));
        return;
      }

      const script = document.createElement('script');
      script.src = GIS_SRC;
      script.async = true;
      script.defer = true;
      script.onload = () => resolve();
      script.onerror = () => reject(new Error('Google SDK indisponible.'));
      document.head.appendChild(script);
    });

    return this.scriptPromise;
  }

  /**
   * Affiche le bouton officiel Google dans le conteneur fourni.
   * `onCredential` reçoit l'ID token brut, à transmettre à `signIn()`.
   */
  async renderButton(container: HTMLElement, onCredential: (idToken: string) => void): Promise<void> {
    if (!environment.googleClientId) {
      throw new Error('GOOGLE_CLIENT_ID non configuré.');
    }

    await this.loadSdk();

    google.accounts.id.initialize({
      client_id: environment.googleClientId,
      callback: (response: { credential: string }) => onCredential(response.credential),
      // Pas de sélection automatique : l'utilisateur doit choisir
      // explicitement son compte à chaque connexion.
      auto_select: false,
      cancel_on_tap_outside: true,
    });

    google.accounts.id.renderButton(container, {
      theme: 'outline',
      size: 'large',
      width: container.offsetWidth || 320,
      text: 'continue_with',
      shape: 'pill',
      locale: 'fr',
    });
  }

  /**
   * Échange l'ID token Google contre une session QUINCH.
   */
  signIn(idToken: string): Observable<GoogleAuthResult> {
    return this.api.post<GoogleAuthResult>('auth/google', { id_token: idToken }).pipe(
      tap((res) => this.auth.applyGoogleSession(res.token, res.user))
    );
  }

/** Numéro de téléphone obligatoire après une première connexion Google. */
addPhone(phoneNumber: string): Observable<any> {
  return this.api.post('auth/google/add-phone', { phone_number: phoneNumber }).pipe(
    tap((res: any) => this.auth.lastDemoOtp.set(res.demo_otp ?? null))
  );
}

  updateUsername(username: string): Observable<any> {
    return this.api.post('auth/google/update-username', { username });
  }
}
