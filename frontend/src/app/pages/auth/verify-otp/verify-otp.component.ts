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
  auth = inject(AuthService);
  private router = inject(Router);

  otp = '';
  loading = signal(false);
  resending = signal(false);
  error = signal('');
  info = signal('');

  phoneNumber = this.auth.user()?.phone_number ?? '';

  // Code de démo (environnements local/testing) transmis par register()/
  // resendOtp() via AuthService.lastDemoOtp. Avant ce fix, ce code n'était
  // jamais affiché sur cet écran : rien ne permettait de savoir qu'il fallait
  // cliquer sur "Renvoyer le code" pour le voir apparaître.
  demoOtp = this.auth.lastDemoOtp;

  constructor() {
    if (this.auth.user()?.phone_verified) {
      this.router.navigate(['/onboarding']);
    }
  }

  /** Pré-remplit le champ avec le code de démo (raccourci dev uniquement,
   *  n'existe que quand demoOtp() est non-null, cf. template). */
  fillDemoOtp() {
    const code = this.demoOtp();
    if (code) this.otp = code;
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
