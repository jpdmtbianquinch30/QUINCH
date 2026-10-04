import { Component, OnInit, inject, signal } from '@angular/core';
import { DatePipe } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { ActivatedRoute, RouterLink } from '@angular/router';
import { AdminService } from '../../../core/services/admin.service';
import { NotificationService } from '../../../core/services/notification.service';
import { AdminModalComponent, ModalResult } from '../shared/admin-modal.component';
import { errMsg, fmtMoney, statusClass } from '../shared/admin-utils';

/** Transactions : liste filtrable, export CSV, fiche détaillée et résolution réelle des litiges (remboursement Wave inclus). */
@Component({
  selector: 'adm-transactions',
  standalone: true,
  imports: [DatePipe, FormsModule, RouterLink, AdminModalComponent],
  styleUrl: '../shared/admin-common.scss',
  template: `
  <div class="adm-page">
    <div class="adm-inline-form" style="margin-bottom:12px">
      <input class="adm-input" placeholder="Id ou référence de paiement…" [(ngModel)]="f.search" (keyup.enter)="load(1)" />
      <select class="adm-input" [(ngModel)]="f.payment_status" (change)="load(1)"><option value="">Paiement : tous</option><option value="pending">En attente</option><option value="completed">Payé</option><option value="failed">Échoué</option><option value="refunded">Remboursé</option></select>
      <select class="adm-input" [(ngModel)]="f.order_status" (change)="load(1)"><option value="">Commande : toutes</option><option value="disputed">En litige</option><option value="completed">Terminée</option><option value="cancelled">Annulée</option></select>
      <select class="adm-input" [(ngModel)]="f.payment_method" (change)="load(1)"><option value="">Moyen : tous</option><option value="wave">Wave</option><option value="orange_money">Orange Money</option></select>
      <input class="adm-input" type="date" [(ngModel)]="f.from" (change)="load(1)" /><input class="adm-input" type="date" [(ngModel)]="f.to" (change)="load(1)" />
      <button class="adm-btn" (click)="exportCsv()">Exporter CSV</button>
    </div>
    <div class="adm-table-wrap"><table class="adm-table">
      <thead><tr><th>Date</th><th>Produit</th><th>Acheteur → Vendeur</th><th>Montant</th><th>Paiement</th><th>Commande</th></tr></thead>
      <tbody>
        @for (t of items(); track t.id) {
          <tr class="clickable" (click)="open(t.id)">
            <td class="adm-sub">{{ t.created_at | date:'dd/MM HH:mm' }}</td><td>{{ t.product?.title || '—' }}</td>
            <td>{{ t.buyer?.full_name }} → {{ t.seller?.full_name }}</td><td><strong>{{ money(t.amount) }}</strong><div class="adm-sub">{{ t.payment_method }}</div></td>
            <td><span class="adm-chip" [class]="'adm-chip ' + sc(t.payment_status)">{{ t.payment_status }}</span></td>
            <td><span class="adm-chip" [class]="'adm-chip ' + sc(t.order_status)">{{ t.order_status }}</span></td>
          </tr>
        } @empty { <tr><td colspan="6" class="adm-empty">{{ loading() ? 'Chargement…' : 'Aucune transaction.' }}</td></tr> }
      </tbody></table></div>
    @if (last() > 1) { <div class="adm-pager"><button class="adm-btn sm" [disabled]="page() <= 1" (click)="load(page() - 1)">‹</button>Page {{ page() }} / {{ last() }}<button class="adm-btn sm" [disabled]="page() >= last()" (click)="load(page() + 1)">›</button></div> }
  </div>

  @if (detail(); as d) {
    <aside class="adm-drawer">
      <button class="adm-btn sm adm-drawer-close" (click)="detail.set(null)">Fermer ✕</button>
      <h3 style="margin-top:0">Transaction {{ d.transaction.id.slice(0, 8) }}</h3>
      <div class="adm-row"><span class="adm-chip" [class]="'adm-chip ' + sc(d.transaction.payment_status)">{{ d.transaction.payment_status }}</span><span class="adm-chip" [class]="'adm-chip ' + sc(d.transaction.order_status)">{{ d.transaction.order_status }}</span></div>
      <dl class="adm-kv" style="margin-top:12px">
        <dt>Montant</dt><dd>{{ money(d.transaction.amount) }} (commission {{ money(d.transaction.transaction_fee) }})</dd>
        <dt>Moyen</dt><dd>{{ d.transaction.payment_method }} · réf. {{ d.transaction.payment_gateway_id || '—' }}</dd>
        <dt>Produit</dt><dd>{{ d.transaction.product?.title }}</dd>
        <dt>Acheteur</dt><dd><a [routerLink]="['../users']" [queryParams]="{ open: d.transaction.buyer_id }">{{ d.transaction.buyer?.full_name }}</a> · {{ d.transaction.buyer?.phone_number }}</dd>
        <dt>Vendeur</dt><dd><a [routerLink]="['../users']" [queryParams]="{ open: d.transaction.seller_id }">{{ d.transaction.seller?.full_name }}</a> · {{ d.transaction.seller?.phone_number }}</dd>
        <dt>Créée</dt><dd>{{ d.transaction.created_at | date:'dd/MM/yyyy HH:mm' }}</dd>
      </dl>
      @if (d.transaction.order_status === 'disputed') {
        <div class="adm-section">Litige</div>
        <ul class="adm-timeline">@for (r of d.reports; track r.id) { <li>{{ r.reason }} — {{ r.description }} <span class="adm-sub">(par {{ r.reporter?.full_name }})</span></li> }</ul>
        @if (admin.can('disputes.resolve')) {
          <div class="adm-row" style="margin:10px 0">
            <button class="adm-btn sm" (click)="loadConv(d.transaction.id)">Lire la conversation</button>
            <button class="adm-btn sm danger" (click)="ask('refund')">Rembourser l'acheteur</button>
            <button class="adm-btn sm success" (click)="ask('release')">Libérer (valider)</button>
            <button class="adm-btn sm warn" (click)="ask('cancel')">Annuler sans remboursement</button>
          </div>
          @if (conv()) { <div class="adm-card" style="max-height:260px;overflow:auto">@for (m of conv(); track m.id) { <p style="margin:4px 0"><strong>{{ m.sender?.full_name }}</strong> <span class="adm-sub">{{ m.created_at | date:'dd/MM HH:mm' }}</span><br>{{ m.body }}</p> } @empty { <span class="adm-sub">Aucun message.</span> }</div>
            <p class="adm-sub">Cet accès est journalisé.</p> }
        } @else { <div class="adm-warn-box">Seul un super admin peut trancher un litige.</div> }
      }
      <div class="adm-section">Historique</div>
      <ul class="adm-timeline">@for (h of d.history; track h.id) { <li>{{ h.created_at | date:'dd/MM HH:mm' }} · <strong>{{ h.action }}</strong> par {{ h.admin?.full_name }}@if (h.metadata?.reason) { — {{ h.metadata.reason }} }</li> } @empty { <li>Aucune action.</li> }</ul>
    </aside>
  }

  @if (dlg(); as a) {
    <adm-modal [title]="a === 'refund' ? 'Rembourser via la passerelle de paiement' : a === 'release' ? 'Libérer la transaction' : 'Annuler la transaction'" [danger]="a === 'refund'"
      [needPassword]="true" [busy]="busy()" [error]="error()" [message]="a === 'refund' ? 'Le remboursement est exécuté chez Wave / Orange Money. Action irréversible.' : ''"
      (cancel)="dlg.set(null)" (confirm)="run($event)"></adm-modal>
  }`,
})
export class AdminTransactionsPage implements OnInit {
  admin = inject(AdminService);
  private notif = inject(NotificationService);
  private route = inject(ActivatedRoute);

