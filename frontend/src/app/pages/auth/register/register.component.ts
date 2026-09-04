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
  username = '';
  phoneNumber = '';
  password = '';
  passwordConfirm = '';
  loading = signal(false);
  error = signal('');

  register() {
    if (!this.fullName || !this.username || !this.phoneNumber || !this.password) {
      this.error.set('Veuillez remplir tous les champs.');
      return;
    }
    if (!/^[a-zA-Z0-9_]{3,30}$/.test(this.username)) {
      this.error.set("Le nom d'utilisateur doit faire 3 à 30 caractères (lettres, chiffres, _ uniquement).");
      return;
    }
    if (this.password !== this.passwordConfirm) {
      this.error.set('Les mots de passe ne correspondent pas.');
      return;
    }
    if (this.password.length < 8 || !/(?=.*[A-Z])(?=.*[0-9])/.test(this.password)) {
      this.error.set('Le mot de passe doit faire au moins 8 caractères, avec 1 majuscule et 1 chiffre.');
      return;
    }

    this.loading.set(true);
    this.error.set('');

    const phone = this.phoneNumber.startsWith('+221')
      ? this.phoneNumber
      : '+221' + this.phoneNumber.replace(/\s/g, '');

    this.auth.register({
      full_name: this.fullName,
      username: this.username,
      phone_number: phone,
      password: this.password,
      password_confirmation: this.passwordConfirm,
    }).subscribe({
      next: () => {
        this.loading.set(false);
        // Le telephone n'est pas encore verifie a ce stade (OTP envoye par
        // register() cote backend) : on passe par l'ecran de verification
        // avant l'onboarding, sinon phone_verified reste false a vie.
        this.router.navigate(['/auth/verify-otp']);
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
