import { Component, OnDestroy, OnInit, computed, inject, signal } from '@angular/core';
import { NavigationEnd, Router, RouterLink, RouterLinkActive, RouterOutlet } from '@angular/router';
import { filter } from 'rxjs';
import { AdminService } from '../../core/services/admin.service';
import { ThemeService } from '../../core/services/theme.service';
import { AuthService } from '../../core/services/auth.service';
import { ConfirmService } from '../../shared/confirm/confirm.service';
import { ROLE_LABELS } from './shared/admin-utils';

interface NavItem { path: string; label: string; icon: string; perms: string[]; badge?: () => number; }
interface NavGroup { title: string; items: NavItem[]; }

/**
 * Coquille du panneau admin (v2) : barre latérale groupée (bureau) / tiroir (mobile),
 * menu filtré selon les permissions du staff, compteur « À traiter », thème clair/sombre.
 *
 * Pour ajouter un module : 1) créer la page dans ./pages, 2) la déclarer dans
 * admin.routes.ts, 3) ajouter UNE ligne dans NAV ci-dessous. Rien d'autre.
 * Le compteur se rafraîchit toutes les 60 s, uniquement onglet visible.
 */
@Component({
  selector: 'app-admin-shell',
  standalone: true,
  imports: [RouterOutlet, RouterLink, RouterLinkActive],
  template: `
  <div class="ad" [class.open]="drawer()">
    <aside class="ad-side" aria-label="Navigation administration">
      <div class="ad-brand">
        <span class="ad-logo material-icons">admin_panel_settings</span>
        <div><strong>QUINCH</strong><small>Administration</small></div>
      </div>

      <nav class="ad-nav">
        @for (g of groups(); track g.title) {
          <div class="ad-group">{{ g.title }}</div>
          @for (item of g.items; track item.path) {
            <a [routerLink]="item.path" routerLinkActive="active" class="ad-link">
              <span class="material-icons">{{ item.icon }}</span>
              <span class="ad-lbl">{{ item.label }}</span>
              @if (item.badge && item.badge() > 0) { <b>{{ item.badge() > 99 ? '99+' : item.badge() }}</b> }
            </a>
          }
        }
      </nav>

      <div class="ad-foot">
        @if (admin.me(); as me) {
          <div class="ad-me"><span class="material-icons">account_circle</span>
            <div><strong>{{ me.user.full_name }}</strong><small>{{ roleLabel() }}</small></div></div>
        }
        <a class="ad-switch" routerLink="/feed" title="Quitter l'administration et ouvrir le site comme un utilisateur">
          <span class="material-icons">storefront</span>
          <span><strong>Voir le site</strong><small>Mode utilisateur (votre compte reste connecté)</small></span>
          <span class="material-icons">arrow_forward</span>
        </a>
        <div class="ad-foot-btns">
          <button type="button" (click)="theme.toggle()" [attr.aria-label]="theme.lightMode() ? 'Mode sombre' : 'Mode clair'">
            <span class="material-icons">{{ theme.lightMode() ? 'dark_mode' : 'light_mode' }}</span></button>
          <button type="button" class="logout" (click)="logout()"><span class="material-icons">logout</span> Se déconnecter</button>
        </div>
      </div>
    </aside>

    @if (drawer()) { <div class="ad-scrim" (click)="drawer.set(false)"></div> }

    <div class="ad-main">
      <header class="ad-top">
        <button class="ad-burger" type="button" (click)="drawer.set(!drawer())" aria-label="Menu"><span class="material-icons">menu</span></button>
        <h1>{{ title() }}</h1>
        <a class="ad-site-btn" routerLink="/feed" aria-label="Voir le site comme un utilisateur"><span class="material-icons">storefront</span><span class="ad-site-lbl">Site</span></a>
        <span class="ad-pending" [class.zero]="pendingTotal() === 0"><i></i>{{ pendingTotal() }} à traiter</span>
      </header>

      <div class="ad-content">
        @if (!admin.me()) { <div class="ad-loading"><div class="ad-spin"></div>Chargement des droits…</div> }
        @else { <router-outlet /> }
      </div>
    </div>
  </div>`,
  styles: [`
    :host { display: block; --ad-side: 262px; }
    .ad { display: grid; grid-template-columns: var(--ad-side) minmax(0, 1fr); min-height: 100dvh;
      background: var(--q-bg-primary); color: var(--q-text-primary); }

    /* ── Barre latérale ── */
    .ad-side { position: sticky; top: 0; height: 100dvh; display: flex; flex-direction: column; padding: 18px 12px 12px;
      background: var(--q-bg-secondary); border-right: 1px solid var(--q-border); z-index: 60; }
    .ad-brand { display: flex; align-items: center; gap: 12px; padding: 4px 8px 18px; }
    .ad-logo { width: 40px; height: 40px; display: grid; place-items: center; border-radius: 13px; color: #fff; font-size: 22px;
      background: linear-gradient(135deg, var(--q-accent), #8b5cf6); box-shadow: 0 8px 22px var(--q-accent-glow, rgba(99,102,241,.35)); }
    .ad-brand strong { display: block; font-size: 1rem; letter-spacing: .08em; }
    .ad-brand small { color: var(--q-text-muted); font-size: .72rem; }
    .ad-nav { flex: 1; overflow-y: auto; padding-right: 2px; scrollbar-width: thin; }
    .ad-group { margin: 16px 10px 6px; font-size: .64rem; font-weight: 800; letter-spacing: .12em; text-transform: uppercase; color: var(--q-text-muted); }
    .ad-link { display: flex; align-items: center; gap: 11px; padding: 10px 12px; margin: 2px 0; border-radius: 12px; text-decoration: none;
      color: var(--q-text-secondary); font-size: .88rem; font-weight: 600; transition: background .15s, color .15s;
      .material-icons { font-size: 20px; opacity: .85; }
      .ad-lbl { flex: 1; min-width: 0; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
      b { background: var(--q-danger); color: #fff; border-radius: 999px; padding: 1px 7px; font-size: .64rem; font-weight: 800; }
      &:hover { background: var(--q-bg-card-hover); color: var(--q-text-primary); }
      &.active { color: #fff; background: linear-gradient(135deg, var(--q-accent), #7c6cf6); box-shadow: 0 6px 18px var(--q-accent-glow, rgba(99,102,241,.3));
        .material-icons { opacity: 1; } b { background: #fff; color: var(--q-accent); } } }
    .ad-foot { border-top: 1px solid var(--q-border); padding-top: 12px; display: grid; gap: 10px; }
    .ad-me { display: flex; align-items: center; gap: 10px; padding: 0 6px; min-width: 0;
      .material-icons { font-size: 32px; color: var(--q-text-muted); }
      strong { display: block; font-size: .84rem; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
      small { color: var(--q-text-muted); font-size: .72rem; } div { min-width: 0; } }
    .ad-switch { display: flex; align-items: center; gap: 10px; padding: 10px 12px; border-radius: 13px; text-decoration: none; color: var(--q-text-primary);
      border: 1px dashed color-mix(in srgb, var(--q-accent) 60%, transparent); background: color-mix(in srgb, var(--q-accent) 9%, transparent);
      > span:nth-child(2) { flex: 1; min-width: 0; } strong { display: block; font-size: .84rem; } small { display: block; color: var(--q-text-muted); font-size: .68rem; line-height: 1.25; }
      .material-icons { font-size: 20px; color: var(--q-accent); } &:hover { background: color-mix(in srgb, var(--q-accent) 16%, transparent); } }
    .ad-site-btn { display: inline-flex; align-items: center; gap: 6px; height: 36px; padding: 0 12px; border-radius: 999px; text-decoration: none; font-size: .76rem; font-weight: 800;
      color: var(--q-text-primary); background: var(--q-bg-card); border: 1px solid var(--q-border); .material-icons { font-size: 18px; color: var(--q-accent); } &:hover { border-color: var(--q-accent); } }
    @media (max-width: 480px) { .ad-site-lbl { display: none; } .ad-site-btn { padding: 0 9px; } }
    .ad-foot-btns { display: flex; gap: 8px;
      button { display: flex; align-items: center; justify-content: center; gap: 6px; height: 38px; padding: 0 12px; border-radius: 11px; cursor: pointer;
        background: var(--q-bg-card); border: 1px solid var(--q-border); color: var(--q-text-secondary); font: inherit; font-size: .78rem; font-weight: 700;
        .material-icons { font-size: 18px; } &:hover { color: var(--q-text-primary); border-color: var(--q-accent); }
        &:last-child { flex: 1; } } }

    /* ── Zone principale ── */
    .ad-main { min-width: 0; display: flex; flex-direction: column; }
    .ad-top { position: sticky; top: 0; z-index: 40; display: flex; align-items: center; gap: 12px; padding: 14px 28px;
      background: color-mix(in srgb, var(--q-bg-primary) 86%, transparent); backdrop-filter: blur(14px); border-bottom: 1px solid var(--q-border);
      h1 { margin: 0; flex: 1; font-size: 1.2rem; font-weight: 800; letter-spacing: -.01em; } }
    .ad-burger { display: none; width: 40px; height: 40px; border-radius: 12px; cursor: pointer; place-items: center;
      background: var(--q-bg-card); border: 1px solid var(--q-border); color: var(--q-text-primary); }
    .ad-pending { display: inline-flex; align-items: center; gap: 7px; font-size: .76rem; font-weight: 800; padding: 6px 14px; border-radius: 999px;
      color: var(--q-warning); background: var(--q-warning-subtle, rgba(245,166,35,.12));
      i { width: 8px; height: 8px; border-radius: 50%; background: currentColor; animation: adp 1.6s infinite; }
      &.zero { color: var(--q-success); background: var(--q-success-subtle, rgba(33,201,133,.12)); i { animation: none; } } }
    @keyframes adp { 50% { opacity: .35; transform: scale(.7); } }
    .ad-content { flex: 1; min-width: 0; padding: 22px 28px 40px; max-width: 1480px; width: 100%; margin: 0 auto; box-sizing: border-box; }
    .ad-loading { display: grid; justify-items: center; gap: 12px; padding: 70px 16px; color: var(--q-text-muted); }
    .ad-spin { width: 30px; height: 30px; border-radius: 50%; border: 3px solid var(--q-border); border-top-color: var(--q-accent); animation: ads .8s linear infinite; }
    @keyframes ads { to { transform: rotate(360deg); } }

    /* ── Mobile : tiroir ── */
    @media (max-width: 900px) {
      .ad { grid-template-columns: minmax(0, 1fr); }
      .ad-side { position: fixed; inset: 0 auto 0 0; width: min(84vw, 300px); transform: translateX(-102%); transition: transform .25s ease;
        box-shadow: 20px 0 60px rgba(0,0,0,.45); padding-top: calc(18px + env(safe-area-inset-top)); padding-bottom: calc(12px + env(safe-area-inset-bottom)); }
      .ad.open .ad-side { transform: none; }
      .ad-scrim { position: fixed; inset: 0; z-index: 55; background: rgba(2,6,23,.6); backdrop-filter: blur(3px); }
      .ad-burger { display: grid; }
      .ad-top { padding: calc(10px + env(safe-area-inset-top)) 14px 10px; h1 { font-size: 1.02rem; } }
      .ad-content { padding: 14px 12px 32px; }
    }
  `],
})
export class AdminShellComponent implements OnInit, OnDestroy {
  admin = inject(AdminService);
  theme = inject(ThemeService);
  private router = inject(Router);
  private confirm = inject(ConfirmService);
  private auth = inject(AuthService);

