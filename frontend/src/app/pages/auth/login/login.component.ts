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

  /** Un compte Google tout neuf n'a pas de numéro sénégalais : on le demande
   *  ici même, sans quitter l'écran (le backend renvoie `needs_phone`). */
  needsPhone = signal(false);
  googlePhone = '';

  phoneNumber = '';
  password = '';
  loading = signal(false);
  error = signal('');

  login() {
    if (!this.phoneNumber || !this.password) {
      this.error.set('Veuillez remplir tous les champs.');
      return;
    }

    this.loading.set(true);
    this.error.set('');

    // Prepend +221 prefix if not already present
    const phone = this.phoneNumber.startsWith('+221')
      ? this.phoneNumber
      : '+221' + this.phoneNumber.replace(/\s/g, '');

    this.auth.login({
      phone_number: phone,
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

  private loginWithGoogle(idToken: string): void {
    this.loading.set(true);
    this.error.set('');

    this.googleAuth.signIn(idToken).subscribe({
      next: (res) => {
        this.loading.set(false);

        // Un compte Google n'a ni numéro sénégalais ni pseudo QUINCH :
        // on complète le profil avant de laisser entrer dans l'app.
        if (res.needs_phone) {
          this.needsPhone.set(true);
          return;
        }

        this.redirectAfterLogin();
      },
      error: (err) => {
        this.loading.set(false);
        this.error.set(err.error?.message || 'Connexion Google impossible. Réessayez.');
      },
    });
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
    if (user && !user.phone_verified) {
      this.router.navigate(['/auth/verify-otp']);
      return;
    }
    if (user && !user.onboarding_completed) {
      this.router.navigate(['/onboarding']);
      return;
    }

    this.router.navigate(['/feed']);
  }

  /**
   * Étape 2 d'une première connexion Google : enregistrer le numéro de
   * téléphone. Le backend génère l'OTP dans la foulée, l'écran de
   * vérification prend ensuite le relais normalement.
   */
  submitGooglePhone(): void {
    const raw = this.googlePhone.replace(/\s/g, '');
    if (!raw) {
      this.error.set('Veuillez saisir votre numéro de téléphone.');
      return;
    }

    const phone = raw.startsWith('+221') ? raw : '+221' + raw;

    this.loading.set(true);
    this.error.set('');

    this.googleAuth.addPhone(phone).subscribe({
      next: (res: any) => {
        this.loading.set(false);
        if (res.user) this.auth.updateUser(res.user);
        this.router.navigate(['/auth/verify-otp']);
      },
      error: (err: any) => {
        this.loading.set(false);
        const errors = err.error?.errors;
        this.error.set(
          errors ? Object.values(errors).flat().join(' ')
                 : (err.error?.message || 'Numéro invalide.')
        );
      },
    });
  }
}
