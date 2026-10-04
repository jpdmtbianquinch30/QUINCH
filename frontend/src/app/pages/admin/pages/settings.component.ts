import { Component, OnInit, computed, inject, signal } from '@angular/core';
import { DatePipe } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { AdminService } from '../../../core/services/admin.service';
import { NotificationService } from '../../../core/services/notification.service';
import { AdminModalComponent, ModalResult } from '../shared/admin-modal.component';
import { errMsg, mediaUrl } from '../shared/admin-utils';

const FEATURES: [string, string][] = [
  ['negotiation', 'Négociation de prix'], ['follow', 'Abonnements'], ['reviews', 'Avis'], ['badges', 'Badges'],
  ['sharing', 'Partage'], ['chat_audio', 'Messages vocaux'], ['chat_file', 'Envoi de fichiers'],
  ['favorites_collections', 'Collections de favoris'], ['purchases', 'Achats'],
];

/** Réglages : message défilant, bannières du feed, boost Premium, modération, mots interdits, maintenance, prix et interrupteurs. */
@Component({
  selector: 'adm-settings',
  standalone: true,
  imports: [DatePipe, FormsModule, AdminModalComponent],
  styleUrl: '../shared/admin-common.scss',
  template: `
  <div class="adm-page">
    <div class="adm-tabs">
      @if (has('feed.ticker_enabled')) { <button class="adm-tab" [class.active]="tab() === 'feed'" (click)="tab.set('feed')">Feed</button>
        <button class="adm-tab" [class.active]="tab() === 'banners'" (click)="tab.set('banners'); loadBanners()">Bannières</button>
        <button class="adm-tab" [class.active]="tab() === 'moderation'" (click)="tab.set('moderation')">Modération</button> }
      @if (has('maintenance.enabled')) { <button class="adm-tab" [class.active]="tab() === 'system'" (click)="tab.set('system')">Système</button> }
    </div>

    @if (tab() === 'feed') {
      <div class="adm-card">
        <h4>Message défilant (bandeau INFO)</h4>
        <label class="adm-label"><input type="checkbox" [(ngModel)]="v['feed.ticker_enabled']" /> Afficher le bandeau</label>
        <label class="adm-label">Libellé</label><input class="adm-input" [(ngModel)]="v['feed.ticker_label']" />
        <label class="adm-label">Messages (un par ligne ; vide = messages d'origine de l'application)</label>
        <textarea class="adm-input" rows="6" [ngModel]="lines('feed.ticker_messages')" (ngModelChange)="setLines('feed.ticker_messages', $event)"></textarea>
        <label class="adm-label">Boost des annonces Premium dans « Pour toi » (0 à 200)</label><input class="adm-input" type="number" min="0" max="200" [(ngModel)]="v['feed.premium_boost']" />
        <div class="adm-actions"><button class="adm-btn primary" (click)="save(['feed.ticker_enabled','feed.ticker_label','feed.ticker_messages','feed.premium_boost'])">Enregistrer</button></div>
      </div>
    }

    @if (tab() === 'banners') {
      <div class="adm-row" style="margin-bottom:12px"><button class="adm-btn primary" (click)="newBanner()">+ Nouvelle bannière</button>
        <span class="adm-sub">Plusieurs bannières actives tournent en rotation. Sans bannière active, l'image d'origine reste affichée.</span></div>
      <div class="adm-grid" style="grid-template-columns:repeat(auto-fill,minmax(280px,1fr))">
        @for (b of banners(); track b.id) {
          <div class="adm-card"><img [src]="b.image_url" alt="" style="width:100%;border-radius:8px;max-height:110px;object-fit:cover" />
            <p style="margin:8px 0 2px"><strong>{{ b.title }}</strong> <span class="adm-chip" [class.ok]="b.is_active" [class.bad]="!b.is_active">{{ b.is_active ? 'active' : 'inactive' }}</span></p>
            <p class="adm-sub">Ordre {{ b.sort_order }}@if (b.city) { · {{ b.city }} }@if (b.starts_at) { · du {{ b.starts_at | date:'dd/MM' }} }@if (b.ends_at) { au {{ b.ends_at | date:'dd/MM' }} }</p>
            <div class="adm-row"><button class="adm-btn sm" (click)="editBanner(b)">Modifier</button><button class="adm-btn sm" (click)="toggleBanner(b)">{{ b.is_active ? 'Désactiver' : 'Activer' }}</button><button class="adm-btn sm danger" (click)="delBanner = b">Supprimer</button></div></div>
        } @empty { <div class="adm-empty">Aucune bannière personnalisée.</div> }
      </div>
    }

    @if (tab() === 'moderation') {
      <div class="adm-card">
        <h4>Avertissements & masquage automatique</h4>
        <div class="adm-inline-form">
          <div><label class="adm-label">Avertissements avant suspension</label><input class="adm-input" type="number" min="1" max="20" [(ngModel)]="v['moderation.strike_threshold']" /></div>
          <div><label class="adm-label">Durée de la suspension auto (jours)</label><input class="adm-input" type="number" min="1" max="365" [(ngModel)]="v['moderation.strike_suspension_days']" /></div>
          <div><label class="adm-label">Validité d'un avertissement (jours, 0 = illimité)</label><input class="adm-input" type="number" min="0" [(ngModel)]="v['moderation.strike_expiry_days']" /></div>
        </div>
        <div class="adm-inline-form">
          <div><label class="adm-label">Comptes distincts avant masquage auto</label><input class="adm-input" type="number" min="2" max="50" [(ngModel)]="v['moderation.auto_hide_reporters']" /></div>
          <div><label class="adm-label">Poids minimal cumulé (confiance des signaleurs)</label><input class="adm-input" type="number" step="0.1" [(ngModel)]="v['moderation.auto_hide_weight']" /></div>
        </div>
        <label class="adm-label"><input type="checkbox" [(ngModel)]="v['moderation.screen_phone']" /> Signaler les numéros de téléphone dans les annonces</label>
        <label class="adm-label"><input type="checkbox" [(ngModel)]="v['moderation.screen_links']" /> Signaler les liens externes</label>
        <label class="adm-label">Mots interdits (un par ligne) — l'annonce reste publiée mais remonte dans la file « suspects »</label>
        <textarea class="adm-input" rows="6" [ngModel]="lines('moderation.banned_words')" (ngModelChange)="setLines('moderation.banned_words', $event)"></textarea>
        <div class="adm-actions"><button class="adm-btn primary" (click)="save(modKeys)">Enregistrer</button></div>
      </div>
      @if (has('notifications.templates')) {
        <div class="adm-card" style="margin-top:12px"><h4>Modèles de notification</h4>
          @for (t of templates; track $index) { <div class="adm-inline-form" style="margin-bottom:8px"><input class="adm-input" placeholder="Nom" [(ngModel)]="t.name" /><input class="adm-input" placeholder="Titre" [(ngModel)]="t.title" /><input class="adm-input" placeholder="Message" [(ngModel)]="t.body" /><button class="adm-btn sm danger" style="flex:0" (click)="templates.splice($index, 1)">✕</button></div> }
          <div class="adm-actions"><button class="adm-btn sm" (click)="templates.push({ name: '', title: '', body: '' })">+ Modèle</button><button class="adm-btn primary" (click)="saveTemplates()">Enregistrer</button></div></div>
      }
    }

    @if (tab() === 'system') {
      <div class="adm-warn-box">Ces réglages agissent immédiatement sur toute la plateforme. Le mot de passe est demandé à l'enregistrement.</div>
      <div class="adm-card"><h4>Mode maintenance</h4>
        <label class="adm-label"><input type="checkbox" [(ngModel)]="v['maintenance.enabled']" /> Activer la maintenance (l'API répond 503 sauf admin, connexion et webhooks de paiement)</label>
        <label class="adm-label">Message affiché</label><input class="adm-input" [(ngModel)]="v['maintenance.message']" /></div>
      <div class="adm-card" style="margin-top:12px"><h4>Prix</h4><div class="adm-inline-form">
        <div><label class="adm-label">Premium mensuel (F)</label><input class="adm-input" type="number" [(ngModel)]="v['premium.price_monthly']" /></div>
        <div><label class="adm-label">Premium annuel (F)</label><input class="adm-input" type="number" [(ngModel)]="v['premium.price_annual']" /></div>
        <div><label class="adm-label">Frais de publication avec vidéo (F)</label><input class="adm-input" type="number" [(ngModel)]="v['premium.listing_fee_with_video']" /></div></div></div>
      <div class="adm-card" style="margin-top:12px"><h4>Fonctionnalités</h4>
        @for (f of features; track f[0]) { <label class="adm-label"><input type="checkbox" [(ngModel)]="v['features.' + f[0]]" /> {{ f[1] }}</label> }</div>
      <div class="adm-actions"><button class="adm-btn primary" (click)="error.set(''); pwd.set(true)">Enregistrer les réglages système…</button></div>
    }
  </div>

  @if (bform(); as b) {
    <div class="adm-overlay" (click)="bform.set(null)"><div class="adm-modal" (click)="$event.stopPropagation()">
      <h3>{{ b.id ? 'Modifier la bannière' : 'Nouvelle bannière' }}</h3>
      <label class="adm-label">Titre</label><input class="adm-input" [(ngModel)]="b.title" />
      <label class="adm-label">Image {{ b.id ? '(laisser vide pour conserver)' : '' }} — format large conseillé (ex. 1600×400)</label><input type="file" accept="image/*" (change)="bfile = $any($event.target).files[0]" />
      <label class="adm-label">Lien au clic (optionnel)</label><input class="adm-input" [(ngModel)]="b.link_url" placeholder="https://…" />
      <div class="adm-inline-form"><div><label class="adm-label">Début</label><input class="adm-input" type="date" [(ngModel)]="b.starts_at" /></div><div><label class="adm-label">Fin</label><input class="adm-input" type="date" [(ngModel)]="b.ends_at" /></div></div>
      <div class="adm-inline-form"><div><label class="adm-label">Ville (vide = toutes)</label><input class="adm-input" [(ngModel)]="b.city" /></div><div><label class="adm-label">Ordre</label><input class="adm-input" type="number" [(ngModel)]="b.sort_order" /></div></div>
      <label class="adm-label"><input type="checkbox" [(ngModel)]="b.is_active" /> Active</label>
      @if (error()) { <div class="adm-error">{{ error() }}</div> }
      <div class="adm-actions"><button class="adm-btn" (click)="bform.set(null)">Annuler</button><button class="adm-btn primary" [disabled]="!b.title" (click)="saveBanner()">Enregistrer</button></div>
    </div></div>
  }
  @if (delBanner) { <adm-modal title="Supprimer la bannière" [danger]="true" [needReason]="false" (cancel)="delBanner = null" (confirm)="removeBanner()"></adm-modal> }
  @if (pwd()) { <adm-modal title="Confirmer les réglages système" [needReason]="false" [needPassword]="true" [busy]="busy()" [error]="error()" (cancel)="pwd.set(false)" (confirm)="saveSystem($event)"></adm-modal> }`,
})
export class AdminSettingsPage implements OnInit {
  private admin = inject(AdminService);
  private notif = inject(NotificationService);

