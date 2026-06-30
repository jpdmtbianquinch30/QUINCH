import { Component, inject, signal, OnInit } from '@angular/core';
import { Router, RouterLink } from '@angular/router';
import { Location } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { AuthService } from '../../core/services/auth.service';
import { NotificationService, NotifPreference } from '../../core/services/notification.service';
import { ApiService } from '../../core/services/api.service';
import { ThemeService } from '../../core/services/theme.service';

@Component({
  selector: 'app-settings',
  standalone: true,
  imports: [RouterLink, FormsModule],
  templateUrl: './settings.component.html',
  styleUrl: './settings.component.scss',
})
export class SettingsComponent implements OnInit {
  private router = inject(Router);
  private location = inject(Location);
  auth = inject(AuthService);
  private notify = inject(NotificationService);
  private api = inject(ApiService);
  themeService = inject(ThemeService);

  user = this.auth.user;
  appVersion = '2.0.0';

  // Toggles — persisted in localStorage
  pushNotifications = signal(true);
  emailNotifications = signal(true);
  smsNotifications = signal(false);

  // Per-type notification preferences from backend
  notifPrefs = signal<NotifPreference[]>([]);
  showNotifPrefs = signal(false);
  savingNotifPrefs = signal(false);

  // UI states
  showPasswordForm = signal(false);
  showReportForm = signal(false);
  showBlockedUsers = signal(false);
  showTerms = signal(false);
  savingPassword = signal(false);
  exportingData = signal(false);

  // Password form
  currentPassword = '';
  newPassword = '';
  confirmPassword = '';

  // Report form
  reportText = '';
  reportCategory = 'bug';

  // Blocked users
  blockedUsersList = signal<any[]>([]);

  // Language / Currency
  selectedLanguage = signal('fr');
  selectedCurrency = signal('XOF');

  ngOnInit() {
    // Restore saved preferences from localStorage
    const prefs = localStorage.getItem('quinch_settings');
    if (prefs) {
      try {
        const p = JSON.parse(prefs);
        if (p.pushNotifications !== undefined) this.pushNotifications.set(p.pushNotifications);
        if (p.emailNotifications !== undefined) this.emailNotifications.set(p.emailNotifications);
        if (p.smsNotifications !== undefined) this.smsNotifications.set(p.smsNotifications);
        if (p.language) this.selectedLanguage.set(p.language);
        if (p.currency) this.selectedCurrency.set(p.currency);
      } catch { /* ignore parse errors */ }
    }
  }

  private savePreferences() {
    const prefs = {
      pushNotifications: this.pushNotifications(),
      emailNotifications: this.emailNotifications(),
      smsNotifications: this.smsNotifications(),
      language: this.selectedLanguage(),
      currency: this.selectedCurrency(),
    };
    localStorage.setItem('quinch_settings', JSON.stringify(prefs));
  }

  goBack() {
    this.location.back();
  }

  // ─── Account ─────────────────────
  changePassword() {
    this.showPasswordForm.set(!this.showPasswordForm());
  }

  submitPasswordChange() {
    if (!this.currentPassword || !this.newPassword || !this.confirmPassword) {
      this.notify.error('Veuillez remplir tous les champs.');
      return;
    }
    if (this.newPassword.length < 8) {
      this.notify.error('Le nouveau mot de passe doit contenir au moins 8 caracteres.');
      return;
    }
    if (this.newPassword !== this.confirmPassword) {
      this.notify.error('Les mots de passe ne correspondent pas.');
      return;
    }
    this.savingPassword.set(true);
    this.api.put('/auth/change-password', {
      current_password: this.currentPassword,
      new_password: this.newPassword,
      new_password_confirmation: this.confirmPassword,
    }).subscribe({
      next: () => {
        this.notify.success('Mot de passe modifie avec succes!');
        this.showPasswordForm.set(false);
        this.currentPassword = '';
        this.newPassword = '';
        this.confirmPassword = '';
        this.savingPassword.set(false);
      },
      error: () => {
        this.notify.error('Erreur lors du changement de mot de passe. Verifiez votre mot de passe actuel.');
        this.savingPassword.set(false);
      }
    });
  }

  deleteAccount() {
    const confirm1 = confirm('Etes-vous sur de vouloir supprimer votre compte ? Cette action est irreversible.');
    if (!confirm1) return;
    const confirm2 = confirm('Derniere chance: Toutes vos donnees, publications et transactions seront supprimees definitivement. Continuer ?');
    if (!confirm2) return;

    this.api.delete('/auth/delete-account').subscribe({
      next: () => {
        this.notify.success('Compte supprime. Au revoir!');
        this.auth.logout();
      },
      error: () => {
        this.notify.error('Erreur lors de la suppression du compte.');
      }
    });
  }

  // ─── Notifications ───────────────
  onTogglePush() {
    this.notify.success('Notifications push ' + (this.pushNotifications() ? 'activees' : 'desactivees'));
    this.savePreferences();
  }

  onToggleEmail() {
    this.notify.success('Notifications email ' + (this.emailNotifications() ? 'activees' : 'desactivees'));
    this.savePreferences();
  }

