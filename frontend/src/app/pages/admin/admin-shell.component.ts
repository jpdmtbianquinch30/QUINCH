import { Component, OnDestroy, OnInit, computed, inject, signal } from '@angular/core';
import { Location } from '@angular/common';
import { Router, RouterLink, RouterLinkActive, RouterOutlet } from '@angular/router';
import { AdminService } from '../../core/services/admin.service';
import { ROLE_LABELS } from './shared/admin-utils';

interface NavItem { path: string; label: string; icon: string; perms: string[]; badge?: () => number; }

/**
 * Coquille du panneau admin : menu filtré selon les permissions du staff
 * connecté, compteur « À traiter ». Chaque module est une page chargée à la
 * demande (lazy) : l'ancien composant monolithique de 912 lignes a disparu.
 * Le rafraîchissement du compteur est de 60 s et ne tourne QUE onglet visible
 * (avant : toutes les 10 s même onglet caché).
 */
@Component({
  selector: 'app-admin-shell',
  standalone: true,
  imports: [RouterOutlet, RouterLink, RouterLinkActive],
  template: `
  <div class="shell">
    <header class="shell-head">
      <button class="back" (click)="goBack()" aria-label="Retour"><span class="material-icons">arrow_back</span></button>
      <div class="titles">
        <h1><span class="material-icons">admin_panel_settings</span> Administration</h1>
        @if (admin.me(); as me) { <span class="role">{{ roleLabel() }} · {{ me.user.full_name }}</span> }
      </div>
      <span class="live"><i></i> {{ pendingTotal() }} à traiter</span>
    </header>

    <nav class="shell-nav" aria-label="Modules">
      @for (item of visibleNav(); track item.path) {
        <a [routerLink]="item.path" routerLinkActive="active" class="nav-link">
          <span class="material-icons">{{ item.icon }}</span>{{ item.label }}
          @if (item.badge && item.badge() > 0) { <b>{{ item.badge() }}</b> }
        </a>
      }
    </nav>

    @if (!admin.me()) { <div class="loading">Chargement des droits…</div> }
    @else { <router-outlet /> }
  </div>`,
  styles: [`
    .shell { padding: 20px 28px; max-width: 1400px; margin: 0 auto; }
    .shell-head { display: flex; align-items: center; gap: 12px; margin-bottom: 14px; }
    .back { background: var(--q-bg-card); border: 1px solid var(--q-border); border-radius: 10px; width: 36px; height: 36px; color: var(--q-text-secondary); cursor: pointer; }
    h1 { margin: 0; font-size: 1.35rem; display: flex; align-items: center; gap: 8px; .material-icons { color: var(--q-accent); } }
    .role { font-size: .78rem; color: var(--q-text-muted); }
    .titles { flex: 1; }
    .live { font-size: .75rem; font-weight: 700; color: var(--q-warning); background: var(--q-warning-subtle); padding: 4px 12px; border-radius: 999px; display: flex; align-items: center; gap: 6px;
      i { width: 7px; height: 7px; border-radius: 50%; background: var(--q-warning); } }
    .shell-nav { display: flex; gap: 2px; overflow-x: auto; border-bottom: 1px solid var(--q-border); margin-bottom: 18px; }
    .nav-link { display: flex; align-items: center; gap: 6px; padding: 10px 14px; color: var(--q-text-muted); text-decoration: none; font-size: .84rem; font-weight: 600; white-space: nowrap; border-bottom: 2px solid transparent;
      .material-icons { font-size: 18px; } b { background: var(--q-danger); color: #fff; border-radius: 999px; padding: 0 6px; font-size: .64rem; }
      &:hover { color: var(--q-text-primary); } &.active { color: var(--q-accent); border-bottom-color: var(--q-accent); } }
    .loading { padding: 40px; text-align: center; color: var(--q-text-muted); }
    @media (max-width: 700px) { .shell { padding: 12px; } }
  `],
})
export class AdminShellComponent implements OnInit, OnDestroy {
  admin = inject(AdminService);
  private router = inject(Router);
  private location = inject(Location);

  counts = signal({ inbox: 0, moderation: 0 });
  private timer: any;
  private onVisible = () => { if (!document.hidden) this.refreshCounts(); };

  nav: NavItem[] = [
    { path: 'dashboard', label: 'Tableau de bord', icon: 'dashboard', perms: [] },
    { path: 'inbox', label: 'À traiter', icon: 'inbox', perms: ['reports.handle'], badge: () => this.counts().inbox },
    { path: 'moderation', label: 'Vidéos', icon: 'smart_display', perms: ['videos.moderate'], badge: () => this.counts().moderation },
    { path: 'products', label: 'Produits', icon: 'inventory_2', perms: ['products.view'] },
    { path: 'users', label: 'Utilisateurs', icon: 'group', perms: ['users.view'] },
    { path: 'transactions', label: 'Transactions', icon: 'receipt_long', perms: ['finance.view'] },
    { path: 'categories', label: 'Catégories', icon: 'category', perms: ['categories.manage'] },
    { path: 'notifications', label: 'Notifications', icon: 'campaign', perms: ['notifications.broadcast'] },
    { path: 'security', label: 'Sécurité & audit', icon: 'security', perms: ['audit.view', 'security.ip_ban'] },
    { path: 'team', label: 'Équipe & Premium', icon: 'badge', perms: ['staff.manage', 'premium.manage', 'reviews.moderate'] },
    { path: 'settings', label: 'Réglages', icon: 'tune', perms: ['feed.manage', 'settings.manage'] },
  ];

  visibleNav = computed(() => this.nav.filter(n => !n.perms.length || this.admin.canAny(...n.perms)));
  pendingTotal = computed(() => this.counts().inbox + this.counts().moderation);
  roleLabel = computed(() => ROLE_LABELS[this.admin.me()?.role ?? ''] ?? '');

  ngOnInit() {
    this.admin.loadMe().subscribe({ next: () => this.refreshCounts(), error: () => this.router.navigate(['/feed']) });
    this.timer = setInterval(() => { if (!document.hidden) this.refreshCounts(); }, 60000);
    document.addEventListener('visibilitychange', this.onVisible);
  }

  ngOnDestroy() {
    clearInterval(this.timer);
    document.removeEventListener('visibilitychange', this.onVisible);
  }

  refreshCounts() {
    this.admin.getMetrics().subscribe({
      next: m => this.counts.set({
        inbox: m.moderation.reports + m.moderation.user_reports + m.moderation.tickets + m.moderation.appeals + m.transactions.disputed + m.security.fraud_alerts,
        moderation: m.moderation.flagged_videos,
      }),
    });
  }

  goBack() {
    if (window.history.length > 1) this.location.back(); else this.router.navigate(['/feed']);
  }
}