  features = FEATURES;
  modKeys = ['moderation.strike_threshold', 'moderation.strike_suspension_days', 'moderation.strike_expiry_days', 'moderation.auto_hide_reporters', 'moderation.auto_hide_weight', 'moderation.banned_words', 'moderation.screen_phone', 'moderation.screen_links'];
  tab = signal<'feed' | 'banners' | 'moderation' | 'system'>('feed');
  schema = signal<Record<string, any>>({});
  v: Record<string, any> = {};
  templates: { name: string; title: string; body: string }[] = [];
  banners = signal<any[]>([]);
  bform = signal<any>(null); bfile: File | null = null; delBanner: any = null;
  pwd = signal(false); busy = signal(false); error = signal('');

  has = (k: string) => k in this.schema();
  mediaUrl = mediaUrl;

  ngOnInit() {
    this.admin.getSettings().subscribe(r => {
      this.schema.set(r.settings);
      for (const [k, s] of Object.entries<any>(r.settings)) this.v[k] = s.value;
      this.templates = JSON.parse(JSON.stringify(r.settings['notifications.templates']?.value ?? []));
      if (!this.has('feed.ticker_enabled')) this.tab.set(this.has('maintenance.enabled') ? 'system' : 'feed');
    });
  }

  lines(k: string) { return (this.v[k] ?? []).join('\n'); }
  setLines(k: string, text: string) { this.v[k] = text.split('\n').map(x => x.trim()).filter(Boolean); }

