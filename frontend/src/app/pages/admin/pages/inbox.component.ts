import { Component, OnInit, inject, signal, computed } from '@angular/core';
import { DatePipe } from '@angular/common';
import { Router, RouterLink } from '@angular/router';
import { FormsModule } from '@angular/forms';
import { AdminService } from '../../../core/services/admin.service';
import { NotificationService } from '../../../core/services/notification.service';
import { AdminModalComponent, ModalResult } from '../shared/admin-modal.component';
import { REASON_LABELS, errMsg, fmtMoney } from '../shared/admin-utils';

type Tab = 'all' | 'product_reports' | 'user_reports' | 'tickets' | 'appeals' | 'fraud';
type Dlg = { kind: 'product_report' | 'user_report' | 'ticket' | 'appeal' | 'fraud'; item: any } | null;

/** Boîte unique « À traiter » : signalements, tickets, litiges, fraude et contestations au même endroit. */
@Component({
  selector: 'adm-inbox',
  standalone: true,
  imports: [DatePipe, FormsModule, RouterLink, AdminModalComponent],
  styleUrl: '../shared/admin-common.scss',
  template: `
  <div class="adm-page">
    <div class="adm-tabs">
      @for (t of tabs; track t.key) {
        <button class="adm-tab" [class.active]="tab() === t.key" (click)="setTab(t.key)">{{ t.label }}
          @if (count(t.key) > 0) { <span class="adm-count">{{ count(t.key) }}</span> }</button>
      }
      <span style="flex:1"></span>
      <label class="adm-muted" style="align-self:center"><input type="checkbox" [(ngModel)]="mine" (change)="load()" /> Mes assignations</label>
    </div>

    @if (loading()) { <div class="adm-empty">Chargement…</div> }

    @if (!loading() && tab() === 'all') {
      @if (!inbox()?.items?.length) { <div class="adm-empty">🎉 Rien à traiter.</div> }
      <div class="adm-card" style="padding:0">
        @for (it of inbox()?.items; track it.type + it.id) {
          <div class="adm-list-item">
            <span class="adm-chip" [class.bad]="it.priority >= 3" [class.warn]="it.priority === 2">{{ typeLabel(it.type) }}</span>
            <div style="flex:1"><strong>{{ it.title }}</strong><div class="adm-sub">{{ it.subtitle }} · {{ it.created_at | date:'dd/MM HH:mm' }}</div></div>
            @if (it.type === 'dispute') { <a class="adm-btn sm" routerLink="../transactions" [queryParams]="{ open: it.id }">Ouvrir</a> }
            @else { <button class="adm-btn sm primary" (click)="openType(it.type)">Traiter</button> }
          </div>
        }
      </div>
    }

    <!-- Signalements annonces -->
    @if (!loading() && tab() === 'product_reports') {
      @for (r of productReports(); track r.id) {
        <div class="adm-card" style="margin-bottom:10px">
          <div class="adm-row">
            <span class="adm-chip bad">{{ reason(r.reason) }}</span>
            @if (r.group_total > 1) { <span class="adm-chip warn">{{ r.group_total }} signalements · {{ r.group_reporters }} comptes</span> }
            @if (r.product?.deleted_at) { <span class="adm-chip">supprimée</span> } @else if (r.product?.status === 'disabled') { <span class="adm-chip bad">masquée</span> }
            <span class="adm-sub" style="margin-left:auto">{{ r.created_at | date:'dd/MM HH:mm' }}</span>
          </div>
          <p><strong>{{ r.product?.title }}</strong></p>
          <p class="adm-muted">{{ r.description || 'Aucun détail.' }}<br>Signalé par {{ r.reporter?.full_name }} (confiance {{ r.reporter?.trust_score }}@if (r.reporter?.false_reports_count > 0) { , {{ r.reporter.false_reports_count }} faux signalement(s) }).</p>
          <div class="adm-row">
            <a class="adm-btn sm" routerLink="../products" [queryParams]="{ open: r.product_id }">Voir l'annonce</a>
            <button class="adm-btn sm primary" (click)="open('product_report', r)">Traiter</button>
            <button class="adm-btn sm" (click)="assignMe('product-report', r)">{{ r.assignee ? 'Assigné : ' + r.assignee.full_name : "M'assigner" }}</button>
          </div>
        </div>
      } @empty { <div class="adm-empty">Aucun signalement d'annonce en attente.</div> }
    }

    <!-- Signalements utilisateurs (inclut les litiges ouverts par un acheteur/vendeur) -->
    @if (!loading() && tab() === 'user_reports') {
      @for (r of userReports(); track r.id) {
        <div class="adm-card" style="margin-bottom:10px">
          <div class="adm-row"><span class="adm-chip bad">{{ reason(r.reason) }}</span>
            @if (r.group_total > 1) { <span class="adm-chip warn">{{ r.group_total }} signalements</span> }
            <span class="adm-sub" style="margin-left:auto">{{ r.created_at | date:'dd/MM HH:mm' }}</span></div>
          <p><strong>{{ r.reported_user?.full_name }}</strong> <span class="adm-chip">{{ r.reported_user?.account_status }}</span></p>
          <p class="adm-muted">{{ r.description || 'Aucun détail.' }}<br>Par {{ r.reporter?.full_name }}</p>
          <div class="adm-row">
            <a class="adm-btn sm" routerLink="../users" [queryParams]="{ open: r.reported_user_id }">Voir le profil</a>
            <button class="adm-btn sm primary" (click)="open('user_report', r)">Traiter</button>
            <button class="adm-btn sm" (click)="assignMe('user-report', r)">{{ r.assignee ? 'Assigné : ' + r.assignee.full_name : "M'assigner" }}</button>
          </div>
        </div>
      } @empty { <div class="adm-empty">Aucun signalement d'utilisateur en attente.</div> }
    }

    <!-- Tickets -->
    @if (!loading() && tab() === 'tickets') {
      @for (t of tickets(); track t.id) {
        <div class="adm-card" style="margin-bottom:10px">
          <div class="adm-row"><span class="adm-chip info">{{ t.category }}</span><span class="adm-sub" style="margin-left:auto">{{ t.created_at | date:'dd/MM HH:mm' }}</span></div>
          <p><strong>{{ t.user?.full_name }}</strong> <span class="adm-sub">{{ t.user?.phone_number }}</span></p>
          <p class="adm-muted">{{ t.description }}</p>
          <div class="adm-row"><button class="adm-btn sm primary" (click)="open('ticket', t)">Répondre / clôturer</button>
            <button class="adm-btn sm" (click)="assignMe('ticket', t)">{{ t.assignee ? 'Assigné : ' + t.assignee.full_name : "M'assigner" }}</button></div>
        </div>
      } @empty { <div class="adm-empty">Aucun ticket en attente.</div> }
    }

    <!-- Contestations -->
    @if (!loading() && tab() === 'appeals') {
      @for (a of appeals(); track a.id) {
        <div class="adm-card" style="margin-bottom:10px">
          <div class="adm-row"><span class="adm-chip warn">Contestation {{ a.target_type === 'video' ? 'vidéo' : 'annonce' }}</span><span class="adm-sub" style="margin-left:auto">{{ a.created_at | date:'dd/MM HH:mm' }}</span></div>
          <p><strong>{{ a.user?.full_name }}</strong> <span class="adm-sub">confiance {{ a.user?.trust_score }}</span></p>
          <p class="adm-muted">« {{ a.message }} »</p>
          <p class="adm-sub">Motif du retrait : {{ a.target?.moderation_reason || '—' }}</p>
          <div class="adm-row"><button class="adm-btn sm primary" (click)="open('appeal', a)">Décider</button></div>
        </div>
      } @empty { <div class="adm-empty">Aucune contestation en attente.</div> }
    }

    <!-- Fraude -->
    @if (!loading() && tab() === 'fraud') {
      @if (admin.can('fraud.handle')) { <div class="adm-row" style="margin-bottom:10px"><button class="adm-btn" (click)="scan()" [disabled]="scanning()">{{ scanning() ? 'Analyse…' : "Lancer l'analyse maintenant" }}</button><span class="adm-sub">L'analyse tourne aussi automatiquement toutes les heures.</span></div> }
      @for (f of fraud(); track f.id) {
        <div class="adm-card" style="margin-bottom:10px">
          <div class="adm-row"><span class="adm-chip bad">{{ f.detection_type }}</span><span class="adm-chip" [class.bad]="f.confidence_score >= 0.8" [class.warn]="f.confidence_score < 0.8">confiance {{ (f.confidence_score * 100).toFixed(0) }}%</span>
            <span class="adm-sub" style="margin-left:auto">{{ f.created_at | date:'dd/MM HH:mm' }}</span></div>
          <p><strong>{{ f.user?.full_name || 'Compte supprimé' }}</strong> <span class="adm-chip">{{ f.user?.account_status }}</span></p>
          <pre class="adm-sub" style="white-space:pre-wrap">{{ evidence(f) }}</pre>
          <div class="adm-row">
            @if (f.user_id) { <a class="adm-btn sm" routerLink="../users" [queryParams]="{ open: f.user_id }">Voir le compte</a> }
            <button class="adm-btn sm primary" (click)="open('fraud', f)">Décider</button></div>
        </div>
      } @empty { <div class="adm-empty">Aucune alerte de fraude en attente.</div> }
    }
  </div>

  @if (dlg(); as d) {
    <adm-modal
      [title]="dialogTitle(d.kind)" [danger]="act() !== 'none' && act() !== 'dismiss'" [confirmLabel]="'Valider'"
      [needReason]="needReason()" [busy]="busy()" [error]="error()"
      [presets]="d.kind === 'appeal' || d.kind === 'ticket' ? [] : presets"
      (cancel)="close()" (confirm)="submit($event)">
      @switch (d.kind) {
        @case ('product_report') {
          <label class="adm-label">Décision</label>
          <select class="adm-input" [(ngModel)]="status"><option value="resolved">Fondé — traité</option><option value="dismissed">Non fondé — classé</option></select>
          <label class="adm-label">Action</label>
          <select class="adm-input" [ngModel]="act()" (ngModelChange)="act.set($event)">
            <option value="none">Aucune action</option><option value="hide_product">Masquer l'annonce</option><option value="delete_product">Supprimer l'annonce</option>
            <option value="warn_seller">Avertir le vendeur</option><option value="suspend_seller">Suspendre le vendeur (7 j)</option></select>
          <label class="adm-label"><input type="checkbox" [(ngModel)]="resolveAll" /> Clore tous les signalements de cette annonce</label>
          <label class="adm-label"><input type="checkbox" [(ngModel)]="falseReport" /> Faux signalement (sanctionne le signaleur)</label>
        }
        @case ('user_report') {
          <label class="adm-label">Décision</label>
          <select class="adm-input" [(ngModel)]="status"><option value="resolved">Fondé — traité</option><option value="dismissed">Non fondé — classé</option></select>
          <label class="adm-label">Action sur le compte signalé</label>
          <select class="adm-input" [ngModel]="act()" (ngModelChange)="act.set($event)">
            <option value="none">Aucune action</option><option value="warn">Avertissement</option><option value="suspend">Suspension</option>
            @if (admin.can('users.ban')) { <option value="ban">Bannissement définitif</option> }</select>
          @if (act() === 'suspend') { <label class="adm-label">Durée (jours)</label><input class="adm-input" type="number" min="1" [max]="maxDays()" [(ngModel)]="duration" /> }
          <label class="adm-label"><input type="checkbox" [(ngModel)]="falseReport" /> Faux signalement</label>
        }
        @case ('ticket') {
          <label class="adm-label">Réponse à l'utilisateur (optionnel)</label>
          <textarea class="adm-input" rows="3" maxlength="1000" [(ngModel)]="reply"></textarea>
          <label class="adm-label">Statut</label>
          <select class="adm-input" [(ngModel)]="status"><option value="resolved">Résolu</option><option value="reviewed">Vu / en cours</option></select>
        }
        @case ('appeal') {
          <label class="adm-label">Décision</label>
          <select class="adm-input" [(ngModel)]="status"><option value="accepted">Accepter (rétablir le contenu)</option><option value="rejected">Refuser</option></select>
          <p class="adm-sub">Le texte ci-dessous est envoyé au vendeur.</p>
        }
        @case ('fraud') {
          <label class="adm-label">Décision</label>
          <select class="adm-input" [(ngModel)]="status"><option value="confirmed">Fraude confirmée</option><option value="dismissed">Fausse alerte</option></select>
          <label class="adm-label">Action</label>
          <select class="adm-input" [ngModel]="act()" (ngModelChange)="act.set($event)">
            <option value="none">Aucune</option><option value="warning">Avertissement</option><option value="payment_hold">Geler les paiements en cours</option>
            @if (admin.can('users.suspend')) { <option value="suspension">Suspension 7 j</option> }
            @if (admin.can('users.ban')) { <option value="ban">Bannissement</option> }</select>
        }
      }
    </adm-modal>
  }`,
})
export class AdminInboxPage implements OnInit {
  admin = inject(AdminService);
  private notif = inject(NotificationService);
  private router = inject(Router);

