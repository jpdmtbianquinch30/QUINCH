import { Component, OnInit, inject, signal, computed } from '@angular/core';
import { FormsModule } from '@angular/forms';
import { AdminService } from '../../../core/services/admin.service';
import { NotificationService } from '../../../core/services/notification.service';
import { ConfirmService } from '../../../shared/confirm/confirm.service';
import { errMsg } from '../shared/admin-utils';

interface BadgeForm {
  id?: string; key: string; name: string; description: string; how_to_get: string;
  icon: string; color: string; auto_rule: string; auto_threshold: number | null;
  zones: string[]; is_active: boolean; sellers_can_award: boolean; sort_order: number; is_system?: boolean;
}

const ICONS = [
  'verified', 'workspace_premium', 'emoji_events', 'local_shipping', 'favorite', 'rate_review', 'celebration', 'military_tech',
  'campaign', 'cake', 'star', 'stars', 'shield', 'verified_user', 'thumb_up', 'bolt', 'diamond', 'trending_up', 'handshake',
  'storefront', 'redeem', 'support_agent', 'school', 'eco', 'whatshot', 'rocket_launch', 'volunteer_activism', 'new_releases',
  'groups', 'translate', 'public', 'bookmark', 'flag', 'lock', 'check_circle', 'sentiment_very_satisfied',
];

const EMPTY: BadgeForm = {
  key: '', name: '', description: '', how_to_get: '', icon: 'stars', color: '#6366f1', auto_rule: '', auto_threshold: null,
  zones: [], is_active: true, sellers_can_award: false, sort_order: 100,
};

/**
 * Catalogue des badges : l'admin crée les badges, choisit icône / couleur, les zones où ils
 * s'affichent, et peut les « brancher » sur une règle automatique (Premium, KYC, ventes…).
 */
