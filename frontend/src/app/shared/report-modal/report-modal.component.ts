import { Component, EventEmitter, Input, Output, inject, signal } from '@angular/core';
import { FormsModule } from '@angular/forms';
import { ApiService } from '../../core/services/api.service';
import { NotificationService } from '../../core/services/notification.service';

export type ReportKind = 'product' | 'user';

/**
 * Fenêtre de signalement unique, branchée sur l'admin :
 *  - kind="product" → POST products/{id}/report   (Admin > Modération > Signalements annonces)
 *  - kind="user"    → POST users/{id}/report      (Admin > Modération > Utilisateurs signalés)
 * Remplace les anciens boutons « Signaler » factices qui affichaient un toast
 * « Signalement envoyé » sans rien appeler côté serveur.
 */
@Component({
  selector: 'app-report-modal',
  standalone: true,
  imports: [FormsModule],
  template: `
    <div class="rm-overlay" (click)="close()">
      <div class="rm-box" (click)="$event.stopPropagation()" role="dialog" aria-modal="true">
        <div class="rm-head">
          <h2><span class="material-icons">flag</span> {{ title }}</h2>
          <button class="rm-x" type="button" (click)="close()" aria-label="Fermer"><span class="material-icons">close</span></button>
        </div>
        @if (subject) { <p class="rm-subject">{{ subject }}</p> }
        <label class="rm-label" for="rm-reason">Motif</label>
        <select id="rm-reason" class="rm-input" [(ngModel)]="reason">
          <option value="" disabled>Choisir un motif…</option>
          @for (r of reasons(); track r.v) { <option [value]="r.v">{{ r.l }}</option> }
        </select>
        <label class="rm-label" for="rm-desc">Détails (facultatif)</label>
        <textarea id="rm-desc" class="rm-input" rows="3" maxlength="1000" [(ngModel)]="description" placeholder="Précisez ce qui pose problème…"></textarea>
        <button class="rm-send" type="button" (click)="submit()" [disabled]="!reason || sending()">
          <span class="material-icons">{{ sending() ? 'hourglass_top' : 'send' }}</span>
          {{ sending() ? 'Envoi…' : 'Envoyer le signalement' }}
        </button>
        <p class="rm-hint">Notre équipe examine chaque signalement. Les signalements abusifs peuvent être sanctionnés.</p>
      </div>
    </div>
  `,
  styles: [`
    :host { display: contents; }
    .rm-overlay { position: fixed; inset: 0; z-index: 3000; background: rgba(2,6,23,.62); backdrop-filter: blur(6px);
      display: flex; align-items: flex-end; justify-content: center; padding: 0; }
    @media (min-width: 560px) { .rm-overlay { align-items: center; padding: 16px; } }
    .rm-box { width: 100%; max-width: 440px; max-height: 92dvh; overflow-y: auto; background: var(--q-bg-elevated, #14141f);
      color: var(--q-text-primary, #f3f4f6); border: 1px solid var(--q-border, rgba(255,255,255,.08));
      border-radius: 22px 22px 0 0; padding: 20px 20px calc(20px + env(safe-area-inset-bottom)); box-shadow: 0 24px 60px rgba(0,0,0,.45);
      animation: rm-in .22s ease-out; }
    @media (min-width: 560px) { .rm-box { border-radius: 22px; } }
    @keyframes rm-in { from { transform: translateY(24px); opacity: 0; } to { transform: none; opacity: 1; } }
    .rm-head { display: flex; align-items: center; justify-content: space-between; gap: 12px; margin-bottom: 8px; }
    .rm-head h2 { margin: 0; font-size: 1.05rem; font-weight: 800; display: flex; align-items: center; gap: 8px; }
    .rm-head h2 .material-icons { color: #f87171; font-size: 22px; }
    .rm-x { background: transparent; border: 0; color: inherit; opacity: .7; cursor: pointer; width: 36px; height: 36px; border-radius: 50%; display: grid; place-items: center; }
    .rm-x:hover { opacity: 1; background: rgba(127,127,127,.15); }
    .rm-subject { margin: 0 0 12px; font-size: .82rem; opacity: .65; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
    .rm-label { display: block; font-size: .75rem; font-weight: 700; letter-spacing: .02em; opacity: .7; margin: 12px 0 6px; }
    .rm-input { width: 100%; box-sizing: border-box; font: inherit; font-size: .92rem; color: inherit; background: var(--q-bg-input, rgba(255,255,255,.06));
      border: 1px solid var(--q-border, rgba(255,255,255,.1)); border-radius: 12px; padding: 11px 12px; outline: none; resize: vertical; }
    .rm-input:focus { border-color: var(--q-accent, #6366f1); box-shadow: 0 0 0 3px var(--q-accent-subtle, rgba(99,102,241,.2)); }
    .rm-send { width: 100%; margin-top: 16px; display: flex; align-items: center; justify-content: center; gap: 8px; border: 0; cursor: pointer;
      font: inherit; font-weight: 800; color: #fff; padding: 13px 16px; border-radius: 14px; background: linear-gradient(135deg, #ef4444, #f97316); }
    .rm-send:disabled { opacity: .45; cursor: not-allowed; }
    .rm-hint { margin: 12px 0 0; font-size: .72rem; opacity: .55; text-align: center; line-height: 1.4; }
  `],
})
export class ReportModalComponent {
  private api = inject(ApiService);
  private notify = inject(NotificationService);

  /** 'product' (annonce / vidéo) ou 'user' (profil vendeur). */
  @Input() kind: ReportKind = 'product';
  /** Identifiant de l'annonce ou de l'utilisateur signalé. */
  @Input({ required: true }) targetId!: string;
  /** Libellé affiché sous le titre (titre de l'annonce, @pseudo…). */
  @Input() subject = '';
  @Output() closed = new EventEmitter<void>();

  reason = '';
  description = '';
  sending = signal(false);

  get title(): string { return this.kind === 'user' ? 'Signaler ce profil' : 'Signaler cette annonce'; }

  reasons = () => this.kind === 'user'
    ? [
        { v: 'fraud', l: 'Fraude / arnaque' },
        { v: 'harassment', l: 'Harcèlement' },
        { v: 'impersonation', l: 'Usurpation d\'identité' },
        { v: 'inappropriate_content', l: 'Contenu inapproprié' },
        { v: 'spam', l: 'Spam' },
        { v: 'other', l: 'Autre' },
      ]
    : [
        { v: 'fraud', l: 'Fraude / arnaque' },
        { v: 'counterfeit', l: 'Contrefaçon' },
        { v: 'inappropriate', l: 'Contenu inapproprié' },
        { v: 'spam', l: 'Spam' },
        { v: 'other', l: 'Autre' },
      ];

  close() { this.closed.emit(); }

  submit() {
    if (!this.reason || this.sending() || !this.targetId) return;
    this.sending.set(true);
    const path = this.kind === 'user' ? `users/${this.targetId}/report` : `products/${this.targetId}/report`;
    this.api.post<any>(path, { reason: this.reason, description: this.description.trim() || undefined }).subscribe({
      next: (res) => {
        this.sending.set(false);
        this.notify.success(res?.message || 'Signalement envoyé. Merci !');
        this.close();
      },
      error: (err) => {
        this.sending.set(false);
        if (err?.status === 409) {
          this.notify.info(err?.error?.message || 'Vous avez déjà signalé ce contenu : il est en cours de traitement.');
          this.close();
        } else {
          this.notify.error(err?.error?.message || 'Impossible d\'envoyer le signalement.');
        }
      },
    });
  }
}