  sc = statusClass; money = fmtMoney;
  f: { search: string; payment_status: string; order_status: string; payment_method: string; from: string; to: string } = { search: '', payment_status: '', order_status: '', payment_method: '', from: '', to: '' };
  items = signal<any[]>([]); loading = signal(true);
  page = signal(1); last = signal(1);
  detail = signal<any>(null); conv = signal<any[] | null>(null);
  dlg = signal<'refund' | 'release' | 'cancel' | null>(null);
  busy = signal(false); error = signal('');

  ngOnInit() {
    this.load(1);
    const id = this.route.snapshot.queryParamMap.get('open');
    if (id) this.open(id);
  }

  load(page: number) {
    this.loading.set(true);
    this.admin.getTransactions({ ...this.f, page }).subscribe({
      next: r => { this.items.set(r.data); this.page.set(r.current_page); this.last.set(r.last_page); this.loading.set(false); },
      error: e => { this.loading.set(false); this.notif.error(errMsg(e)); },
    });
  }

  open(id: string) { this.conv.set(null); this.admin.getTransaction(id).subscribe({ next: d => this.detail.set(d), error: e => this.notif.error(errMsg(e)) }); }
  loadConv(id: string) { this.admin.getDisputeConversation(id).subscribe({ next: r => this.conv.set(r.messages), error: e => this.notif.error(errMsg(e)) }); }
  ask(a: 'refund' | 'release' | 'cancel') { this.error.set(''); this.dlg.set(a); }

  run(res: ModalResult) {
    const id = this.detail().transaction.id; this.busy.set(true);
    this.admin.resolveDispute(id, this.dlg()!, res.reason, res.password).subscribe({
      next: () => { this.busy.set(false); this.dlg.set(null); this.notif.success('Litige tranché'); this.open(id); this.load(this.page()); },
      error: (e: any) => { this.busy.set(false); this.error.set(errMsg(e)); },
    });
  }

  exportCsv() {
    this.admin.exportTransactions(this.f).subscribe({ next: b => this.admin.saveBlob(b, 'quinch-transactions.csv'), error: () => this.notif.error('Export impossible') });
  }
}