@Component({
  selector: 'adm-badges',
  standalone: true,
  imports: [FormsModule],
  styleUrl: '../shared/admin-common.scss',
  template: `
  <div class="adm-page">
    <div class="adm-card bd-help">
      <h4>Comment fonctionnent les badges ?</h4>
      <ul>
        <li><strong>Manuel</strong> : vous l'attribuez à la main (fiche utilisateur → Badge). Le badge « Client Fidèle » peut aussi être attribué par les vendeurs si vous l'autorisez.</li>
        <li><strong>Automatique</strong> : vous le « branchez » sur une règle (Premium actif, KYC vérifié, nombre de ventes, ancienneté, score de confiance). Le système le pose et le retire tout seul (immédiatement pour Premium/KYC, chaque heure pour le reste).</li>
        <li><strong>Zones</strong> : cochez les endroits où le badge s'affiche. Aucun badge n'est affiché en dehors de ceux d'ici.</li>
      </ul>
    </div>

    <div class="adm-row" style="margin:12px 0;flex-wrap:wrap;gap:8px">
      <button class="adm-btn primary" (click)="openNew()"><span class="material-icons" style="font-size:18px">add</span> Nouveau badge</button>
      <button class="adm-btn" (click)="sync()" [disabled]="syncing()">{{ syncing() ? 'Calcul…' : 'Recalculer les badges automatiques' }}</button>
      <span class="adm-sub">{{ items().length }} badge(s)</span>
    </div>

    @if (loading()) { <div class="adm-empty">Chargement…</div> }
    <div class="bd-grid">
      @for (b of items(); track b.id) {
        <div class="adm-card bd-card" [class.off]="!b.is_active">
          <div class="bd-top">
            <span class="bd-ico" [style.background]="b.color + '26'" [style.color]="b.color"><span class="material-icons">{{ b.icon }}</span></span>
            <div class="bd-title"><strong>{{ b.name }}</strong><code>{{ b.key }}</code></div>
            <span class="adm-chip" [class.ok]="b.auto_rule" [class.info]="!b.auto_rule">{{ b.auto_rule ? 'Auto' : 'Manuel' }}</span>
          </div>
          <p class="adm-muted">{{ b.description || '—' }}</p>
          @if (b.auto_rule) { <p class="adm-sub">⚙ {{ ruleLabel(b) }}</p> }
          <p class="adm-sub">📍 {{ zonesLabel(b) }}</p>
          <div class="adm-row" style="gap:8px;flex-wrap:wrap">
            <span class="adm-chip">{{ b.holders_count }} détenteur(s)</span>
            @if (!b.is_active) { <span class="adm-chip bad">Désactivé</span> }
            @if (b.is_system) { <span class="adm-chip">Origine</span> }
            <span style="flex:1"></span>
            <button class="adm-btn sm" (click)="edit(b)">Modifier</button>
            @if (!b.is_system) { <button class="adm-btn sm danger" (click)="remove(b)">Supprimer</button> }
          </div>
        </div>
      }
    </div>
  </div>

  @if (form(); as f) {
    <div class="adm-overlay" (click)="form.set(null)">
      <div class="adm-modal bd-modal" (click)="$event.stopPropagation()" role="dialog" aria-modal="true">
        <h3>{{ f.id ? 'Modifier le badge' : 'Nouveau badge' }}</h3>

        <div class="bd-preview"><span class="bd-ico lg" [style.background]="f.color + '26'" [style.color]="f.color"><span class="material-icons">{{ f.icon || 'stars' }}</span></span>
          <div><strong>{{ f.name || 'Nom du badge' }}</strong><div class="adm-sub">Aperçu</div></div></div>

        <label class="adm-label">Nom affiché *</label>
        <input class="adm-input" maxlength="60" [(ngModel)]="f.name" />

        @if (!f.id) {
          <label class="adm-label">Identifiant technique * (minuscules, chiffres, _ — non modifiable ensuite)</label>
          <input class="adm-input" maxlength="40" [(ngModel)]="f.key" placeholder="ex. super_vendeur" />
        }

        <label class="adm-label">Description (affichée dans le guide)</label>
        <input class="adm-input" maxlength="300" [(ngModel)]="f.description" />
        <label class="adm-label">Comment l'obtenir (affiché dans le guide)</label>
        <input class="adm-input" maxlength="400" [(ngModel)]="f.how_to_get" />

        <label class="adm-label">Icône</label>
        <div class="bd-icons">@for (i of icons; track i) { <button type="button" class="bd-pick" [class.on]="f.icon === i" (click)="f.icon = i" [attr.aria-label]="i" [title]="i"><span class="material-icons">{{ i }}</span></button> }</div>
        <input class="adm-input" [(ngModel)]="f.icon" placeholder="ou nom Material Icons (ex. workspace_premium)" />

        <label class="adm-label">Couleur</label>
        <div class="adm-row" style="gap:10px"><input type="color" [(ngModel)]="f.color" style="width:48px;height:38px;border:0;background:none" /><input class="adm-input" [(ngModel)]="f.color" maxlength="7" /></div>

        <label class="adm-label">Attribution</label>
        <select class="adm-input" [(ngModel)]="f.auto_rule">
          <option value="">Manuelle (attribuée par l'équipe)</option>
          @for (r of rules(); track r.key) { <option [value]="r.key">Automatique — {{ r.label }}</option> }
        </select>
        @if (needsThreshold(f.auto_rule)) {
          <label class="adm-label">Seuil ({{ thresholdUnit(f.auto_rule) }})</label>
          <input class="adm-input" type="number" min="1" max="100000" [(ngModel)]="f.auto_threshold" />
        }
        @if (f.auto_rule) { <div class="adm-warn-box">Changer la règle efface les anciennes attributions automatiques de ce badge puis recalcule. Les badges donnés à la main sont conservés.</div> }

        <label class="adm-label">Où afficher ce badge</label>
        <div class="bd-zones">
          @for (z of zones(); track z.key) { <label class="bd-zone"><input type="checkbox" [checked]="f.zones.includes(z.key)" (change)="toggleZone(f, z.key)" /> {{ z.label }}</label> }
        </div>
        <div class="adm-row" style="gap:8px;margin:6px 0"><button type="button" class="adm-btn sm" (click)="f.zones = allZones()">Tout cocher</button><button type="button" class="adm-btn sm" (click)="f.zones = []">Tout décocher</button></div>

        <label class="bd-zone"><input type="checkbox" [(ngModel)]="f.is_active" /> Badge actif (décoché = masqué partout)</label>
        @if (!f.auto_rule) { <label class="bd-zone"><input type="checkbox" [(ngModel)]="f.sellers_can_award" /> Les vendeurs peuvent l'attribuer à leurs clients (Client Fidèle)</label> }

        <label class="adm-label">Ordre d'affichage (petit = en premier)</label>
        <input class="adm-input" type="number" min="0" max="10000" [(ngModel)]="f.sort_order" />

        @if (error()) { <div class="adm-error">{{ error() }}</div> }
        <div class="adm-actions">
          <button class="adm-btn" (click)="form.set(null)" [disabled]="busy()">Annuler</button>
          <button class="adm-btn primary" (click)="save()" [disabled]="busy()">{{ busy() ? 'Enregistrement…' : 'Enregistrer' }}</button>
        </div>
      </div>
    </div>
  }`,
  styles: [`
    .bd-help ul { margin: 6px 0 0 18px; padding: 0; font-size: .86rem; line-height: 1.55; color: var(--q-text-secondary); }
    .bd-grid { display: grid; gap: 12px; grid-template-columns: repeat(auto-fill, minmax(290px, 1fr)); }
    .bd-card.off { opacity: .6; }
    .bd-top { display: flex; align-items: center; gap: 10px; margin-bottom: 6px; }
    .bd-title { flex: 1; min-width: 0; } .bd-title strong { display: block; } .bd-title code { font-size: .7rem; color: var(--q-text-muted); }
    .bd-ico { width: 40px; height: 40px; border-radius: 12px; display: grid; place-items: center; flex-shrink: 0; }
    .bd-ico.lg { width: 52px; height: 52px; } .bd-ico .material-icons { font-size: 22px; } .bd-ico.lg .material-icons { font-size: 28px; }
    .bd-modal { max-height: calc(100dvh - 32px); overflow-y: auto; width: min(560px, 100%); }
    .bd-preview { display: flex; align-items: center; gap: 12px; padding: 10px; border-radius: 14px; background: var(--q-bg-primary); margin-bottom: 8px; }
    .bd-icons { display: grid; grid-template-columns: repeat(auto-fill, minmax(40px, 1fr)); gap: 6px; margin-bottom: 8px; max-height: 150px; overflow-y: auto; }
    .bd-pick { height: 40px; border-radius: 10px; cursor: pointer; background: var(--q-bg-card); color: var(--q-text-secondary); border: 1px solid var(--q-border); }
    .bd-pick.on { border-color: var(--q-accent); color: var(--q-accent); background: color-mix(in srgb, var(--q-accent) 12%, transparent); }
    .bd-zones { display: grid; grid-template-columns: repeat(auto-fill, minmax(170px, 1fr)); gap: 6px; }
    .bd-zone { display: flex; align-items: center; gap: 8px; font-size: .84rem; padding: 4px 0; cursor: pointer; }
  `],
})
export class AdminBadgesPage implements OnInit {
  private admin = inject(AdminService);
  private notif = inject(NotificationService);
  private confirm = inject(ConfirmService);

