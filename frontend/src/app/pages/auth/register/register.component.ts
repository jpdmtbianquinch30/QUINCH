import { Component, inject, signal } from '@angular/core';
import { FormsModule } from '@angular/forms';
import { Router, RouterLink } from '@angular/router';
import { AuthService } from '../../../core/services/auth.service';

@Component({
  selector: 'app-register',
  standalone: true,
  imports: [FormsModule, RouterLink],
  templateUrl: './register.component.html',
  styleUrl: './register.component.scss',
})
export class RegisterComponent {
  private auth = inject(AuthService);
  private router = inject(Router);

  fullName = '';
  phoneNumber = '';
  password = '';
  passwordConfirm = '';
  loading = signal(false);
  error = signal('');

  register() {
    if (!this.fullName || !this.phoneNumber || !this.password) {
      this.error.set('Veuillez remplir tous les champs.');
      return;
    }
    if (this.password !== this.passwordConfirm) {
      this.error.set('Les mots de passe ne correspondent pas.');
      return;
    }
    if (this.password.length < 6) {
      this.error.set('Le mot de passe doit contenir au moins 6 caractères.');
      return;
    }

    this.loading.set(true);
    this.error.set('');

    const phone = this.phoneNumber.startsWith('+221')
      ? this.phoneNumber
      : '+221' + this.phoneNumber.replace(/\s/g, '');

    this.auth.register({
      full_name: this.fullName,
      phone_number: phone,
      password: this.password,
      password_confirmation: this.passwordConfirm,
    }).subscribe({
      next: () => {
        this.loading.set(false);
        this.router.navigate(['/onboarding']);
      },
      error: (err) => {
        this.loading.set(false);
        const messages = err.error?.errors;
        if (messages) {
          this.error.set(Object.values(messages).flat().join(' '));
        } else {
          this.error.set(err.error?.message || 'Erreur lors de l\'inscription.');
        }
      }
    });
  }
}
