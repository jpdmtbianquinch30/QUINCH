import { Component, inject, signal } from '@angular/core';
import { Router, RouterLink } from '@angular/router';
import { FormsModule } from '@angular/forms';
import { AuthService } from '../../../core/services/auth.service';
import { NotificationService } from '../../../core/services/notification.service';

@Component({
  selector: 'app-forgot-password',
  standalone: true,
  imports: [FormsModule, RouterLink],
  templateUrl: './forgot-password.component.html',
  styleUrl: './forgot-password.component.scss',
})
export class ForgotPasswordComponent {
  private auth = inject(AuthService);
  private notify = inject(NotificationService);
  private router = inject(Router);

  method = signal<'sms' | 'email'>('sms');
  step = signal<'request' | 'reset'>('request');
  loading = signal(false);

  phoneNumber = '';
  email = '';
  otp = '';
  password = '';
  passwordConfirmation = '';

  /** Même format que la connexion : le backend exige +221XXXXXXXXX (sans espaces). */
  private normalizedPhone(): string {
    const raw = this.phoneNumber.replace(/\s/g, '');
    return raw.startsWith('+221') ? raw : '+221' + raw;
  }

  /** Envoie le code SMS (utilisé par les deux méthodes : SMS et e-mail). */
  requestOtp() {
    if (!this.phoneNumber.trim()) {
      this.notify.error('Veuillez saisir votre numéro de téléphone.');
      return;
    }
    this.loading.set(true);
    this.auth.forgotPassword(this.normalizedPhone()).subscribe({
      next: (res: any) => {
        this.loading.set(false);
        this.notify.success(res.message);
        this.step.set('reset');
        this.otp = '';
        if (res.demo_otp) {
          this.notify.info(`Code de démonstration (local) : ${res.demo_otp}`);
        }
      },
      error: (err: any) => {
        this.loading.set(false);
        const errors = err.error?.errors;
        this.notify.error(
          errors ? Object.values(errors).flat().join(' ') : (err.error?.message || 'Erreur lors de la demande.')
        );
      },
    });
  }

  /** Revenir saisir un autre numéro (faute de frappe). */
  changeNumber() {
    this.step.set('request');
    this.otp = '';
  }

  /** Validation commune avant d'envoyer le nouveau mot de passe. */
  private passwordsValid(): boolean {
    if (this.password.length < 8 || !/[a-z]/.test(this.password) || !/[A-Z]/.test(this.password) || !/\d/.test(this.password)) {
      this.notify.error('Le mot de passe doit faire 8 caractères minimum, avec une majuscule, une minuscule et un chiffre.');
      return false;
    }
    if (this.password !== this.passwordConfirmation) {
      this.notify.error('Les mots de passe ne correspondent pas.');
      return false;
    }
    return true;
  }

  resetWithOtp() {
    if (this.otp.length !== 6) {
      this.notify.error('Le code doit contenir 6 chiffres.');
      return;
    }
    if (!this.passwordsValid()) return;
    this.loading.set(true);
    this.auth.resetPassword(this.normalizedPhone(), this.otp, this.password, this.passwordConfirmation).subscribe({
      next: (res: any) => {
        this.loading.set(false);
        this.notify.success(res.message);
        this.router.navigate(['/auth/login']);
      },
      error: (err: any) => {
        this.loading.set(false);
        this.notify.error(err.error?.message || 'Code invalide ou expiré.');
      },
    });
  }

  /** Par e-mail : le code SMS reste obligatoire (l'e-mail est un 2ᵉ facteur, pas le seul). */
  resetWithEmail() {
    if (!this.email.trim()) {
      this.notify.error("Veuillez saisir l'e-mail associé au compte.");
      return;
    }
    if (this.otp.length !== 6) {
      this.notify.error('Le code doit contenir 6 chiffres.');
      return;
    }
    if (!this.passwordsValid()) return;
    this.loading.set(true);
    this.auth.resetPasswordByEmail(this.normalizedPhone(), this.email.trim(), this.otp, this.password, this.passwordConfirmation).subscribe({
      next: (res: any) => {
        this.loading.set(false);
        this.notify.success(res.message);
        this.router.navigate(['/auth/login']);
      },
      error: (err: any) => {
        this.loading.set(false);
        this.notify.error(err.error?.message || 'Les informations fournies ne correspondent à aucun compte.');
      },
    });
  }
}
