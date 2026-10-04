import { Component, OnInit, computed, inject, signal } from '@angular/core';
import { DatePipe } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { ActivatedRoute, RouterLink } from '@angular/router';
import { AdminService } from '../../../core/services/admin.service';
import { NotificationService } from '../../../core/services/notification.service';
import { AdminModalComponent, ModalResult } from '../shared/admin-modal.component';
import { errMsg, fmtMoney, mediaUrl, statusClass } from '../shared/admin-utils';

type Act = 'replace' | 'hide' | 'delete' | 'restore' | 'status' | 'edit' | 'rm-image' | 'rm-poster' | 'rm-video' | 'bulk-hide' | 'bulk-delete' | 'bulk-restore';

/** Module Produits : liste complète (tous statuts), filtres, fiche détaillée, actions unitaires/en masse, gestion des médias. */
@Component({
  selector: 'adm-products',
  standalone: true,
  imports: [DatePipe, FormsModule, RouterLink, AdminModalComponent],
  styleUrl: '../shared/admin-common.scss',
  template: `
  <div class="adm-page">
    <div class="adm-inline-form" style="margin-bottom:12px">
      <input class="adm-input" placeholder="Rechercher titre, description, id…" [(ngModel)]="f.search" (keyup.enter)="load(1)" />
      <select class="adm-input" [(ngModel)]="f.status" (change)="load(1)"><option value="">Tous statuts</option><option value="active">Actif</option><option value="disabled">Masqué</option><option value="sold">Vendu</option><option value="draft">Brouillon</option><option value="paused">En pause</option><option value="expired">Expiré</option></select>
      <select class="adm-input" [(ngModel)]="f.category_id" (change)="load(1)"><option value="">Toutes catégories</option>@for (c of cats(); track c.id) { <option [value]="c.id">{{ c.name }}</option> }</select>
      <select class="adm-input" [(ngModel)]="f.reported" (change)="load(1)"><option value="">Signalement : tous</option><option value="1">Signalés</option></select>
      <select class="adm-input" [(ngModel)]="f.flagged" (change)="load(1)"><option value="">Pré-filtrage : tous</option><option value="1">Suspects (mots/tél/lien)</option></select>
      <select class="adm-input" [(ngModel)]="f.has_video" (change)="load(1)"><option value="">Vidéo : toutes</option><option value="1">Avec vidéo</option><option value="0">Sans vidéo</option></select>
      <select class="adm-input" [(ngModel)]="f.trashed" (change)="load(1)"><option value="">Non supprimés</option><option value="with">Avec supprimés</option><option value="only">Supprimés seulement</option></select>
      <input class="adm-input" type="number" placeholder="Prix min" [(ngModel)]="f.min_price" (change)="load(1)" />
      <input class="adm-input" type="number" placeholder="Prix max" [(ngModel)]="f.max_price" (change)="load(1)" />
      <input class="adm-input" type="date" [(ngModel)]="f.from" (change)="load(1)" /><input class="adm-input" type="date" [(ngModel)]="f.to" (change)="load(1)" />
    </div>

    @if (sel().size) {
      <div class="adm-row" style="margin-bottom:10px"><strong>{{ sel().size }} sélectionné(s)</strong>
        <button class="adm-btn sm warn" (click)="ask('bulk-hide')">Masquer</button>
        <button class="adm-btn sm success" (click)="ask('bulk-restore')">Réactiver</button>
        <button class="adm-btn sm danger" (click)="ask('bulk-delete')">Supprimer</button></div>
    }

    <div class="adm-table-wrap"><table class="adm-table">
      <thead><tr><th></th><th>Annonce</th><th>Vendeur</th><th>Statut</th><th>Prix</th><th>Alertes</th><th>Date</th></tr></thead>
      <tbody>
        @for (p of items(); track p.id) {
          <tr class="clickable" (click)="openDetail(p.id)">
            <td (click)="$event.stopPropagation()"><input type="checkbox" [checked]="sel().has(p.id)" (change)="toggle(p.id)" /></td>
            <td><strong>{{ p.title }}</strong>@if (p.is_pinned) { <span class="adm-chip info">📌</span> }<div class="adm-sub">{{ p.category?.name }}</div></td>
            <td>{{ p.user?.full_name }}<div class="adm-sub">confiance {{ p.user?.trust_score }}</div></td>
            <td><span class="adm-chip" [class]="'adm-chip ' + sc(p.status)">{{ p.deleted_at ? 'supprimée' : p.status }}</span>@if (p.hidden_by_system) { <span class="adm-chip warn">auto</span> }</td>
            <td>{{ money(p.price) }}</td>
            <td>@if (p.pending_reports_count) { <span class="adm-chip bad">{{ p.pending_reports_count }} signal.</span> }
              @if (p.screening_flags?.length) { <span class="adm-chip warn" [title]="p.screening_flags.join(', ')">suspect</span> }
              @if (p.video?.moderation_status === 'pending') { <span class="adm-chip">vidéo à revoir</span> }</td>
            <td class="adm-sub">{{ p.created_at | date:'dd/MM/yy' }}</td>
          </tr>
        } @empty { <tr><td colspan="7" class="adm-empty">{{ loading() ? 'Chargement…' : 'Aucune annonce.' }}</td></tr> }
      </tbody></table></div>
    @if (last() > 1) { <div class="adm-pager"><button class="adm-btn sm" [disabled]="page() <= 1" (click)="load(page() - 1)">‹</button>Page {{ page() }} / {{ last() }} · {{ total() }} annonces<button class="adm-btn sm" [disabled]="page() >= last()" (click)="load(page() + 1)">›</button></div> }
  </div>

  @if (detail(); as d) {
    <aside class="adm-drawer">
      <button class="adm-btn sm adm-drawer-close" (click)="detail.set(null)">Fermer ✕</button>
      <h3 style="margin-top:0">{{ d.product.title }} @if (d.product.deleted_at) { <span class="adm-chip bad">supprimée</span> }</h3>
      <div class="adm-row"><span class="adm-chip" [class]="'adm-chip ' + sc(d.product.status)">{{ d.product.status }}</span>
        @if (d.product.moderation_reason) { <span class="adm-sub">Motif : {{ d.product.moderation_reason }}</span> }</div>
      <dl class="adm-kv" style="margin-top:12px">
        <dt>Prix</dt><dd>{{ money(d.product.price) }}</dd>
        <dt>Catégorie</dt><dd>{{ d.product.category?.name }}</dd>
        <dt>Vendeur</dt><dd><a [routerLink]="['../users']" [queryParams]="{ open: d.product.user_id }">{{ d.product.user?.full_name }}</a> · {{ d.seller_stats.products }} annonce(s), {{ d.seller_stats.disabled }} masquée(s), {{ d.seller_stats.rejected_videos }} vidéo(s) rejetée(s)</dd>
        <dt>Pré-filtrage</dt><dd>{{ d.product.screening_flags?.join(', ') || '—' }}</dd>
        <dt>Description</dt><dd style="white-space:pre-wrap">{{ d.product.description || '—' }}</dd>
      </dl>

      <div class="adm-section">Médias</div>
      @if (d.product.video) {
        @if (d.product.video.preview?.video) { <video class="adm-video" controls preload="metadata" [src]="d.product.video.preview.video"></video> }
        <div class="adm-row" style="margin:6px 0"><span class="adm-chip">{{ d.product.video.moderation_status }}</span>
          @if (admin.can('media.remove')) { <button class="adm-btn sm danger" (click)="ask('rm-video')">Retirer la vidéo</button> }</div>
      }
      <div class="adm-media">
        @if (d.raw_poster) { <figure><img [src]="img(d.raw_poster)" alt="couverture" /><figcaption>
          @if (admin.can('media.remove')) { <button class="adm-btn sm danger" (click)="ask('rm-poster')">Retirer</button>
            <label class="adm-btn sm">Remplacer<input type="file" accept="image/*" hidden (change)="replace($event, 'poster')" /></label> }</figcaption></figure> }
        @for (im of d.raw_images; track $index) {
          <figure><img [src]="img(im)" alt="image" /><figcaption>
            @if (admin.can('media.remove')) { <button class="adm-btn sm danger" (click)="idx = $index; ask('rm-image')">Retirer</button>
              <label class="adm-btn sm">Remplacer<input type="file" accept="image/*" hidden (change)="replace($event, 'image', $index)" /></label> }</figcaption></figure>
        }
      </div>

      <div class="adm-section">Actions</div>
      <div class="adm-row">
        @if (d.product.deleted_at || d.product.status === 'disabled') { @if (admin.can('products.moderate')) { <button class="adm-btn success sm" (click)="ask('restore')">Réactiver</button> } }
        @else if (admin.can('products.moderate')) { <button class="adm-btn warn sm" (click)="ask('hide')">Masquer</button> }
        @if (!d.product.deleted_at && admin.can('products.moderate')) { <button class="adm-btn danger sm" (click)="ask('delete')">Supprimer</button> }
        @if (admin.can('products.edit_content')) { <button class="adm-btn sm" (click)="openEdit()">Corriger le contenu</button> }
        @if (admin.can('products.pin')) { <button class="adm-btn sm" (click)="pin(d.product)">{{ d.product.is_pinned ? 'Désépingler' : 'Épingler en tête du feed' }}</button> }
        @if (admin.can('products.force_status')) { <button class="adm-btn sm" (click)="ask('status')">Forcer un statut</button> }
      </div>

      <div class="adm-section">Signalements ({{ d.reports.length }})</div>
      <ul class="adm-timeline">@for (r of d.reports; track r.id) { <li>{{ r.created_at | date:'dd/MM HH:mm' }} · <strong>{{ r.reason }}</strong> · {{ r.status }} · par {{ r.reporter?.full_name }}<br><span class="adm-sub">{{ r.description }}</span></li> } @empty { <li>Aucun.</li> }</ul>
      <div class="adm-section">Historique de modération</div>
      <ul class="adm-timeline">@for (h of d.history; track h.id) { <li>{{ h.created_at | date:'dd/MM HH:mm' }} · <strong>{{ h.action }}</strong> par {{ h.admin?.full_name || 'Système' }}@if (h.metadata?.reason) { — {{ h.metadata.reason }} }</li> } @empty { <li>Aucune action.</li> }</ul>
    </aside>
  }

  @if (dlg(); as a) {
    <adm-modal [title]="title(a)" [danger]="isDanger(a)" [needReason]="true" [busy]="busy()" [error]="error()" [presets]="presets" (cancel)="dlg.set(null)" (confirm)="run($event)">
      @if (a === 'status') { <label class="adm-label">Nouveau statut</label>
        <select class="adm-input" [(ngModel)]="newStatus"><option value="active">Actif</option><option value="draft">Brouillon</option><option value="paused">En pause</option><option value="sold">Vendu</option><option value="reserved">Réservé</option><option value="expired">Expiré</option><option value="disabled">Masqué</option></select> }
      @if (a === 'edit') {
        <label class="adm-label">Titre</label><input class="adm-input" [(ngModel)]="edit.title" />
        <label class="adm-label">Description</label><textarea class="adm-input" rows="4" [(ngModel)]="edit.description"></textarea>
        @if (admin.can('products.force_status')) { <label class="adm-label">Prix</label><input class="adm-input" type="number" [(ngModel)]="edit.price" /> }
      }
    </adm-modal>
  }`,
})
export class AdminProductsPage implements OnInit {
  admin = inject(AdminService);
  private notif = inject(NotificationService);
  private route = inject(ActivatedRoute);

