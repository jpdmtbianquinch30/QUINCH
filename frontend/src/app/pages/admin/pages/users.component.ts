import { Component, OnInit, computed, inject, signal } from '@angular/core';
import { DatePipe } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { ActivatedRoute, RouterLink } from '@angular/router';
import { AdminService } from '../../../core/services/admin.service';
import { NotificationService } from '../../../core/services/notification.service';
import { AdminModalComponent, ModalResult } from '../shared/admin-modal.component';
import { ROLE_LABELS, errMsg, fmtMoney, statusClass } from '../shared/admin-utils';

type Act = 'warn' | 'suspend' | 'lift' | 'ban' | 'unban' | 'delete' | 'role' | 'trust' | 'notify' | 'kyc' | 'grant' | 'revoke' | 'export' | 'badge';

/** Gestion des utilisateurs : liste paginée, fiche complète, sanctions avec motif, hiérarchie des rôles. */
@Component({
  selector: 'adm-users',
  standalone: true,
  imports: [DatePipe, FormsModule, RouterLink, AdminModalComponent],
  styleUrl: '../shared/admin-common.scss',
  template: `
  <div class="adm-page">
    <div class="adm-inline-form" style="margin-bottom:12px">
      <input class="adm-input" placeholder="Nom, téléphone, @username, email, id…" [(ngModel)]="f.search" (keyup.enter)="load(1)" />
      <select class="adm-input" [(ngModel)]="f.status" (change)="load(1)"><option value="">Tous statuts</option><option value="active">Actifs</option><option value="suspended">Suspendus</option><option value="banned">Bannis</option><option value="deactivated">Désactivés</option></select>
      <select class="adm-input" [(ngModel)]="f.role" (change)="load(1)"><option value="">Tous rôles</option><option value="user">Utilisateurs</option><option value="moderator">Modérateurs</option><option value="admin">Admins</option><option value="super_admin">Super admins</option></select>
      <select class="adm-input" [(ngModel)]="f.kyc" (change)="load(1)"><option value="">KYC : tous</option><option value="pending">En attente</option><option value="verified">Vérifiés</option><option value="rejected">Rejetés</option></select>
      <select class="adm-input" [(ngModel)]="f.premium" (change)="load(1)"><option value="">Premium : tous</option><option value="1">Premium actifs</option></select>
      <select class="adm-input" [(ngModel)]="f.sort" (change)="load(1)"><option value="created_at">Plus récents</option><option value="trust_score">Confiance</option><option value="last_seen_at">Dernière activité</option></select>
      <button class="adm-btn primary" (click)="load(1)">Rechercher</button>
    </div>

    <div class="adm-table-wrap"><table class="adm-table">
      <thead><tr><th>Utilisateur</th><th>Rôle</th><th>Statut</th><th>Confiance</th><th>Annonces</th><th>Avert.</th><th>Inscrit</th></tr></thead>
      <tbody>
        @for (u of items(); track u.id) {
          <tr class="clickable" (click)="open(u.id)">
            <td><strong>{{ u.full_name }}</strong><div class="adm-sub">{{ u.phone_number }}@if (u.username) { · &#64;{{ u.username }} }</div></td>
            <td><span class="adm-chip" [class.info]="u.role !== 'user'">{{ roles[u.role] }}</span></td>
            <td><span class="adm-chip" [class]="'adm-chip ' + sc(u.account_status)">{{ u.account_status }}</span>@if (u.suspended_until) { <div class="adm-sub">jusqu'au {{ u.suspended_until | date:'dd/MM HH:mm' }}</div> }</td>
            <td>{{ u.trust_score }}</td><td>{{ u.products_count }}</td>
            <td>@if (u.active_strikes_count) { <span class="adm-chip warn">{{ u.active_strikes_count }}</span> }</td>
            <td class="adm-sub">{{ u.created_at | date:'dd/MM/yy' }}</td>
          </tr>
        } @empty { <tr><td colspan="7" class="adm-empty">{{ loading() ? 'Chargement…' : 'Aucun utilisateur.' }}</td></tr> }
      </tbody></table></div>
    @if (last() > 1) { <div class="adm-pager"><button class="adm-btn sm" [disabled]="page() <= 1" (click)="load(page() - 1)">‹</button>Page {{ page() }} / {{ last() }} · {{ total() }} comptes<button class="adm-btn sm" [disabled]="page() >= last()" (click)="load(page() + 1)">›</button></div> }
  </div>

  @if (d(); as d) {
    <aside class="adm-drawer">
      <button class="adm-btn sm adm-drawer-close" (click)="detail.set(null)">Fermer ✕</button>
      <h3 style="margin-top:0">{{ d.user.full_name }}</h3>
      <div class="adm-row"><span class="adm-chip info">{{ roles[d.user.role] }}</span><span class="adm-chip" [class]="'adm-chip ' + sc(d.user.account_status)">{{ d.user.account_status }}</span>
        @if (d.user.is_premium) { <span class="adm-chip ok">Premium</span> }<span class="adm-chip">KYC {{ d.user.kyc_status }}</span><span class="adm-chip" [class.warn]="d.active_strikes > 0">{{ d.active_strikes }} avertissement(s)</span></div>
      <dl class="adm-kv" style="margin-top:12px">
        <dt>Téléphone</dt><dd>{{ d.user.phone_number }}</dd><dt>Email</dt><dd>{{ d.user.email || '—' }}</dd>
        <dt>Ville</dt><dd>{{ d.user.city || '—' }}</dd><dt>Confiance</dt><dd>{{ d.user.trust_score }}</dd>
        <dt>Inscrit</dt><dd>{{ d.user.created_at | date:'dd/MM/yyyy HH:mm' }}</dd><dt>Dernière activité</dt><dd>{{ d.user.last_seen_at ? (d.user.last_seen_at | date:'dd/MM/yyyy HH:mm') : '—' }}</dd>
        @if (d.user.suspended_until) { <dt>Suspendu jusqu'au</dt><dd>{{ d.user.suspended_until | date:'dd/MM/yyyy HH:mm' }} — {{ d.user.suspension_reason }}</dd> }
        @if (d.user.ban_reason) { <dt>Motif du ban</dt><dd>{{ d.user.ban_reason }}</dd> }
        <dt>Appareil partagé</dt><dd>{{ d.shared_device_count }} autre(s) compte(s) @for (a of d.shared_device_accounts; track a.id) { <a [routerLink]="[]" [queryParams]="{ open: a.id }" (click)="open(a.id)">{{ a.full_name }}</a>, }</dd>
      </dl>

      @if (d.can_manage) {
        <div class="adm-section">Actions</div>
        <div class="adm-row">
          @if (admin.can('users.warn')) { <button class="adm-btn sm warn" (click)="ask('warn')">Avertir</button> }
          @if (d.user.account_status === 'suspended') { <button class="adm-btn sm success" (click)="ask('lift')">Lever la suspension</button> }
          @else if (d.user.account_status === 'active' && admin.canAny('users.suspend','users.suspend_short')) { <button class="adm-btn sm warn" (click)="ask('suspend')">Suspendre…</button> }
          @if (d.user.account_status === 'banned') { @if (admin.can('users.ban')) { <button class="adm-btn sm success" (click)="ask('unban')">Débannir</button> } }
          @else if (admin.can('users.ban')) { <button class="adm-btn sm danger" (click)="ask('ban')">Bannir</button> }
          @if (admin.can('users.kyc')) { <button class="adm-btn sm" (click)="ask('kyc')">KYC</button> }
          @if (admin.can('users.trust')) { <button class="adm-btn sm" (click)="ask('trust')">Confiance</button> }
          @if (admin.can('users.notify')) { <button class="adm-btn sm" (click)="ask('notify')">Notifier</button> }
          @if (admin.can('users.badges')) { <button class="adm-btn sm" (click)="ask('badge')">Badge</button> }
          @if (admin.can('premium.manage')) { <button class="adm-btn sm" (click)="ask('grant')">Offrir Premium</button><button class="adm-btn sm" (click)="ask('revoke')">Retirer Premium</button> }
          @if (admin.can('staff.manage')) { <button class="adm-btn sm" (click)="ask('role')">Changer le rôle</button> }
          @if (admin.can('users.export')) { <button class="adm-btn sm" (click)="ask('export')">Export RGPD</button> }
          @if (admin.can('users.delete') && !d.user.anonymized_at) { <button class="adm-btn sm danger" (click)="ask('delete')">Supprimer le compte</button> }
        </div>
      } @else { <div class="adm-warn-box">Vous ne pouvez pas agir sur ce compte (rôle égal ou supérieur, ou votre propre compte).</div> }

      <div class="adm-section">Avertissements</div>
      <ul class="adm-timeline">@for (s of d.strikes; track s.id) { <li>{{ s.created_at | date:'dd/MM/yy' }} · {{ s.reason }} @if (s.revoked_at) { <span class="adm-chip">retiré</span> } @else if (d.can_manage && admin.can('users.warn')) { <button class="adm-btn sm" (click)="revokeStrike(s.id)">Retirer</button> }</li> } @empty { <li>Aucun.</li> }</ul>
      <div class="adm-section">Annonces récentes</div>
      <ul class="adm-timeline">@for (p of d.products; track p.id) { <li><a [routerLink]="['../products']" [queryParams]="{ open: p.id }">{{ p.title }}</a> · {{ p.deleted_at ? 'supprimée' : p.status }} · {{ money(p.price) }}</li> } @empty { <li>Aucune.</li> }</ul>
      <div class="adm-section">Transactions récentes</div>
      <ul class="adm-timeline">@for (t of d.transactions; track t.id) { <li>{{ t.created_at | date:'dd/MM/yy' }} · {{ money(t.amount) }} · {{ t.payment_status }} / {{ t.order_status }}</li> } @empty { <li>Aucune.</li> }</ul>
      <div class="adm-section">Signalements reçus / émis</div>
      <ul class="adm-timeline">@for (r of d.reports_received; track r.id) { <li>Reçu · {{ r.reason }} · {{ r.status }} — {{ r.reporter?.full_name }}</li> }@for (r of d.reports_made; track r.id) { <li>Émis · {{ r.reason }} · {{ r.status }}</li> } @empty { <li>Aucun.</li> }</ul>
      <div class="adm-section">Actions du staff sur ce compte</div>
      <ul class="adm-timeline">@for (h of d.admin_actions; track h.id) { <li>{{ h.created_at | date:'dd/MM/yy HH:mm' }} · <strong>{{ h.action }}</strong> par {{ h.admin?.full_name || 'Système' }}@if (h.metadata?.reason) { — {{ h.metadata.reason }} }</li> } @empty { <li>Aucune.</li> }</ul>
    </aside>
  }

  @if (dlg(); as a) {
    <adm-modal [title]="title(a)" [danger]="danger(a)" [needReason]="needReason(a)" [needPassword]="needPwd(a)" [busy]="busy()" [error]="error()" [message]="hint(a)" (cancel)="dlg.set(null)" (confirm)="run($event)">
      @switch (a) {
        @case ('suspend') { <label class="adm-label">Durée (jours){{ maxDays() < 365 ? ' — max ' + maxDays() + ' pour votre rôle' : ' — vide = indéfinie' }}</label>
          <input class="adm-input" type="number" min="1" [max]="maxDays()" [(ngModel)]="duration" /> }
        @case ('role') { <label class="adm-label">Nouveau rôle</label><select class="adm-input" [(ngModel)]="role"><option value="user">Utilisateur</option><option value="moderator">Modérateur</option><option value="admin">Administrateur</option></select>
          <div class="adm-warn-box">Le compte sera déconnecté et devra se reconnecter. « Super admin » ne s'attribue que par la commande serveur.</div> }
        @case ('trust') { <label class="adm-label">Score (0 à 1)</label><input class="adm-input" type="number" step="0.05" min="0" max="1" [(ngModel)]="trust" /> }
        @case ('kyc') { <label class="adm-label">Statut KYC</label><select class="adm-input" [(ngModel)]="kyc"><option value="verified">Vérifié</option><option value="rejected">Rejeté</option></select> }
        @case ('notify') { <label class="adm-label">Titre</label><input class="adm-input" [(ngModel)]="nTitle" /><label class="adm-label">Message</label><textarea class="adm-input" rows="3" [(ngModel)]="nBody"></textarea> }
        @case ('grant') { <label class="adm-label">Durée offerte (jours)</label><input class="adm-input" type="number" min="1" max="730" [(ngModel)]="days" /> }
        @case ('badge') { <label class="adm-label">Badge</label><select class="adm-input" [(ngModel)]="badge"><option value="verified">Vérifié</option><option value="top_seller">Top Vendeur</option><option value="fast_shipper">Livraison Express</option><option value="ambassador">Ambassadeur</option><option value="loyal_customer">Client Fidèle</option></select> }
      }
    </adm-modal>
  }`,
})
export class AdminUsersPage implements OnInit {
  admin = inject(AdminService);
  private notif = inject(NotificationService);
  private route = inject(ActivatedRoute);

