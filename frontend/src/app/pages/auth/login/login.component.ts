import { AfterViewInit, Component, ElementRef, ViewChild, inject, signal } from '@angular/core';
import { FormsModule } from '@angular/forms';
import { Router, RouterLink } from '@angular/router';
import { AuthService } from '../../../core/services/auth.service';
import { GoogleAuthService } from '../../../core/services/google-auth.service';

@Component({
  selector: 'app-login',
  standalone: true,
  imports: [FormsModule, RouterLink],
  templateUrl: './login.component.html',
  styleUrl: './login.component.scss',
})
export class LoginComponent implements AfterViewInit {
  private auth = inject(AuthService);
  private router = inject(Router);
  private googleAuth = inject(GoogleAuthService);

  @ViewChild('googleBtn') googleBtn?: ElementRef<HTMLDivElement>;

  googleAvailable = this.googleAuth.isConfigured;

  email = '';
  password = '';
  loading = signal(false);
  error = signal('');

  // ─── Consentement Google (nouveau compte) ─────────────────────────────
  /** Jeton Google gardé en attente : aucun compte n'est créé avant l'acceptation explicite. */
  private pendingGoogleToken: string | null = null;
  showGoogleConsent = signal(false);
  googleTermsAccepted = false;

  login() {
    if (!this.email.trim() || !this.password) {
      this.error.set('Veuillez remplir tous les champs.');
      return;
    }

    this.loading.set(true);
    this.error.set('');

    this.auth.login({
      email: this.email.trim(),
      password: this.password,
    }).subscribe({
      next: (res) => {
        this.loading.set(false);

        // Redirection selon le rôle : admin vers le back-office, utilisateur
        // normal vers le feed (ou l'onboarding s'il ne l'a pas terminé).
        this.redirectAfterLogin();
      },
      error: (err) => {
        this.loading.set(false);
        // Laravel validation errors come in err.error.errors object
        const errors = err.error?.errors;
        if (errors) {
          this.error.set(Object.values(errors).flat().join(' '));
        } else {
          this.error.set(err.error?.message || 'Erreur de connexion. Vérifiez que le serveur est lancé.');
        }
      }
    });
  }

  // ─── Connexion Google ──────────────────────────────────────────────────

  async ngAfterViewInit(): Promise<void> {
    if (!this.googleAvailable() || !this.googleBtn) return;

    try {
      await this.googleAuth.renderButton(
        this.googleBtn.nativeElement,
        (idToken) => this.loginWithGoogle(idToken)
      );
    } catch {
      // SDK bloqué (réseau, bloqueur de pub, hors ligne) : on masque le
      // bouton au lieu d'afficher une zone vide inexplicable.
      this.googleAvailable.set(false);
    }
  }

  private loginWithGoogle(idToken: string, acceptTerms = false): void {
    this.loading.set(true);
    this.error.set('');

    this.googleAuth.signIn(idToken, acceptTerms).subscribe({
      next: () => {
        this.loading.set(false);
        this.cancelGoogleConsent();
        this.redirectAfterLogin();
      },
      error: (err) => {
        this.loading.set(false);

        if (err.error?.error === 'terms_required') {
          // Première connexion Google : aucun compte n'existe encore. On demande
          // l'acceptation explicite des conditions avant d'en créer un.
          this.pendingGoogleToken = idToken;
          this.googleTermsAccepted = false;
          this.showGoogleConsent.set(true);
          return;
        }

        this.cancelGoogleConsent();
        this.error.set(err.error?.message || 'Connexion Google impossible. Réessayez.');
      },
    });
  }

  /** L'utilisateur a coché la case et confirme : on renvoie le même jeton, cette fois avec son accord. */
  confirmGoogleConsent(): void {
    if (!this.googleTermsAccepted || !this.pendingGoogleToken) return;
    this.loginWithGoogle(this.pendingGoogleToken, true);
  }

  cancelGoogleConsent(): void {
    this.pendingGoogleToken = null;
    this.googleTermsAccepted = false;
    this.showGoogleConsent.set(false);
  }

  /**
   * Destination post-connexion, commune au mot de passe et à Google.
   */
  private redirectAfterLogin(): void {
    if (this.auth.isAdmin()) {
      this.router.navigate(['/admin']);
      return;
    }

    const user = this.auth.user();
    if (user && !user.onboarding_completed) {
      this.router.navigate(['/onboarding']);
      return;
    }

    this.router.navigate(['/feed']);
  }
}