  save(keys: string[]) {
    const settings: Record<string, any> = {}; keys.forEach(k => { if (k in this.v) settings[k] = this.v[k]; });
    this.admin.saveSettings(settings).subscribe({ next: () => this.notif.success('Réglages enregistrés'), error: e => this.notif.error(errMsg(e)) });
  }
  saveTemplates() {
    const clean = this.templates.filter(t => t.name && t.title && t.body);
    this.admin.saveSettings({ 'notifications.templates': clean }).subscribe({ next: () => this.notif.success('Modèles enregistrés'), error: e => this.notif.error(errMsg(e)) });
  }
  saveSystem(res: ModalResult) {
    const keys = Object.keys(this.schema()).filter(k => this.schema()[k].group === 'system');
    const settings: Record<string, any> = {}; keys.forEach(k => settings[k] = this.v[k]);
    this.busy.set(true);
    this.admin.saveSystemSettings(settings, res.password).subscribe({
      next: () => { this.busy.set(false); this.pwd.set(false); this.notif.success('Réglages système enregistrés'); },
      error: e => { this.busy.set(false); this.error.set(errMsg(e)); },
    });
  }

  loadBanners() { this.admin.getBanners().subscribe(r => this.banners.set(r.banners)); }
  newBanner() { this.error.set(''); this.bfile = null; this.bform.set({ title: '', link_url: '', starts_at: '', ends_at: '', city: '', sort_order: 0, is_active: true }); }
  editBanner(b: any) { this.error.set(''); this.bfile = null; this.bform.set({ ...b, starts_at: b.starts_at?.slice(0, 10) ?? '', ends_at: b.ends_at?.slice(0, 10) ?? '' }); }
  saveBanner() {
    const b = this.bform();
    if (!b.id && !this.bfile) { this.error.set('Choisissez une image.'); return; }
    const fd = new FormData();
    fd.append('title', b.title); fd.append('sort_order', String(b.sort_order ?? 0)); fd.append('is_active', b.is_active ? '1' : '0');
    ['link_url', 'city', 'starts_at', 'ends_at'].forEach(k => fd.append(k, b[k] ?? ''));
    if (this.bfile) fd.append('image', this.bfile);
    this.admin.saveBanner(fd, b.id).subscribe({ next: () => { this.bform.set(null); this.notif.success('Bannière enregistrée'); this.loadBanners(); }, error: e => this.error.set(errMsg(e)) });
  }
  toggleBanner(b: any) {
    const fd = new FormData(); fd.append('is_active', b.is_active ? '0' : '1');
    this.admin.saveBanner(fd, b.id).subscribe({ next: () => this.loadBanners(), error: e => this.notif.error(errMsg(e)) });
  }
  removeBanner() { this.admin.deleteBanner(this.delBanner.id).subscribe({ next: () => { this.delBanner = null; this.notif.success('Bannière supprimée'); this.loadBanners(); }, error: e => this.notif.error(errMsg(e)) }); }
}
