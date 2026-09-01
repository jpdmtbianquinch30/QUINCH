import { Component, inject, signal } from '@angular/core';
import { FormsModule } from '@angular/forms';
import { Router, RouterLink } from '@angular/router';
import { AuthService } from '../../../core/services/auth.service';

@Component({
  selector: 'app-login',
  standalone: true,
  imports: [FormsModule, RouterLink],
  templateUrl: './login.component.html',
  styleUrl: './login.component.scss',
})
export class LoginComponent {
  private auth = inject(AuthService);
  private router = inject(Router);

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
}