  icons = ICONS;
  items = signal<any[]>([]);
  zones = signal<{ key: string; label: string }[]>([]);
  rules = signal<{ key: string; label: string; needs_threshold: boolean }[]>([]);
  loading = signal(true); busy = signal(false); syncing = signal(false); error = signal('');
  form = signal<BadgeForm | null>(null);
  allZones = computed(() => this.zones().map(z => z.key));

  ngOnInit() { this.load(); }

  load() {
    this.admin.getBadgeCatalog().subscribe({
      next: r => { this.items.set(r.badges); this.zones.set(r.zones); this.rules.set(r.auto_rules); this.loading.set(false); },
      error: e => { this.loading.set(false); this.notif.error(errMsg(e)); },
    });
  }

  openNew() { this.error.set(''); this.form.set({ ...EMPTY, zones: this.allZones() }); }
  edit(b: any) {
    this.error.set('');
    this.form.set({
      id: b.id, key: b.key, name: b.name, description: b.description ?? '', how_to_get: b.how_to_get ?? '', icon: b.icon, color: b.color,
      auto_rule: b.auto_rule ?? '', auto_threshold: b.auto_threshold, zones: [...(b.zones ?? [])], is_active: b.is_active,
      sellers_can_award: b.sellers_can_award, sort_order: b.sort_order, is_system: b.is_system,
    });
  }

