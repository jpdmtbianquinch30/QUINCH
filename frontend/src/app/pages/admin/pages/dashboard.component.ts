import { Component, OnInit, inject, signal } from '@angular/core';
import { DecimalPipe } from '@angular/common';
import { RouterLink } from '@angular/router';
import { AdminMetrics, AdminService } from '../../../core/services/admin.service';
import { fmtMoney, fmtNum } from '../shared/admin-utils';

@Component({
  selector: 'adm-dashboard',
  standalone: true,
  imports: [RouterLink, DecimalPipe],
  styleUrl: '../shared/admin-common.scss',
  template: `
  <div class="adm-page adm-dashboard">

    @if (m(); as m) {

      <!-- =====================================================
           KPI PRINCIPAUX
           ===================================================== -->

      <div class="adm-kpi-grid">

        <!-- UTILISATEURS -->
        <div class="adm-card adm-kpi-card adm-kpi-users">

          <div class="adm-kpi-top">
            <div>
              <h4>Utilisateurs</h4>
              <div class="adm-kpi-label">Utilisateurs inscrits</div>
            </div>

            <div class="adm-kpi-icon">
              <span class="material-icons">people</span>
            </div>
          </div>

          <div class="adm-kpi-value">
            {{ n(m.users.total) }}
          </div>

          <div class="adm-kpi-bottom">
            <span class="adm-trend positive">
              +{{ n(m.users.new_today) }}
            </span>

            <span>aujourd'hui</span>

            <span class="adm-kpi-separator">·</span>

            <span>{{ n(m.users.premium) }} Premium</span>
          </div>

          <div class="adm-progress">
            <span
              [style.width.%]="ratio(m.users.premium, m.users.total)">
            </span>
          </div>

        </div>


        <!-- ANNONCES -->
        <div class="adm-card adm-kpi-card adm-kpi-products">

          <div class="adm-kpi-top">
            <div>
              <h4>Annonces actives</h4>
              <div class="adm-kpi-label">Marketplace</div>
            </div>

            <div class="adm-kpi-icon">
              <span class="material-icons">inventory_2</span>
            </div>
          </div>

          <div class="adm-kpi-value">
            {{ n(m.products.active) }}
          </div>

          <div class="adm-kpi-bottom">
            <span>{{ n(m.products.hidden) }} masquées</span>
            <span class="adm-kpi-separator">·</span>
            <span>{{ n(m.products.sold) }} vendues</span>
          </div>

          <div class="adm-mini-stats">
            <span>
              <b>{{ n(m.products.active) }}</b>
              actives
            </span>

            <span>
              <b>{{ n(m.products.sold) }}</b>
              vendues
            </span>
          </div>

        </div>


        <!-- EN LIGNE -->
        <div class="adm-card adm-kpi-card adm-kpi-online">

          <div class="adm-kpi-top">
            <div>
              <h4>En ligne (5 min)</h4>
              <div class="adm-kpi-label">Activité en temps réel</div>
            </div>

            <div class="adm-live-icon">
              <span></span>
            </div>
          </div>

          <div class="adm-kpi-value">
            {{ n(rt()?.active_users) }}
          </div>

          <div class="adm-kpi-bottom">
            <span class="adm-live-text">● En activité</span>
            <span>dernière activité</span>
          </div>

          <div class="adm-live-line">
            <span></span>
            <span></span>
            <span></span>
            <span></span>
            <span></span>
            <span></span>
            <span></span>
          </div>

        </div>


        <!-- SANTÉ SYSTÈME -->
        <div class="adm-card adm-kpi-card adm-health-card">

          <div class="adm-kpi-top">

            <div>
              <h4>Santé système</h4>
              <div class="adm-kpi-label">État des services</div>
            </div>

            <div class="adm-kpi-icon">
              <span class="material-icons">monitor_heart</span>
            </div>

          </div>

          <div class="adm-health-content">

            <div
              class="adm-health-ring"
              [style.--health]="(rt()?.system_health ?? 0) + '%'">

              <div>
                <strong>{{ rt()?.system_health ?? '—' }}%</strong>
                <small>stable</small>
              </div>

            </div>

            <div class="adm-health-checks">

              @for (c of checks(); track c[0]) {

                <span
                  class="adm-health-check"
                  [class.ok]="c[1].ok"
                  [class.bad]="!c[1].ok"
                  [title]="c[1].detail">

                  <i></i>
                  {{ c[0] }}

                </span>

              }

            </div>

          </div>

        </div>

      </div>


      <!-- =====================================================
           À TRAITER
           ===================================================== -->

      <div class="adm-section adm-section-main">

        <span class="material-icons">inbox</span>

        <div>
          <strong>À traiter</strong>
          <small>Éléments nécessitant votre attention</small>
        </div>

      </div>


      <div class="adm-grid adm-action-grid">

        <a class="adm-card adm-action-card"
           routerLink="../inbox"
           [class.has-alert]="m.moderation.reports > 0">

          <div class="adm-action-icon">
            <span class="material-icons">report</span>
          </div>

          <div class="adm-action-content">
            <h4>Signalements annonces</h4>
            <div class="adm-action-value">
              {{ n(m.moderation.reports) }}
            </div>
            <div class="adm-sub">
              annonces signalées
            </div>
          </div>

          <span class="material-icons adm-arrow">
            arrow_forward
          </span>

        </a>


        <a class="adm-card adm-action-card"
           routerLink="../inbox"
           [class.has-alert]="m.moderation.user_reports > 0">

          <div class="adm-action-icon">
            <span class="material-icons">person_search</span>
          </div>

          <div class="adm-action-content">
            <h4>Signalements utilisateurs</h4>
            <div class="adm-action-value">
              {{ n(m.moderation.user_reports) }}
            </div>
            <div class="adm-sub">
              utilisateurs signalés
            </div>
          </div>

          <span class="material-icons adm-arrow">
            arrow_forward
          </span>

        </a>


        <a class="adm-card adm-action-card"
           routerLink="../inbox"
           [class.has-alert]="m.moderation.tickets > 0">

          <div class="adm-action-icon">
            <span class="material-icons">support_agent</span>
          </div>

          <div class="adm-action-content">
            <h4>Tickets support</h4>
            <div class="adm-action-value">
              {{ n(m.moderation.tickets) }}
            </div>
            <div class="adm-sub">
              tickets ouverts
            </div>
          </div>

          <span class="material-icons adm-arrow">
            arrow_forward
          </span>

        </a>


        <a class="adm-card adm-action-card"
           routerLink="../inbox"
           [class.has-alert]="m.moderation.appeals > 0">

          <div class="adm-action-icon">
            <span class="material-icons">gavel</span>
          </div>

          <div class="adm-action-content">
            <h4>Contestations</h4>
            <div class="adm-action-value">
              {{ n(m.moderation.appeals) }}
            </div>
            <div class="adm-sub">
              contestations
            </div>
          </div>

          <span class="material-icons adm-arrow">
            arrow_forward
          </span>

        </a>


        <a class="adm-card adm-action-card"
           routerLink="../inbox"
           [class.has-alert]="m.transactions.disputed > 0">

          <div class="adm-action-icon">
            <span class="material-icons">account_balance</span>
          </div>

          <div class="adm-action-content">
            <h4>Litiges</h4>
            <div class="adm-action-value">
              {{ n(m.transactions.disputed) }}
            </div>
            <div class="adm-sub">
              transactions disputées
            </div>
          </div>

          <span class="material-icons adm-arrow">
            arrow_forward
          </span>

        </a>


        <a class="adm-card adm-action-card"
           routerLink="../inbox"
           [class.has-alert]="m.security.fraud_alerts > 0">

          <div class="adm-action-icon">
            <span class="material-icons">security</span>
          </div>

          <div class="adm-action-content">
            <h4>Alertes fraude</h4>
            <div class="adm-action-value">
              {{ n(m.security.fraud_alerts) }}
            </div>
            <div class="adm-sub">
              alertes détectées
            </div>
          </div>

          <span class="material-icons adm-arrow">
            arrow_forward
          </span>

        </a>


        <a class="adm-card adm-action-card"
           routerLink="../moderation"
           [class.has-alert]="m.moderation.pending_videos > 0">

          <div class="adm-action-icon">
            <span class="material-icons">videocam</span>
          </div>

          <div class="adm-action-content">
            <h4>Vidéos à revoir</h4>
            <div class="adm-action-value">
              {{ n(m.moderation.pending_videos) }}
            </div>
            <div class="adm-sub">
              {{ n(m.moderation.flagged_videos) }} en vérification
            </div>
          </div>

          <span class="material-icons adm-arrow">
            arrow_forward
          </span>

        </a>

      </div>


      <!-- =====================================================
           FINANCE
           ===================================================== -->

      @if (admin.can('finance.view')) {

        <div class="adm-section adm-section-main">

          <span class="material-icons">payments</span>

          <div>
            <strong>Finance (30 jours)</strong>
            <small>Vue financière de la plateforme</small>
          </div>

        </div>


        @if (fin(); as f) {

          <div class="adm-finance-grid">

            <div class="adm-card adm-finance-card adm-finance-main">

              <div class="adm-finance-header">
                <h4>Revenu total</h4>

                <span class="material-icons">
                  trending_up
                </span>
              </div>

              <div class="adm-finance-value">
                {{ money(f.total_revenue) }}
              </div>

              <div class="adm-finance-line">
                <span></span>
              </div>

            </div>


            <div class="adm-card adm-finance-card">

              <h4>Commissions</h4>

              <div class="adm-finance-value">
                {{ money(f.commissions) }}
              </div>

              <div class="adm-finance-label">
                Revenus plateforme
              </div>

            </div>


            <div class="adm-card adm-finance-card">

              <h4>Abonnements Premium</h4>

              <div class="adm-finance-value">
                {{ money(f.premium_revenue) }}
              </div>

              <div class="adm-finance-label">
                {{ n(f.premium_subscriptions) }} abonnement(s)
              </div>

            </div>


            <div class="adm-card adm-finance-card">

              <h4>Frais de publication</h4>

              <div class="adm-finance-value">
                {{ money(f.listing_fees) }}
              </div>

              <div class="adm-finance-label">
                {{ n(f.listing_fees_count) }} annonce(s)
              </div>

            </div>


            <div class="adm-card adm-finance-card">

              <h4>Volume échangé</h4>

              <div class="adm-finance-value">
                {{ money(f.gmv) }}
              </div>

              <div class="adm-finance-label">
                GMV plateforme
              </div>

            </div>


            <div class="adm-card adm-finance-card">

              <h4>Remboursé</h4>

              <div class="adm-finance-value">
                {{ money(f.refunded) }}
              </div>

              <div class="adm-finance-label">
                remboursements
              </div>

            </div>

          </div>

        }

      }


      <!-- =====================================================
           ACTIVITÉ
           ===================================================== -->

      <div class="adm-section adm-section-main">

        <span class="material-icons">show_chart</span>

        <div class="adm-section-title">

          <div>
            <strong>Activité</strong>
            <small>Évolution de la plateforme</small>
          </div>

          <select
            class="adm-input inline adm-period-select"
            [value]="days()"
            (change)="setDays(+$any($event.target).value)">

            <option value="7">7 jours</option>
            <option value="14">14 jours</option>
            <option value="30">30 jours</option>
            <option value="90">90 jours</option>

          </select>

        </div>

      </div>


      @if (overview(); as o) {

        <div class="adm-analytics-grid">

          @for (s of series; track s.key) {

            <div class="adm-card adm-chart-card">

              <div class="adm-chart-header">

                <div>

                  <h4>{{ s.label }}</h4>

                  <div class="adm-chart-total">
                    {{ totalSeries(o.daily, s.key) | number }}
                  </div>

                </div>

                <div class="adm-chart-icon">
                  <span class="material-icons">
                    {{ s.key === 'users'
                      ? 'person_add'
                      : s.key === 'products'
                        ? 'storefront'
                        : 'swap_horiz' }}
                  </span>
                </div>

              </div>


              <div class="adm-bars">

                @for (d of o.daily; track d.date) {

                  <div
                    class="bar"
                    [style.height.%]="pct(o.daily, s.key, d[s.key])"
                    [title]="d.date + ' : ' + d[s.key]">
                  </div>

                }

              </div>


              <div class="adm-chart-footer">

                <span>
                  {{ o.daily.length }} jours
                </span>

                <span>
                  Activité
                </span>

              </div>

            </div>

          }

        </div>

      }

    }

    @else {

      <div class="adm-empty adm-loading">

        <span class="adm-loader"></span>

        <span>Chargement du tableau de bord…</span>

      </div>

    }

  </div>
`,
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
    {
      key: 'users',
      label: 'Inscriptions'
    },
    {
      key: 'products',
      label: 'Annonces'
    },
    {
      key: 'transactions',
      label: 'Transactions'
    },
  ];

  n = fmtNum;
  money = fmtMoney;


  ngOnInit() {

    this.admin
      .getMetrics()
      .subscribe(m => this.m.set(m));


    this.admin
      .getRealTime()
      .subscribe(r => {

        this.rt.set(r);

        this.checks.set(
          Object.entries(r.health_checks ?? {})
        );

      });


    if (this.admin.can('finance.view')) {

      this.admin
        .getFinance(30)
        .subscribe(f => this.fin.set(f));

    }


    this.loadOverview();

  }


  setDays(d: number) {

    this.days.set(d);

    this.loadOverview();

  }


  private loadOverview() {

    if (this.admin.can('audit.view')) {

      this.admin
        .getOverview(this.days())
        .subscribe(o => this.overview.set(o));

    }

  }


  pct(rows: any[], key: string, v: number) {

    const max = Math.max(
      1,
      ...rows.map(r => Number(r[key] ?? 0))
    );

    return Math.max(
      2,
      (Number(v ?? 0) / max) * 100
    );

  }


  ratio(value: number, total: number): number {

    if (!total || total <= 0) {
      return 0;
    }

    return Math.min(
      100,
      Math.max(
        0,
        (value / total) * 100
      )
    );

  }


  totalSeries(rows: any[], key: string): number {

    if (!rows?.length) {
      return 0;
    }

    return rows.reduce(
      (total, row) =>
        total + Number(row[key] ?? 0),
      0
    );

  }

}