  tabs: { key: Tab; label: string }[] = [
    { key: 'all', label: 'Tout' }, { key: 'product_reports', label: 'Annonces' }, { key: 'user_reports', label: 'Utilisateurs' },
    { key: 'tickets', label: 'Tickets' }, { key: 'appeals', label: 'Contestations' }, { key: 'fraud', label: 'Fraude' },
  ];
  presets = ['Contenu interdit', 'Arnaque / fraude', 'Contrefaçon', 'Contenu inapproprié', 'Spam', 'Informations trompeuses'];

  tab = signal<Tab>('all');
  loading = signal(true);
  inbox = signal<any>(null);
  productReports = signal<any[]>([]);
  userReports = signal<any[]>([]);
  tickets = signal<any[]>([]);
  appeals = signal<any[]>([]);
  fraud = signal<any[]>([]);
  mine = false;

  dlg = signal<Dlg>(null);
  busy = signal(false);
  error = signal('');
  act = signal('none');
  status = 'resolved';
  resolveAll = true;
  falseReport = false;
  duration = 7;
  reply = '';

  maxDays = computed(() => this.admin.can('users.suspend') ? 365 : (this.admin.me()?.moderator_max_suspension_days ?? 7));
  needReason = computed(() => {
    const k = this.dlg()?.kind;
    if (k === 'appeal') return true;
    if (k === 'ticket') return false;
    return this.act() !== 'none';
  });

