import { Component, OnDestroy, inject, signal } from '@angular/core';
import { Router, RouterLink } from '@angular/router';
import { FormsModule } from '@angular/forms';
import { AuthService } from '../../../core/services/auth.service';
import { NotificationService } from '../../../core/services/notification.service';

/** Délai avant de pouvoir redemander un code (le backend impose 60 s). */
const RESEND_DELAY_SECONDS = 60;

@Component({
  selector: 'app-forgot-password',
  standalone: true,
  imports: [FormsModule, RouterLink],
  templateUrl: './forgot-password.component.html',
  styleUrl: './forgot-password.component.scss',
})
export class ForgotPasswordComponent implements OnDestroy {
  private auth = inject(AuthService);
  private notify = inject(NotificationService);
  private router = inject(Router);

  step = signal<'request' | 'reset'>('request');
  loading = signal(false);
  /** Secondes restantes avant de pouvoir renvoyer le code (0 = possible). */
  cooldown = signal(0);

  email = '';
  otp = '';
  password = '';
  passwordConfirmation = '';

  private timer: ReturnType<typeof setInterval> | null = null;

  ngOnDestroy(): void {
    this.stopTimer();
  }

  private startCooldown(seconds: number = RESEND_DELAY_SECONDS): void {
    this.stopTimer();
    this.cooldown.set(seconds);
    this.timer = setInterval(() => {
      const next = this.cooldown() - 1;
      this.cooldown.set(Math.max(0, next));
      if (next <= 0) this.stopTimer();
    }, 1000);
  }

  private stopTimer(): void {
    if (this.timer) {
      clearInterval(this.timer);
      this.timer = null;
    }
  }

  /** Envoie (ou renvoie) le code par e-mail. */
  requestCode(): void {
    const email = this.email.trim();
    if (!email) {
      this.notify.error('Veuillez saisir votre adresse e-mail.');
      return;
    }

    this.loading.set(true);
    this.auth.forgotPassword(email).subscribe({
      next: (res: any) => {
        this.loading.set(false);
        this.notify.success(res.message);
        this.step.set('reset');
        this.otp = '';
        this.startCooldown();
        if (res.demo_otp) {
          this.notify.info(`Code de démonstration (test) : ${res.demo_otp}`);
        }
      },
      error: (err: any) => {
        this.loading.set(false);
        if (err.status === 429) {
          this.step.set('reset');
          this.startCooldown(err.error?.retry_after ?? RESEND_DELAY_SECONDS);
        }
        const errors = err.error?.errors;
        this.notify.error(
          errors ? Object.values(errors).flat().join(' ') : (err.error?.message || 'Erreur lors de la demande.')
        );
      },
    });
  }

  /** Revenir saisir une autre adresse (faute de frappe). */
  changeEmail(): void {
    this.step.set('request');
    this.otp = '';
    this.stopTimer();
    this.cooldown.set(0);
  }

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

  resetPassword(): void {
    if (this.otp.length !== 6) {
      this.notify.error('Le code doit contenir 6 chiffres.');
      return;
    }
    if (!this.passwordsValid()) return;

    this.loading.set(true);
    this.auth.resetPassword(this.email.trim(), this.otp, this.password, this.passwordConfirmation).subscribe({
      next: (res: any) => {
        this.loading.set(false);
        this.notify.success(res.message);
        this.router.navigate(['/auth/login']);
      },
      error: (err: any) => {
        this.loading.set(false);
        const errors = err.error?.errors;
        this.notify.error(
          errors ? Object.values(errors).flat().join(' ') : (err.error?.message || 'Code invalide ou expiré.')
        );
      },
    });
  }
}
