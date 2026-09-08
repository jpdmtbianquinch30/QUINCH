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

  requestOtp() {
    if (!this.phoneNumber.trim()) return;
    this.loading.set(true);
    this.auth.forgotPassword(this.phoneNumber.trim()).subscribe({
      next: (res: any) => {
        this.loading.set(false);
        this.notify.success(res.message);
        this.step.set('reset');
        if (res.demo_otp) {
          this.notify.info(`Code de démonstration (local) : ${res.demo_otp}`);
        }
      },
      error: (err: any) => {
        this.loading.set(false);
        this.notify.error(err.error?.message || 'Erreur lors de la demande.');
      },
    });
  }

  resetWithOtp() {
    if (!this.otp || !this.password || this.password !== this.passwordConfirmation) return;
    this.loading.set(true);
    this.auth.resetPassword(this.phoneNumber.trim(), this.otp, this.password, this.passwordConfirmation).subscribe({
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

  resetWithEmail() {
    if (!this.phoneNumber.trim() || !this.email.trim() || !this.password || this.password !== this.passwordConfirmation) return;
    this.loading.set(true);
    this.auth.resetPasswordByEmail(this.phoneNumber.trim(), this.email.trim(), this.password, this.passwordConfirmation).subscribe({
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