  roles = ROLE_LABELS; sc = statusClass; money = fmtMoney;
  f: { search: string; status: string; role: string; kyc: string; premium: string; sort: string } = { search: '', status: '', role: '', kyc: '', premium: '', sort: 'created_at' };
  items = signal<any[]>([]); loading = signal(true);
  page = signal(1); last = signal(1); total = signal(0);
  detail = signal<any>(null);
  d = computed(() => this.detail());
  dlg = signal<Act | null>(null);
  busy = signal(false); error = signal('');
  duration: number | null = 7; role = 'moderator'; trust = 0.5; kyc = 'verified'; nTitle = ''; nBody = ''; days = 30; badge = 'verified';
  maxDays = computed(() => this.admin.can('users.suspend') ? 365 : (this.admin.me()?.moderator_max_suspension_days ?? 7));

  ngOnInit() {
    this.load(1);
    const id = this.route.snapshot.queryParamMap.get('open');
    if (id) this.open(id);
  }

  load(page: number) {
    this.loading.set(true);
    this.admin.getUsers({ ...this.f, page }).subscribe({
      next: r => { this.items.set(r.data); this.page.set(r.current_page); this.last.set(r.last_page); this.total.set(r.total); this.loading.set(false); },
      error: e => { this.loading.set(false); this.notif.error(errMsg(e)); },
    });
  }