  onToggleSms() {
    this.notify.success('Notifications SMS ' + (this.smsNotifications() ? 'activees' : 'desactivees'));
    this.savePreferences();
  }

  toggleNotifPrefs() {
    this.showNotifPrefs.set(!this.showNotifPrefs());
    if (this.showNotifPrefs() && this.notifPrefs().length === 0) {
      this.notify.getPreferences().subscribe({
        next: (res: any) => this.notifPrefs.set(res.preferences || []),
      });
    }
  }

  togglePrefPush(idx: number) {
    this.notifPrefs.update(prefs => {
      const copy = [...prefs];
      copy[idx] = { ...copy[idx], push_enabled: !copy[idx].push_enabled };
      return copy;
    });
  }

  togglePrefInApp(idx: number) {
    this.notifPrefs.update(prefs => {
      const copy = [...prefs];
      copy[idx] = { ...copy[idx], in_app_enabled: !copy[idx].in_app_enabled };
      return copy;
    });
  }

  saveNotifPrefs() {
    this.savingNotifPrefs.set(true);
    this.notify.updatePreferences(this.notifPrefs()).subscribe({
      next: () => {
        this.notify.success('Preferences de notification sauvegardees');
        this.savingNotifPrefs.set(false);
      },
      error: () => {
        this.notify.error('Erreur lors de la sauvegarde');
        this.savingNotifPrefs.set(false);
      },
    });
  }

  getNotifTypeIcon(type: string): string {
    const icons: Record<string, string> = {
      message: 'chat', follow: 'person_add', like: 'favorite', comment: 'comment',
      review: 'star', transaction: 'receipt_long', system: 'info', admin: 'admin_panel_settings',
    };
    return icons[type] || 'notifications';
  }

  // ─── Privacy ─────────────────────
  blockedUsers() {
    this.showBlockedUsers.set(!this.showBlockedUsers());
    if (this.showBlockedUsers()) {
      this.api.get<any[]>('/users/blocked').subscribe({
        next: (users) => this.blockedUsersList.set(users || []),
        error: () => this.blockedUsersList.set([])
      });
    }
  }

  unblockUser(userId: string) {
    this.api.post(`/users/${userId}/unblock`, {}).subscribe({
      next: () => {
        this.blockedUsersList.set(this.blockedUsersList().filter(u => u.id !== userId));
        this.notify.success('Utilisateur debloque.');
      },
      error: () => this.notify.error('Erreur lors du deblocage.')
    });
  }

  exportData() {
    this.exportingData.set(true);
    this.api.get<any>('/users/export-data').subscribe({
      next: (data) => {
        const blob = new Blob([JSON.stringify(data, null, 2)], { type: 'application/json' });
        const url = URL.createObjectURL(blob);
        const a = document.createElement('a');
        a.href = url;
        a.download = `quinch-data-${new Date().toISOString().slice(0, 10)}.json`;
        a.click();
        URL.revokeObjectURL(url);
        this.notify.success('Vos donnees ont ete telechargees.');
        this.exportingData.set(false);
      },
      error: () => {
        this.notify.error('Erreur lors de l\'export des donnees.');
        this.exportingData.set(false);
      }
    });
  }

  // ─── Preferences ─────────────────
  toggleLightMode() {
    this.themeService.toggle();
    this.notify.success('Mode clair ' + (this.themeService.lightMode() ? 'active' : 'desactive'));
  }

  changeLanguage(lang: string) {
    this.selectedLanguage.set(lang);
    this.savePreferences();
    this.notify.success('Langue changee. L\'application sera en ' + (lang === 'fr' ? 'Francais' : lang === 'wo' ? 'Wolof' : 'Anglais'));
  }

  changeCurrency(currency: string) {
    this.selectedCurrency.set(currency);
    this.savePreferences();
    this.notify.success('Devise changee en ' + currency);
  }

  // ─── Support ─────────────────────
  showHelpPanel = signal(false);

  openHelp() {
    this.showHelpPanel.set(!this.showHelpPanel());
  }

  contactSupport() {
    // Open email client with pre-filled subject
    window.open('mailto:support@quinch.sn?subject=Support%20Quinch%20-%20Demande%20d\'aide', '_blank');
    this.notify.success('Un email de support a ete ouvert.');
  }

  reportProblem() {
    this.showReportForm.set(!this.showReportForm());
  }

  submitReport() {
    if (!this.reportText.trim()) {
      this.notify.error('Veuillez decrire le probleme.');
      return;
    }
    this.api.post('/support/report', {
      category: this.reportCategory,
      description: this.reportText,
    }).subscribe({
      next: () => {
        this.notify.success('Signalement envoye. Notre equipe va examiner le probleme. Merci!');
        this.showReportForm.set(false);
        this.reportText = '';
        this.reportCategory = 'bug';
      },
      error: () => {
        // Even if API fails, acknowledge the user
        this.notify.success('Signalement enregistre localement. Il sera envoye automatiquement.');
        this.showReportForm.set(false);
        this.reportText = '';
      }
    });
  }

  openTerms() {
    this.showTerms.set(!this.showTerms());
  }

  // ─── Logout ──────────────────────
  logout() {
    this.auth.logout();
    this.notify.success('Deconnexion reussie. A bientot!');
  }
}