  counts = signal({ inbox: 0, moderation: 0 });
  drawer = signal(false);
  private url = signal(this.router.url);
  private timer: any;
  private navSub = this.router.events.pipe(filter(e => e instanceof NavigationEnd)).subscribe((e: any) => {
    this.url.set(e.urlAfterRedirects || e.url);
    this.drawer.set(false);
  });
  private onVisible = () => { if (!document.hidden) this.refreshCounts(); };

  /** Source unique du menu : un module = une ligne. */
  private readonly NAV: NavGroup[] = [
    { title: 'Pilotage', items: [
      { path: 'dashboard', label: 'Tableau de bord', icon: 'space_dashboard', perms: [] },
      { path: 'inbox', label: 'À traiter', icon: 'inbox', perms: ['reports.handle'], badge: () => this.counts().inbox },
    ] },
    { title: 'Contenu', items: [
      { path: 'moderation', label: 'Vidéos', icon: 'smart_display', perms: ['videos.moderate'], badge: () => this.counts().moderation },
      { path: 'products', label: 'Annonces', icon: 'inventory_2', perms: ['products.view'] },
      { path: 'categories', label: 'Catégories', icon: 'category', perms: ['categories.manage'] },
    ] },
    { title: 'Communauté', items: [
      { path: 'badges', label: 'Badges', icon: 'military_tech', perms: ['badges.manage'] },
      { path: 'users', label: 'Utilisateurs', icon: 'group', perms: ['users.view'] },
      { path: 'notifications', label: 'Annonces & push', icon: 'campaign', perms: ['notifications.broadcast'] },
      { path: 'team', label: 'Équipe & Premium', icon: 'badge', perms: ['staff.manage', 'premium.manage', 'reviews.moderate'] },
    ] },
    { title: 'Finance & sécurité', items: [
      { path: 'transactions', label: 'Transactions', icon: 'receipt_long', perms: ['finance.view'] },
      { path: 'security', label: 'Sécurité & audit', icon: 'shield', perms: ['audit.view', 'security.ip_ban'] },
    ] },
    { title: 'Système', items: [
      { path: 'settings', label: 'Réglages & feed', icon: 'tune', perms: ['feed.manage', 'settings.manage'] },
    ] },
  ];