  ngOnInit() { this.load(); }

  count(t: Tab): number {
    const c = this.inbox()?.counts;
    if (!c) return 0;
    return ({ all: this.inbox().total, product_reports: c.product_reports, user_reports: c.user_reports, tickets: c.tickets, appeals: c.appeals, fraud: c.fraud } as any)[t] ?? 0;
  }

  setTab(t: Tab) { this.tab.set(t); this.load(); }
  openType(type: string) {
    const map: Record<string, Tab> = { product_report: 'product_reports', user_report: 'user_reports', ticket: 'tickets', appeal: 'appeals', fraud: 'fraud' };
    if (map[type]) this.setTab(map[type]);
  }

  load() {
    this.loading.set(true);
    const done = () => this.loading.set(false);
    switch (this.tab()) {
      case 'all': this.admin.getInbox('all', this.mine).subscribe({ next: r => { this.inbox.set(r); done(); }, error: done }); break;
      case 'product_reports': this.refreshCounts(); this.admin.getProductReports().subscribe({ next: r => { this.productReports.set(r.data); done(); }, error: done }); break;
      case 'user_reports': this.refreshCounts(); this.admin.getUserReports().subscribe({ next: r => { this.userReports.set(r.data); done(); }, error: done }); break;
      case 'tickets': this.refreshCounts(); this.admin.getTickets().subscribe({ next: r => { this.tickets.set(r.data); done(); }, error: done }); break;
      case 'appeals': this.refreshCounts(); this.admin.getAppeals().subscribe({ next: r => { this.appeals.set(r.data); done(); }, error: done }); break;
      case 'fraud': this.refreshCounts(); this.admin.getFraud().subscribe({ next: r => { this.fraud.set(r.data); done(); }, error: done }); break;
    }
  }