  f: Record<string, any> = { search: '', status: '', category_id: '', reported: '', flagged: '', has_video: '', trashed: '', min_price: '', max_price: '', from: '', to: '' };
  items = signal<any[]>([]); cats = signal<any[]>([]); loading = signal(true);
  page = signal(1); last = signal(1); total = signal(0);
  sel = signal<Set<string>>(new Set());
  detail = signal<any>(null);
  dlg = signal<Act | null>(null);
  busy = signal(false); error = signal('');
  newStatus = 'active'; idx = 0;
  edit: any = {};
  presets = ['Contenu interdit', 'Arnaque / fraude', 'Contrefaçon', 'Contenu inapproprié', 'Coordonnées / lien externe', 'Photo non conforme', 'Informations trompeuses'];
  money = fmtMoney; sc = statusClass;
  selCount = computed(() => this.sel().size);

  ngOnInit() {
    this.admin.getCategories().subscribe(r => this.cats.set(r.categories));
    this.load(1);
    const open = this.route.snapshot.queryParamMap.get('open');
    if (open) this.openDetail(open);
  }

  img(p: string) { return mediaUrl(p); }
  toggle(id: string) { const s = new Set(this.sel()); s.has(id) ? s.delete(id) : s.add(id); this.sel.set(s); }

  load(page: number) {
    this.loading.set(true);
    this.admin.getProducts({ ...this.f, page }).subscribe({
      next: r => { this.items.set(r.data); this.page.set(r.current_page); this.last.set(r.last_page); this.total.set(r.total); this.loading.set(false); },
      error: e => { this.loading.set(false); this.notif.error(errMsg(e)); },
    });
  }

