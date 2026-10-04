import { Component, OnInit, inject, signal } from '@angular/core';
import { DatePipe } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { AdminService } from '../../../core/services/admin.service';
import { NotificationService } from '../../../core/services/notification.service';
import { AdminModalComponent, ModalResult } from '../shared/admin-modal.component';
import { errMsg } from '../shared/admin-utils';

/** Audit unifié (actions du staff), journal technique, bannissement d'IP avec expiration. */
@Component({
  selector: 'adm-security',
  standalone: true,
  imports: [DatePipe, FormsModule, AdminModalComponent],
  styleUrl: '../shared/admin-common.scss',
  template: `
  <div class="adm-page">
    <div class="adm-tabs">
      @if (admin.can('audit.view')) { <button class="adm-tab" [class.active]="tab() === 'admin'" (click)="setTab('admin')">Journal des actions admin</button>
        <button class="adm-tab" [class.active]="tab() === 'tech'" (click)="setTab('tech')">Journal technique</button> }
      @if (admin.can('security.ip_ban')) { <button class="adm-tab" [class.active]="tab() === 'ips'" (click)="setTab('ips')">IP bannies</button> }
    </div>

    @if (tab() === 'admin') {
      <div class="adm-inline-form" style="margin-bottom:12px">
        <input class="adm-input" placeholder="Action (ex: user_banned)" [(ngModel)]="lf.action" (keyup.enter)="loadLogs(1)" />
        <input class="adm-input" placeholder="Id de la cible" [(ngModel)]="lf.target_id" (keyup.enter)="loadLogs(1)" />
        <select class="adm-input" [(ngModel)]="lf.severity" (change)="loadLogs(1)"><option value="">Gravité</option><option value="info">info</option><option value="warning">warning</option><option value="critical">critical</option></select>
        <input class="adm-input" type="date" [(ngModel)]="lf.from" (change)="loadLogs(1)" /><input class="adm-input" type="date" [(ngModel)]="lf.to" (change)="loadLogs(1)" />
        <button class="adm-btn" (click)="exportLogs()">Exporter CSV</button>
      </div>
      <div class="adm-table-wrap"><table class="adm-table"><thead><tr><th>Date</th><th>Admin</th><th>Action</th><th>Cible</th><th>Détails</th></tr></thead><tbody>
        @for (l of logs(); track l.id) { <tr>
          <td class="adm-sub">{{ l.created_at | date:'dd/MM/yy HH:mm' }}</td><td>{{ l.admin?.full_name || 'Système' }}</td>
          <td><span class="adm-chip" [class.bad]="l.severity === 'critical'" [class.warn]="l.severity === 'warning'">{{ l.action }}</span></td>
          <td class="adm-sub">{{ l.target_type }} {{ l.target_id?.slice(0, 8) }}</td><td class="adm-sub">{{ meta(l) }}</td></tr>
        } @empty { <tr><td colspan="5" class="adm-empty">Aucune entrée.</td></tr> }</tbody></table></div>
      @if (last() > 1) { <div class="adm-pager"><button class="adm-btn sm" [disabled]="page() <= 1" (click)="loadLogs(page() - 1)">‹</button>Page {{ page() }} / {{ last() }}<button class="adm-btn sm" [disabled]="page() >= last()" (click)="loadLogs(page() + 1)">›</button></div> }
    }

    @if (tab() === 'tech') {
      <div class="adm-table-wrap"><table class="adm-table"><thead><tr><th>Date</th><th>Utilisateur</th><th>Type</th><th>Entité</th><th>Gravité</th></tr></thead><tbody>
        @for (l of tech(); track l.id) { <tr><td class="adm-sub">{{ l.created_at | date:'dd/MM HH:mm' }}</td><td>{{ l.user?.full_name }}</td><td>{{ l.action_type }}</td><td class="adm-sub">{{ l.entity_type }}</td><td><span class="adm-chip" [class.bad]="l.severity === 'critical'" [class.warn]="l.severity === 'warning'">{{ l.severity }}</span></td></tr>
        } @empty { <tr><td colspan="5" class="adm-empty">Aucune entrée.</td></tr> }</tbody></table></div>
    }

    @if (tab() === 'ips') {
      <div class="adm-warn-box">⚠ Les opérateurs mobiles partagent leurs adresses IP entre des milliers d'abonnés : privilégiez une <strong>durée courte</strong>, ou sanctionnez plutôt le compte. Les IP privées, la vôtre et celles du staff connecté sont protégées. Vérifiez que <code>TRUSTED_PROXIES</code> est configuré.</div>
      <div class="adm-inline-form" style="margin-bottom:12px">
        <input class="adm-input" placeholder="Adresse IP (ex. 41.82.10.5)" [(ngModel)]="ip" />
        <select class="adm-input" [(ngModel)]="hours"><option [ngValue]="1">1 heure</option><option [ngValue]="24">24 heures</option><option [ngValue]="168">7 jours</option><option [ngValue]="720">30 jours</option><option [ngValue]="null">Sans limite</option></select>
        <button class="adm-btn danger" [disabled]="!ip" (click)="ask('ban')">Bannir</button>
      </div>
      <div class="adm-table-wrap"><table class="adm-table"><thead><tr><th>IP</th><th>Motif</th><th>Expire</th><th>Par</th><th></th></tr></thead><tbody>
        @for (b of ips(); track b.id) { <tr><td><code>{{ b.ip_address }}</code></td><td>{{ b.reason }}</td><td class="adm-sub">{{ b.expires_at ? (b.expires_at | date:'dd/MM HH:mm') : 'jamais' }}</td><td class="adm-sub">{{ b.banned_by?.full_name }}</td>
          <td><button class="adm-btn sm" (click)="target = b; ask('unban')">Débannir</button></td></tr>
        } @empty { <tr><td colspan="5" class="adm-empty">Aucune IP bannie.</td></tr> }</tbody></table></div>
    }
  </div>

  @if (dlg(); as a) {
    <adm-modal [title]="a === 'ban' ? 'Bannir ' + ip : 'Débannir ' + target?.ip_address" [danger]="a === 'ban'" [needReason]="a === 'ban'" [needPassword]="true" [busy]="busy()" [error]="error()" (cancel)="dlg.set(null)" (confirm)="run($event)"></adm-modal>
  }`,
})
export class AdminSecurityPage implements OnInit {
  admin = inject(AdminService);
  private notif = inject(NotificationService);

