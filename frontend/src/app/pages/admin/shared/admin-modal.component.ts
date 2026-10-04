import { Component, input, output, signal } from '@angular/core';
import { FormsModule } from '@angular/forms';

export interface ModalResult { reason: string; password: string; }

/**
 * Remplace les confirm() / prompt() natifs : vrai modal, motif obligatoire
 * (liste de motifs prédéfinis + champ libre) et, pour les actions sensibles,
 * ressaisie du mot de passe. Contenu additionnel via <ng-content>.
 */
@Component({
  selector: 'adm-modal',
  standalone: true,
  imports: [FormsModule],
  template: `
  <div class="adm-overlay" (click)="cancel.emit()">
    <div class="adm-modal" (click)="$event.stopPropagation()" role="dialog" aria-modal="true">
      <h3>{{ title() }}</h3>
      @if (message()) { <p class="adm-muted">{{ message() }}</p> }
      <ng-content />
      @if (presets().length) {
        <label class="adm-label">Motif prédéfini</label>
        <select class="adm-input" [ngModel]="preset()" (ngModelChange)="pickPreset($event)">
          <option value="">— Choisir —</option>
          @for (p of presets(); track p) { <option [value]="p">{{ p }}</option> }
        </select>
      }
      @if (needReason()) {
        <label class="adm-label">{{ presets().length ? 'Précision (obligatoire si aucun motif choisi)' : 'Motif (obligatoire)' }}</label>
        <textarea class="adm-input" rows="3" maxlength="500" [ngModel]="reason()" (ngModelChange)="reason.set($event)" placeholder="Expliquez la décision…"></textarea>
      }
      @if (needPassword()) {
        <label class="adm-label">Votre mot de passe (action sensible)</label>
        <input class="adm-input" type="password" autocomplete="current-password" [ngModel]="password()" (ngModelChange)="password.set($event)" />
      }
      @if (error()) { <div class="adm-error">{{ error() }}</div> }
      <div class="adm-actions">
        <button class="adm-btn" (click)="cancel.emit()" [disabled]="busy()">Annuler</button>
        <button class="adm-btn" [class.danger]="danger()" [class.primary]="!danger()" (click)="submit()" [disabled]="busy() || !valid()">
          {{ busy() ? 'En cours…' : confirmLabel() }}
        </button>
      </div>
    </div>
  </div>`,
  styleUrl: './admin-common.scss',
})
export class AdminModalComponent {
  title = input('Confirmer');
  message = input('');
  confirmLabel = input('Confirmer');
  danger = input(false);
  needReason = input(true);
  needPassword = input(false);
  presets = input<string[]>([]);
  busy = input(false);
  error = input('');

  confirm = output<ModalResult>();
  cancel = output<void>();

  reason = signal('');
  password = signal('');
  preset = signal('');

  pickPreset(v: string) {
    this.preset.set(v);
    if (v && !this.reason().trim()) this.reason.set(v);
  }

  valid() {
    if (this.needReason() && this.reason().trim().length < 3) return false;
    if (this.needPassword() && !this.password()) return false;
    return true;
  }

  submit() {
    if (!this.valid()) return;
    this.confirm.emit({ reason: this.reason().trim(), password: this.password() });
  }
}