  openDetail(id: string) { this.admin.getProduct(id).subscribe({ next: d => this.detail.set(d), error: e => this.notif.error(errMsg(e)) }); }
  private refresh() { const id = this.detail()?.product?.id; this.load(this.page()); if (id) this.openDetail(id); }

  ask(a: Act) { this.error.set(''); this.dlg.set(a); }
  openEdit() { const p = this.detail().product; this.edit = { title: p.title, description: p.description, price: p.price }; this.ask('edit'); }
  title(a: Act) { return ({ hide: "Masquer l'annonce", delete: "Supprimer l'annonce (conservée pour les preuves)", restore: "Réactiver l'annonce", status: 'Forcer le statut', edit: 'Corriger le contenu', 'rm-image': "Retirer l'image", 'rm-poster': 'Retirer la couverture', 'rm-video': 'Retirer la vidéo', replace: 'Remplacer le média', 'bulk-hide': 'Masquer la sélection', 'bulk-delete': 'Supprimer la sélection', 'bulk-restore': 'Réactiver la sélection' } as any)[a]; }
  isDanger(a: Act) { return ['delete', 'rm-image', 'rm-poster', 'rm-video', 'bulk-delete'].includes(a); }

  run(res: ModalResult) {
    const a = this.dlg()!; const id = this.detail()?.product?.id; const reason = res.reason;
    this.busy.set(true);
    let req: any;
    switch (a) {
      case 'replace': req = this.admin.replaceMedia(id, this.pending!.target, reason, this.pending!.file, this.pending!.index); break;
      case 'hide': req = this.admin.hideProduct(id, reason); break;
      case 'delete': req = this.admin.deleteProduct(id, reason); break;
      case 'restore': req = this.admin.restoreProduct(id, reason); break;
      case 'status': req = this.admin.forceProductStatus(id, this.newStatus, reason); break;
      case 'edit': req = this.admin.updateProduct(id, { ...this.edit, reason }); break;
      case 'rm-image': req = this.admin.removeMedia(id, 'image', reason, this.idx); break;
      case 'rm-poster': req = this.admin.removeMedia(id, 'poster', reason); break;
      case 'rm-video': req = this.admin.removeProductVideo(id, reason); break;
      case 'bulk-hide': req = this.admin.bulkProducts([...this.sel()], 'hide', reason); break;
      case 'bulk-delete': req = this.admin.bulkProducts([...this.sel()], 'delete', reason); break;
      case 'bulk-restore': req = this.admin.bulkProducts([...this.sel()], 'restore', reason); break;
    }
    req.subscribe({
      next: () => { this.busy.set(false); this.dlg.set(null); this.sel.set(new Set()); this.notif.success('Action effectuée'); this.refresh(); },
      error: (e: any) => { this.busy.set(false); this.error.set(errMsg(e)); },
    });
  }

  pin(p: any) { this.admin.pinProduct(p.id, !p.is_pinned).subscribe({ next: () => { this.notif.success('Fait'); this.refresh(); }, error: e => this.notif.error(errMsg(e)) }); }

  private pending: { file: File; target: 'image' | 'poster'; index?: number } | null = null;

  /** Le fichier est choisi d'abord, puis le modal demande le motif (pas de prompt() natif). */
  replace(ev: Event, target: 'image' | 'poster', index?: number) {
    const input = ev.target as HTMLInputElement;
    const file = input.files?.[0]; if (!file) return;
    this.pending = { file, target, index };
    input.value = '';
    this.ask('replace');
  }
}
