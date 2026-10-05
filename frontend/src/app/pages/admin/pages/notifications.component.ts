import { Component, OnInit, inject, signal } from '@angular/core';
import { DatePipe } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { AdminService } from '../../../core/services/admin.service';
import { NotificationService } from '../../../core/services/notification.service';
import { AdminModalComponent, ModalResult } from '../shared/admin-modal.component';
import { errMsg } from '../shared/admin-utils';

/** Notifications de masse ou ciblées (tous, Premium, vendeurs, ville), avec modèles et historique. */
@Component({
  selector: 'adm-notifications',
  standalone: true,
  imports: [DatePipe, FormsModule, AdminModalComponent],
  styleUrl: '../shared/admin-common.scss',
  template: `
  <div class="adm-page">
    <div class="adm-card">
      <h4>Nouvelle notification</h4>
      @if (templates().length) {
        <label class="adm-label">Modèle</label>
        <select class="adm-input" (change)="applyTemplate($any($event.target).value)"><option value="">— Aucun —</option>@for (t of templates(); track t.name) { <option [value]="t.name">{{ t.name }}</option> }</select>
      }
      <label class="adm-label">Titre</label><input class="adm-input" maxlength="200" [(ngModel)]="title" />
      <label class="adm-label">Message</label><textarea class="adm-input" rows="3" maxlength="1000" [(ngModel)]="body"></textarea>
      <div class="adm-inline-form">
        <div><label class="adm-label">Audience</label>
          <select class="adm-input" [(ngModel)]="audience" (change)="count.set(null)"><option value="all">Tous les utilisateurs actifs</option><option value="premium">Abonnés Premium</option><option value="sellers">Vendeurs</option><option value="city">Une ville</option></select></div>
        @if (audience === 'city') { <div><label class="adm-label">Ville</label><input class="adm-input" [(ngModel)]="city" /></div> }
        <div><label class="adm-label">Lien (optionnel)</label><input class="adm-input" placeholder="/feed" [(ngModel)]="actionUrl" /></div>
      </div>
      <div class="adm-row" style="margin-top:14px">
        <button class="adm-btn" [disabled]="!valid()" (click)="preview()">Compter les destinataires</button>
        @if (count() !== null) { <span class="adm-chip info">{{ count() }} destinataire(s)</span> }
        <button class="adm-btn primary" [disabled]="!valid()" (click)="error.set(''); confirm.set(true)">Envoyer…</button>
      </div>
    </div>

    <div class="adm-section">Historique</div>
    <div class="adm-table-wrap"><table class="adm-table"><thead><tr><th>Date</th><th>Par</th><th>Titre</th><th>Audience</th><th>Destinataires</th></tr></thead><tbody>
      @for (h of history(); track h.id) { <tr><td class="adm-sub">{{ h.created_at | date:'dd/MM HH:mm' }}</td><td>{{ h.admin?.full_name }}</td><td>{{ h.metadata?.title }}</td><td>{{ h.metadata?.audience }} {{ h.metadata?.city }}</td><td>{{ h.metadata?.recipients }}</td></tr>
      } @empty { <tr><td colspan="5" class="adm-empty">Aucun envoi.</td></tr> }</tbody></table></div>
  </div>

  @if (confirm()) {
    <adm-modal title="Confirmer l'envoi" [message]="'Cette notification sera envoyée à tous les destinataires de l\\'audience choisie. Action irréversible.'" [needReason]="false" [needPassword]="true" confirmLabel="Envoyer" [busy]="busy()" [error]="error()" (cancel)="confirm.set(false)" (confirm)="send($event)"></adm-modal>
  }`,
})
export class AdminNotificationsPage implements OnInit {
  private admin = inject(AdminService);
  private notif = inject(NotificationService);

  title = ''; body = ''; audience = 'all'; city = ''; actionUrl = '';
  count = signal<number | null>(null);
  templates = signal<{ name: string; title: string; body: string }[]>([]);
  history = signal<any[]>([]);
  confirm = signal(false); busy = signal(false); error = signal('');

  ngOnInit() {
    // Modèles par défaut (les modèles enregistrés dans Réglages passent en premier).
    // Un envoi « Tous » apparaît en haut du feed de chaque utilisateur à sa prochaine visite.
    const defaults = [
      { name: 'Correction effectuée', title: 'Nous avons corrigé un problème 🛠️', body: 'Bonne nouvelle : le problème que vous nous avez signalé est corrigé. Merci pour votre patience !' },
      { name: 'Nouveauté', title: 'Nouveauté sur QUINCH ✨', body: 'Découvrez ce qui change dans l\'application. Touchez « Voir le détail » pour tout savoir.' },
    ];
    this.admin.getSettings().subscribe(r => {
      const saved = r.settings['notifications.templates']?.value ?? [];
      this.templates.set([...saved, ...defaults.filter(d => !saved.some((t: any) => t.name === d.name))]);
    });
    this.loadHistory();
  }

  loadHistory() { this.admin.getBroadcastHistory().subscribe(h => this.history.set(h)); }
  valid() { return this.title.trim().length > 0 && this.body.trim().length > 0 && (this.audience !== 'city' || this.city.trim().length > 0); }
  applyTemplate(name: string) { const t = this.templates().find(x => x.name === name); if (t) { this.title = t.title; this.body = t.body; } }

  private payload(extra: any = {}) {
    return { title: this.title.trim(), body: this.body.trim(), audience: this.audience, city: this.audience === 'city' ? this.city.trim() : null, action_url: this.actionUrl.trim() || null, ...extra };
  }

  preview() {
    this.admin.countAudience(this.audience, this.audience === 'city' ? this.city.trim() : null).subscribe({
      next: r => this.count.set(r.recipients), error: e => this.notif.error(errMsg(e)),
    });
  }

  send(res: ModalResult) {
    this.busy.set(true);
    this.admin.broadcast(this.payload({ admin_password: res.password })).subscribe({
      next: r => { this.busy.set(false); this.confirm.set(false); this.notif.success(r.message); this.title = ''; this.body = ''; this.count.set(null); this.loadHistory(); },
      error: e => { this.busy.set(false); this.error.set(errMsg(e)); },
    });
  }
}