  private refreshCounts() { this.admin.getInbox('none', this.mine).subscribe({ next: r => this.inbox.set(r) }); }

  open(kind: NonNullable<Dlg>['kind'], item: any) {
    this.error.set(''); this.act.set('none'); this.reply = ''; this.falseReport = false; this.resolveAll = true; this.duration = 7;
    this.status = kind === 'appeal' ? 'accepted' : kind === 'fraud' ? 'confirmed' : 'resolved';
    this.dlg.set({ kind, item });
  }
  close() { this.dlg.set(null); }

  submit(res: ModalResult) {
    const d = this.dlg(); if (!d) return;
    this.busy.set(true); this.error.set('');
    const item = d.item; const reason = res.reason; let req: any;
    switch (d.kind) {
      case 'product_report':
        req = this.admin.resolveProductReport(item.id, { status: this.status, action: this.act(), reason, admin_notes: reason || undefined, false_report: this.falseReport, resolve_all: this.resolveAll }); break;
      case 'user_report':
        req = this.admin.resolveUserReport(item.id, { status: this.status, action: this.act(), reason, admin_notes: reason || undefined, duration: this.duration, false_report: this.falseReport }); break;
      case 'ticket':
        req = this.admin.resolveTicket(item.id, { status: this.status, reply: this.reply || undefined, admin_notes: reason || undefined }); break;
      case 'appeal':
        req = this.admin.handleAppeal(item.id, this.status as any, reason); break;
      case 'fraud':
        req = this.admin.resolveFraud(item.id, { status: this.status, action_taken: this.act(), reason: reason || undefined }); break;
    }
    req.subscribe({
      next: () => { this.busy.set(false); this.close(); this.notif.success('Décision enregistrée'); this.load(); },
      error: (e: any) => { this.busy.set(false); this.error.set(errMsg(e)); },
    });
  }

  assignMe(type: 'product-report' | 'user-report' | 'ticket', item: any) {
    this.admin.assign(type, item.id).subscribe({ next: () => { this.notif.success('Assigné'); this.load(); }, error: e => this.notif.error(errMsg(e)) });
  }

  scanning = signal(false);
  scan() {
    this.scanning.set(true);
    this.admin.runFraudScan().subscribe({
      next: r => { this.scanning.set(false); this.notif.success(r.message); this.load(); },
      error: e => { this.scanning.set(false); this.notif.error(errMsg(e)); },
    });
  }

  reason = (r: string) => REASON_LABELS[r] ?? r;
  evidence = (f: any) => JSON.stringify(f.evidence, null, 1);
  typeLabel(t: string) { return ({ product_report: 'Annonce', user_report: 'Utilisateur', ticket: 'Ticket', dispute: 'Litige', fraud: 'Fraude', appeal: 'Contestation' } as any)[t] ?? t; }
  dialogTitle(k: string) { return ({ product_report: 'Traiter le signalement', user_report: 'Traiter le signalement', ticket: 'Répondre au ticket', appeal: 'Décision sur la contestation', fraud: "Décision sur l'alerte" } as any)[k]; }
  money = fmtMoney;
}