  groups = computed<NavGroup[]>(() => this.NAV
    .map(g => ({ title: g.title, items: g.items.filter(n => !n.perms.length || this.admin.canAny(...n.perms)) }))
    .filter(g => g.items.length));
  title = computed(() => {
    const seg = this.url().split('?')[0].split('/').filter(Boolean)[1] ?? 'dashboard';
    return this.NAV.flatMap(g => g.items).find(n => n.path === seg)?.label ?? 'Administration';
  });
  pendingTotal = computed(() => this.counts().inbox + this.counts().moderation);
  roleLabel = computed(() => ROLE_LABELS[this.admin.me()?.role ?? ''] ?? '');

  ngOnInit() {
    this.admin.loadMe().subscribe({ next: () => this.refreshCounts(), error: () => this.router.navigate(['/feed']) });
    this.timer = setInterval(() => { if (!document.hidden) this.refreshCounts(); }, 60000);
    document.addEventListener('visibilitychange', this.onVisible);
  }

  ngOnDestroy() {
    clearInterval(this.timer);
    this.navSub.unsubscribe();
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

  async logout() {
    const r = await this.confirm.ask({
      title: 'Se déconnecter ?',
      message: "Vous quitterez l'administration et devrez vous reconnecter avec votre mot de passe.",
      confirmLabel: 'Se déconnecter',
      icon: 'logout',
    });
    if (r.confirmed) this.auth.logout();
  }
}
