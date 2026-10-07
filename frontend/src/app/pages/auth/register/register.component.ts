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
  email = '';
  password = '';
  passwordConfirm = '';
  acceptTerms = false;
  loading = signal(false);
  error = signal('');

  register() {
    if (!this.fullName || !this.username || !this.email.trim() || !this.password) {
      this.error.set('Veuillez remplir tous les champs.');
      return;
    }
    if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(this.email.trim())) {
      this.error.set('Adresse e-mail invalide.');
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

    if (!this.acceptTerms) {
      this.error.set("Vous devez accepter les conditions d'utilisation et la politique de confidentialité.");
      return;
    }

    this.loading.set(true);
    this.error.set('');

    this.auth.register({
      full_name: this.fullName,
      username: this.username,
      email: this.email.trim(),
      password: this.password,
      password_confirmation: this.passwordConfirm,
      accept_terms: this.acceptTerms,
    }).subscribe({
      next: () => {
        this.loading.set(false);
        // L'e-mail est l'identifiant : pas de code a la creation du compte.
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
