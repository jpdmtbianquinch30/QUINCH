import { Component, OnInit, inject, signal } from '@angular/core';
import { RouterLink } from '@angular/router';
import { AdminMetrics, AdminService } from '../../../core/services/admin.service';
import { fmtMoney, fmtNum } from '../shared/admin-utils';

@Component({
  selector: 'adm-dashboard',
  standalone: true,
  imports: [RouterLink],
  styleUrl: '../shared/admin-common.scss',
  template: `
  <div class="adm-page">
    @if (m(); as m) {
      <div class="adm-grid">
        <div class="adm-card"><h4>Utilisateurs</h4><div class="adm-big">{{ n(m.users.total) }}</div><div class="adm-sub">+{{ m.users.new_today }} aujourd'hui · {{ m.users.premium }} Premium</div></div>
        <div class="adm-card"><h4>Annonces actives</h4><div class="adm-big">{{ n(m.products.active) }}</div><div class="adm-sub">{{ m.products.hidden }} masquées · {{ m.products.sold }} vendues</div></div>
        <div class="adm-card"><h4>En ligne (5 min)</h4><div class="adm-big">{{ n(rt()?.active_users) }}</div><div class="adm-sub">basé sur la dernière activité</div></div>
        <div class="adm-card"><h4>Santé système</h4><div class="adm-big">{{ rt()?.system_health ?? '—' }}%</div>
          <div class="adm-sub">@for (c of checks(); track c[0]) { <span class="adm-chip" [class.ok]="c[1].ok" [class.bad]="!c[1].ok" [title]="c[1].detail">{{ c[0] }}</span> }</div></div>
      </div>

      <div class="adm-section"><span class="material-icons">inbox</span> À traiter</div>
      <div class="adm-grid">
        <a class="adm-card" routerLink="../inbox"><h4>Signalements annonces</h4><div class="adm-big">{{ m.moderation.reports }}</div></a>
        <a class="adm-card" routerLink="../inbox"><h4>Signalements utilisateurs</h4><div class="adm-big">{{ m.moderation.user_reports }}</div></a>
        <a class="adm-card" routerLink="../inbox"><h4>Tickets support</h4><div class="adm-big">{{ m.moderation.tickets }}</div></a>
        <a class="adm-card" routerLink="../inbox"><h4>Contestations</h4><div class="adm-big">{{ m.moderation.appeals }}</div></a>
        <a class="adm-card" routerLink="../inbox"><h4>Litiges</h4><div class="adm-big">{{ m.transactions.disputed }}</div></a>
        <a class="adm-card" routerLink="../inbox"><h4>Alertes fraude</h4><div class="adm-big">{{ m.security.fraud_alerts }}</div></a>
        <a class="adm-card" routerLink="../moderation"><h4>Vidéos à revoir</h4><div class="adm-big">{{ m.moderation.pending_videos }}</div><div class="adm-sub">{{ m.moderation.flagged_videos }} en vérification</div></a>
      </div>

      @if (admin.can('finance.view')) {
        <div class="adm-section"><span class="material-icons">payments</span> Finance (30 jours)</div>
        @if (fin(); as f) {
          <div class="adm-grid">
            <div class="adm-card"><h4>Revenu total</h4><div class="adm-big">{{ money(f.total_revenue) }}</div></div>
            <div class="adm-card"><h4>Commissions</h4><div class="adm-big">{{ money(f.commissions) }}</div></div>
            <div class="adm-card"><h4>Abonnements Premium</h4><div class="adm-big">{{ money(f.premium_revenue) }}</div><div class="adm-sub">{{ f.premium_subscriptions }} abonnement(s)</div></div>
            <div class="adm-card"><h4>Frais de publication</h4><div class="adm-big">{{ money(f.listing_fees) }}</div><div class="adm-sub">{{ f.listing_fees_count }} annonce(s)</div></div>
            <div class="adm-card"><h4>Volume échangé</h4><div class="adm-big">{{ money(f.gmv) }}</div></div>
            <div class="adm-card"><h4>Remboursé</h4><div class="adm-big">{{ money(f.refunded) }}</div></div>
          </div>
        }
      }

      <div class="adm-section"><span class="material-icons">show_chart</span> Activité
        <select class="adm-input inline" [value]="days()" (change)="setDays(+$any($event.target).value)"><option value="7">7 jours</option><option value="14">14 jours</option><option value="30">30 jours</option><option value="90">90 jours</option></select>
      </div>
      @if (overview(); as o) {
        <div class="adm-grid">
          @for (s of series; track s.key) {
            <div class="adm-card"><h4>{{ s.label }}</h4>
              <div class="adm-bars">@for (d of o.daily; track d.date) { <div class="bar" [style.height.%]="pct(o.daily, s.key, d[s.key])" [title]="d.date + ' : ' + d[s.key]"></div> }</div>
            </div>
          }
        </div>
      }
    } @else { <div class="adm-empty">Chargement…</div> }
  </div>`,
})
export class AdminDashboardPage implements OnInit {
  admin = inject(AdminService);
  m = signal<AdminMetrics | null>(null);
  rt = signal<any>(null);
  fin = signal<any>(null);
  overview = signal<any>(null);
  days = signal(14);
  checks = signal<[string, any][]>([]);
  series = [
    { key: 'users', label: 'Inscriptions' }, { key: 'products', label: 'Annonces' },
    { key: 'transactions', label: 'Transactions' },
  ];
  n = fmtNum; money = fmtMoney;

  ngOnInit() {
    this.admin.getMetrics().subscribe(m => this.m.set(m));
    this.admin.getRealTime().subscribe(r => { this.rt.set(r); this.checks.set(Object.entries(r.health_checks ?? {})); });
    if (this.admin.can('finance.view')) this.admin.getFinance(30).subscribe(f => this.fin.set(f));
    this.loadOverview();
  }

  setDays(d: number) { this.days.set(d); this.loadOverview(); }
  private loadOverview() {
    if (this.admin.can('audit.view')) this.admin.getOverview(this.days()).subscribe(o => this.overview.set(o));
  }
  pct(rows: any[], key: string, v: number) {
    const max = Math.max(1, ...rows.map(r => r[key]));
    return Math.max(2, (v / max) * 100);
  }
}
