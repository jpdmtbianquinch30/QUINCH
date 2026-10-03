import { Component, inject, signal } from '@angular/core';
import { FormsModule } from '@angular/forms';
import { Router } from '@angular/router';
import { AuthService } from '../../../core/services/auth.service';
import { GoogleAuthService } from '../../../core/services/google-auth.service';

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
  private phoneApi = inject(GoogleAuthService);

  otp = '';
  loading = signal(false);
  resending = signal(false);
  error = signal('');
  info = signal('');

  phoneNumber = this.auth.user()?.phone_number ?? '';

  /** Étape « numéro de téléphone » : affichée quand le compte n'a encore aucun
   *  numéro (1ère connexion Google, ou retour sur cet écran après avoir quitté
   *  l'app) ou quand l'utilisateur veut corriger une faute de frappe. */
  editingPhone = signal(!(this.auth.user()?.phone_number));
  newPhone = '';
  savingPhone = signal(false);

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

  /** Corriger / renseigner le numéro avant vérification (jamais pour un numéro déjà vérifié :
   *  le backend refuse, le changement passe alors par le profil). */
  startEditPhone() {
    this.error.set('');
    this.info.set('');
    this.newPhone = '';
    this.editingPhone.set(true);
  }

  cancelEditPhone() {
    // Impossible d'annuler tant qu'aucun numéro n'est enregistré.
    if (this.phoneNumber) this.editingPhone.set(false);
  }

  savePhone() {
    const raw = this.newPhone.replace(/\s/g, '');
    if (!raw) {
      this.error.set('Veuillez saisir votre numéro de téléphone.');
      return;
    }
    const phone = raw.startsWith('+221') ? raw : '+221' + raw;

    this.savingPhone.set(true);
    this.error.set('');
    this.info.set('');

    this.phoneApi.addPhone(phone).subscribe({
      next: (res: any) => {
        this.savingPhone.set(false);
        if (res.user) this.auth.updateUser(res.user);
        this.phoneNumber = phone;
        this.otp = '';
        this.editingPhone.set(false);
        this.info.set(
          res.demo_otp
            ? `Code envoyé à ${phone} (démo: ${res.demo_otp}).`
            : `Un code a été envoyé par SMS au ${phone}.`
        );
      },
      error: (err: any) => {
        this.savingPhone.set(false);
        const errors = err.error?.errors;
        this.error.set(
          errors ? Object.values(errors).flat().join(' ')
                 : (err.error?.message || "Impossible d'enregistrer ce numéro.")
        );
      },
    });
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
      error: (err: any) => {
        this.resending.set(false);
        // 429 : le backend indique combien de secondes attendre.
        this.error.set(err.status === 429
          ? (err.error?.message || 'Trop de demandes. Réessayez dans un instant.')
          : "Impossible d'envoyer un nouveau code pour le moment.");
      },
    });
  }
}