  open(id: string) { this.admin.getUser(id).subscribe({ next: d => this.detail.set(d), error: e => this.notif.error(errMsg(e)) }); }
  private refresh() { const id = this.detail()?.user?.id; this.load(this.page()); if (id) this.open(id); }
  ask(a: Act) { this.error.set(''); this.duration = this.admin.can('users.suspend') ? 7 : Math.min(7, this.maxDays()); this.trust = this.detail().user.trust_score; this.dlg.set(a); }

  title(a: Act) { return ({ warn: 'Envoyer un avertissement', suspend: 'Suspendre le compte', lift: 'Lever la suspension', ban: 'Bannir définitivement', unban: 'Débannir le compte', delete: 'Supprimer le compte', role: 'Changer le rôle', trust: 'Ajuster la confiance', notify: 'Envoyer une notification', kyc: 'Statut KYC', grant: 'Offrir le Premium', revoke: 'Retirer le Premium', export: 'Export des données (RGPD)', badge: 'Attribuer un badge' } as any)[a]; }
  danger(a: Act) { return ['ban', 'delete', 'suspend', 'revoke'].includes(a); }
  needReason(a: Act) { return !['notify', 'export', 'badge'].includes(a); }
  needPwd(a: Act) { return ['ban', 'unban', 'delete', 'role', 'export'].includes(a); }
  hint(a: Act) { return a === 'delete' ? "Anonymisation : les données personnelles sont effacées, les transactions et signalements sont conservés pour les litiges." : a === 'warn' ? '3 avertissements actifs entraînent une suspension automatique.' : ''; }