  toggleZone(f: BadgeForm, key: string) { f.zones = f.zones.includes(key) ? f.zones.filter(z => z !== key) : [...f.zones, key]; }
  needsThreshold(rule: string) { return !!this.rules().find(r => r.key === rule)?.needs_threshold; }
  thresholdUnit(rule: string) { return ({ sales_completed: 'ventes', account_age_days: 'jours', trust_score: '% de confiance' } as any)[rule] ?? ''; }
  ruleLabel(b: any) { const r = this.rules().find(x => x.key === b.auto_rule); return (r?.label ?? b.auto_rule) + (b.auto_threshold ? ` : ${b.auto_threshold}` : ''); }
  zonesLabel(b: any) {
    const map = new Map(this.zones().map(z => [z.key, z.label]));
    const z: string[] = b.zones ?? [];
    return z.length === 0 ? 'Affiché nulle part' : z.length === this.zones().length ? 'Partout' : z.map(k => map.get(k) ?? k).join(', ');
  }

  save() {
    const f = this.form(); if (!f) return;
    const body: any = {
      name: f.name.trim(), description: f.description || null, how_to_get: f.how_to_get || null, icon: f.icon.trim(), color: f.color,
      auto_rule: f.auto_rule || null, auto_threshold: f.auto_rule && this.needsThreshold(f.auto_rule) ? f.auto_threshold : null,
      zones: f.zones, is_active: f.is_active, sellers_can_award: !f.auto_rule && f.sellers_can_award, sort_order: f.sort_order ?? 0,
    };
    if (!f.id) body.key = f.key.trim();
    this.busy.set(true); this.error.set('');
    const req = f.id ? this.admin.updateBadge(f.id, body) : this.admin.createBadge(body);
    req.subscribe({
      next: () => { this.busy.set(false); this.form.set(null); this.notif.success('Badge enregistré'); this.load(); },
      error: e => { this.busy.set(false); this.error.set(errMsg(e)); },
    });
  }

  async remove(b: any) {
    const r = await this.confirm.ask({
      title: `Supprimer « ${b.name} » ?`,
      message: `Ce badge sera retiré aux ${b.holders_count} utilisateur(s) qui l'ont. Action irréversible.`,
      confirmLabel: 'Supprimer', danger: true, icon: 'delete_forever',
    });
    if (!r.confirmed) return;
    this.admin.deleteBadge(b.id).subscribe({ next: () => { this.notif.success('Badge supprimé'); this.load(); }, error: e => this.notif.error(errMsg(e)) });
  }

  sync() {
    this.syncing.set(true);
    this.admin.syncBadges().subscribe({
      next: () => { this.syncing.set(false); this.notif.success('Badges automatiques recalculés'); this.load(); },
      error: e => { this.syncing.set(false); this.notif.error(errMsg(e)); },
    });
  }
}
