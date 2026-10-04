import { Component, OnInit, inject, signal } from '@angular/core';
import { DatePipe } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { AdminService } from '../../../core/services/admin.service';
import { NotificationService } from '../../../core/services/notification.service';
import { AdminModalComponent, ModalResult } from '../shared/admin-modal.component';
import { ROLE_LABELS, errMsg, fmtMoney } from '../shared/admin-utils';

/** Équipe (rôles, charge par modérateur), abonnements Premium et modération des avis. */
@Component({
  selector: 'adm-team',
  standalone: true,
  imports: [DatePipe, FormsModule, AdminModalComponent],
  styleUrl: '../shared/admin-common.scss',
  template: `
  <div class="adm-page">
    <div class="adm-tabs">
      @if (admin.can('staff.manage')) { <button class="adm-tab" [class.active]="tab() === 'staff'" (click)="setTab('staff')">Équipe</button> }
      @if (admin.can('premium.manage')) { <button class="adm-tab" [class.active]="tab() === 'premium'" (click)="setTab('premium')">Premium</button> }
      @if (admin.can('reviews.moderate')) { <button class="adm-tab" [class.active]="tab() === 'reviews'" (click)="setTab('reviews')">Avis</button> }
    </div>

    @if (tab() === 'staff') {
      <p class="adm-muted">Pour nommer un membre : ouvrez sa fiche dans <strong>Utilisateurs</strong> puis « Changer le rôle ». Un super admin ne se crée que par la commande serveur <code>php artisan quinch:set-role</code>.</p>
      <div class="adm-table-wrap"><table class="adm-table"><thead><tr><th>Membre</th><th>Rôle</th><th>Statut</th><th>Actions (30 j)</th><th>Dossiers assignés</th><th>Dernière activité</th></tr></thead><tbody>
        @for (s of staff(); track s.id) { <tr><td><strong>{{ s.full_name }}</strong><div class="adm-sub">{{ s.phone_number }}</div></td><td><span class="adm-chip info">{{ roles[s.role] }}</span></td>
          <td><span class="adm-chip" [class.ok]="s.account_status === 'active'" [class.bad]="s.account_status !== 'active'">{{ s.account_status }}</span></td>
          <td>{{ s.actions_30d }}</td><td>{{ s.open_assigned }}</td><td class="adm-sub">{{ s.last_seen_at ? (s.last_seen_at | date:'dd/MM HH:mm') : '—' }}</td></tr>
        } @empty { <tr><td colspan="6" class="adm-empty">Aucun membre.</td></tr> }</tbody></table></div>
    }

    @if (tab() === 'premium') {
      @if (prem(); as p) {
        <div class="adm-grid" style="margin-bottom:14px"><div class="adm-card"><h4>Abonnés actifs</h4><div class="adm-big">{{ p.stats.active }}</div></div>
          <div class="adm-card"><h4>Expirent sous 7 jours</h4><div class="adm-big">{{ p.stats.expiring_7d }}</div></div><div class="adm-card"><h4>Paiements en attente</h4><div class="adm-big">{{ p.stats.pending }}</div></div></div>
        <div class="adm-row" style="margin-bottom:10px"><select class="adm-input inline" [(ngModel)]="pf" (change)="loadPremium()"><option value="">Tous</option><option value="active">Actifs</option><option value="expired">Expirés</option><option value="pending">En attente</option><option value="cancelled">Annulés</option></select>
          <label class="adm-muted"><input type="checkbox" [(ngModel)]="expiring" (change)="loadPremium()" /> Expirent bientôt</label></div>
        <div class="adm-table-wrap"><table class="adm-table"><thead><tr><th>Utilisateur</th><th>Plan</th><th>Montant</th><th>Statut</th><th>Début</th><th>Fin</th></tr></thead><tbody>
          @for (s of p.subscriptions.data; track s.id) { <tr><td>{{ s.user?.full_name }}</td><td>{{ s.plan }}{{ s.payment_method === 'admin_grant' ? ' (offert)' : '' }}</td><td>{{ money(s.amount) }}</td><td><span class="adm-chip" [class.ok]="s.status === 'active'">{{ s.status }}</span></td>
            <td class="adm-sub">{{ s.starts_at | date:'dd/MM/yy' }}</td><td class="adm-sub">{{ s.expires_at | date:'dd/MM/yy' }}</td></tr>
          } @empty { <tr><td colspan="6" class="adm-empty">Aucun abonnement.</td></tr> }</tbody></table></div>
        <p class="adm-sub">Pour offrir ou retirer un Premium : fiche utilisateur → « Offrir / Retirer Premium ».</p>
      }
    }

    @if (tab() === 'reviews') {
      <div class="adm-inline-form" style="margin-bottom:10px"><input class="adm-input" placeholder="Rechercher dans les commentaires…" [(ngModel)]="rs" (keyup.enter)="loadReviews()" />
        <select class="adm-input" [(ngModel)]="rr" (change)="loadReviews()"><option value="">Toutes notes</option>@for (n of [1,2,3,4,5]; track n) { <option [value]="n">{{ n }} ★</option> }</select></div>
      <div class="adm-table-wrap"><table class="adm-table"><thead><tr><th>Date</th><th>Auteur → Vendeur</th><th>Note</th><th>Commentaire</th><th></th></tr></thead><tbody>
        @for (r of reviews(); track r.id) { <tr><td class="adm-sub">{{ r.created_at | date:'dd/MM/yy' }}</td><td>{{ r.reviewer?.full_name }} → {{ r.seller?.full_name }}</td><td>{{ r.rating }} ★</td><td>{{ r.comment }}</td>
          <td><button class="adm-btn sm danger" (click)="target = r; error.set('')">Supprimer</button></td></tr>
        } @empty { <tr><td colspan="5" class="adm-empty">Aucun avis.</td></tr> }</tbody></table></div>
    }
  </div>

  @if (target) { <adm-modal title="Supprimer cet avis" [danger]="true" [busy]="busy()" [error]="error()" [presets]="['Insulte / propos haineux','Avis faux ou diffamatoire','Spam / publicité','Hors-sujet']" (cancel)="target = null" (confirm)="delReview($event)"></adm-modal> }`,
})
export class AdminTeamPage implements OnInit {
  admin = inject(AdminService);
  private notif = inject(NotificationService);