  run(res: ModalResult) {
    const a = this.dlg()!; const u = this.detail().user; const id = u.id; const r = res.reason; const pw = res.password;
    this.busy.set(true);
    let req: any;
    switch (a) {
      case 'warn': req = this.admin.warnUser(id, r); break;
      case 'suspend': req = this.admin.suspendUser(id, r, this.duration || undefined); break;
      case 'lift': req = this.admin.liftSuspension(id, r); break;
      case 'ban': req = this.admin.banUser(id, r, pw); break;
      case 'unban': req = this.admin.unbanUser(id, r, pw); break;
      case 'delete': req = this.admin.deleteUser(id, r, pw); break;
      case 'role': req = this.admin.setRole(id, this.role, r, pw); break;
      case 'trust': req = this.admin.adjustTrust(id, this.trust, r); break;
      case 'kyc': req = this.admin.verifyKyc(id, this.kyc, r); break;
      case 'notify': req = this.admin.sendNotification(id, this.nTitle, this.nBody); break;
      case 'grant': req = this.admin.grantPremium(id, this.days, r); break;
      case 'revoke': req = this.admin.revokePremium(id, r); break;
      case 'badge': req = this.admin.awardBadge(id, this.badge); break;
      case 'export':
        this.admin.exportUser(id, pw).subscribe({
          next: b => { this.busy.set(false); this.dlg.set(null); this.admin.saveBlob(b, `quinch-user-${id}.json`); },
          error: async (e: any) => { this.busy.set(false); this.error.set(await this.blobError(e)); },
        });
        return;
    }
    req.subscribe({
      next: () => { this.busy.set(false); this.dlg.set(null); this.notif.success('Action effectuée'); this.refresh(); },
      error: (e: any) => { this.busy.set(false); this.error.set(errMsg(e)); },
    });
  }

  revokeStrike(strikeId: string) {
    this.admin.revokeStrike(this.detail().user.id, strikeId).subscribe({ next: () => { this.notif.success('Avertissement retiré'); this.refresh(); }, error: e => this.notif.error(errMsg(e)) });
  }

  private async blobError(e: any): Promise<string> {
    try { return JSON.parse(await e.error.text()).message ?? 'Erreur'; } catch { return 'Erreur'; }
  }
}