  tab = signal<'admin' | 'tech' | 'ips'>('admin');
  logs = signal<any[]>([]); tech = signal<any[]>([]); ips = signal<any[]>([]);
  page = signal(1); last = signal(1);
  lf: { action: string; target_id: string; severity: string; from: string; to: string } = { action: '', target_id: '', severity: '', from: '', to: '' };
  ip = ''; hours: number | null = 24; target: any = null;
  dlg = signal<'ban' | 'unban' | null>(null); busy = signal(false); error = signal('');

  ngOnInit() {
    this.tab.set(this.admin.can('audit.view') ? 'admin' : 'ips');
    this.setTab(this.tab());
  }

  setTab(t: 'admin' | 'tech' | 'ips') {
    this.tab.set(t);
    if (t === 'admin') this.loadLogs(1);
    if (t === 'tech') this.admin.getTechLogs({}).subscribe(r => this.tech.set(r.data));
    if (t === 'ips') this.loadIps();
  }

  loadLogs(page: number) {
    this.admin.getAdminLogs({ ...this.lf, page }).subscribe({ next: r => { this.logs.set(r.data); this.page.set(r.current_page); this.last.set(r.last_page); }, error: e => this.notif.error(errMsg(e)) });
  }
  loadIps() { this.admin.getBannedIps().subscribe(r => this.ips.set(r)); }
  meta(l: any) { const m = l.metadata; if (!m) return ''; return m.reason ? m.reason : JSON.stringify(m).slice(0, 90); }
  exportLogs() { this.admin.exportAdminLogs(this.lf).subscribe({ next: b => this.admin.saveBlob(b, 'quinch-audit.csv'), error: () => this.notif.error('Export impossible') }); }

  ask(a: 'ban' | 'unban') { this.error.set(''); this.dlg.set(a); }
  run(res: ModalResult) {
    this.busy.set(true);
    const req = this.dlg() === 'ban'
      ? this.admin.banIp(this.ip.trim(), res.reason, this.hours, res.password)
      : this.admin.unbanIp(this.target.id, res.password);
    req.subscribe({
      next: (r: any) => { this.busy.set(false); this.dlg.set(null); this.notif.success(r?.message ?? 'Fait'); this.ip = ''; this.loadIps(); },
      error: (e: any) => { this.busy.set(false); this.error.set(errMsg(e)); },
    });
  }
}
