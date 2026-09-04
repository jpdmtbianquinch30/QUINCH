import { Component, inject, signal } from '@angular/core';
import { FormsModule } from '@angular/forms';
import { Router } from '@angular/router';
import { AuthService } from '../../../core/services/auth.service';

@Component({
  selector: 'app-verify-otp',
  standalone: true,
  imports: [FormsModule],
  templateUrl: './verify-otp.component.html',
  styleUrl: './verify-otp.component.scss',
})
export class VerifyOtpComponent {
  private auth = inject(AuthService);
  private router = inject(Router);

  otp = '';
  loading = signal(false);
  resending = signal(false);
  error = signal('');
  info = signal('');

  // L'utilisateur est déjà authentifié à ce stade (le token est émis dès
  // /auth/register) : on lit son numéro depuis la session en cours, pas
  // besoin de le faire ressaisir.
  phoneNumber = this.auth.user()?.phone_number ?? '';

  constructor() {
    if (this.auth.user()?.phone_verified) {
      this.router.navigate(['/onboarding']);
    }
  }

  verify() {
    if (this.otp.length !== 6) {
      this.error.set('Le code doit contenir 6 chiffres.');
      return;
    }

    this.loading.set(true);
    this.error.set('');
    this.info.set('');

    this.auth.verifyOtp({ phone_number: this.phoneNumber, otp: this.otp }).subscribe({
      next: () => {
        this.loading.set(false);
        const user = this.auth.user();
        this.router.navigate([user?.onboarding_completed ? '/feed' : '/onboarding']);
      },
      error: (err) => {
        this.loading.set(false);
        this.error.set(err.error?.message || 'Code invalide ou expiré.');
      },
    });
  }

  resend() {
    this.resending.set(true);
    this.error.set('');
    this.info.set('');

    this.auth.resendOtp(this.phoneNumber).subscribe({
      next: (res) => {
        this.resending.set(false);
        this.info.set(
          res.demo_otp
            ? `Nouveau code envoyé (démo: ${res.demo_otp}).`
            : 'Un nouveau code a été envoyé par SMS.'
        );
      },
      error: () => {
        this.resending.set(false);
        this.error.set("Impossible d'envoyer un nouveau code pour le moment.");
      },
    });
  }
}