  roles = ROLE_LABELS; money = fmtMoney;
  tab = signal<'staff' | 'premium' | 'reviews'>('staff');
  staff = signal<any[]>([]); prem = signal<any>(null); reviews = signal<any[]>([]);
  pf = ''; expiring = false; rs = ''; rr = '';
  target: any = null; busy = signal(false); error = signal('');

  ngOnInit() {
    const first = this.admin.can('staff.manage') ? 'staff' : this.admin.can('premium.manage') ? 'premium' : 'reviews';
    this.setTab(first);
  }

  setTab(t: 'staff' | 'premium' | 'reviews') {
    this.tab.set(t);
    if (t === 'staff') this.admin.getStaff().subscribe(r => this.staff.set(r.staff));
    if (t === 'premium') this.loadPremium();
    if (t === 'reviews') this.loadReviews();
  }
  loadPremium() { this.admin.getPremium({ status: this.pf || null, expiring: this.expiring ? 1 : null }).subscribe(r => this.prem.set(r)); }
  loadReviews() { this.admin.getReviews({ search: this.rs || null, rating: this.rr || null }).subscribe(r => this.reviews.set(r.data)); }

  delReview(res: ModalResult) {
    this.busy.set(true);
    this.admin.deleteReview(this.target.id, res.reason).subscribe({
      next: () => { this.busy.set(false); this.target = null; this.notif.success('Avis supprimé'); this.loadReviews(); },
      error: e => { this.busy.set(false); this.error.set(errMsg(e)); },
    });
  }
}
