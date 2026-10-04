import { Component, HostListener, OnInit, inject, signal } from '@angular/core';
import { DatePipe } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { RouterLink } from '@angular/router';
import { AdminService } from '../../../core/services/admin.service';
import { NotificationService } from '../../../core/services/notification.service';
import { AdminModalComponent, ModalResult } from '../shared/admin-modal.component';
import { errMsg, mediaUrl } from '../shared/admin-utils';

/**
 * Post-modération vidéo : file priorisée, lecteur intégré (URL signée), miniature,
 * historique du vendeur, motifs prédéfinis, actions clavier et actions en masse.
 * Raccourcis : J/K naviguer · A approuver · R rejeter · F mettre en vérification.
 */
@Component({
  selector: 'adm-moderation',
  standalone: true,
  imports: [DatePipe, FormsModule, RouterLink, AdminModalComponent],
  styleUrl: '../shared/admin-common.scss',
  template: `
  <div class="adm-page">
    <div class="adm-tabs">
      @for (t of tabs; track t.key) { <button class="adm-tab" [class.active]="status() === t.key" (click)="setStatus(t.key)">{{ t.label }}</button> }
      <span style="flex:1"></span>
      <input class="adm-input inline" placeholder="Vendeur…" [(ngModel)]="search" (keyup.enter)="load(1)" />
    </div>
    <p class="adm-muted">Les vidéos « en attente » sont déjà visibles dans le feed (publication immédiate). Un rejet les retire partout.
      Raccourcis : <kbd>J</kbd>/<kbd>K</kbd> naviguer · <kbd>A</kbd> approuver · <kbd>R</kbd> rejeter · <kbd>F</kbd> vérification.</p>

    @if (selected().size) {
      <div class="adm-row" style="margin-bottom:10px">
        <strong>{{ selected().size }} sélectionnée(s)</strong>
        <button class="adm-btn success sm" (click)="bulkApprove()">Approuver</button>
        <button class="adm-btn danger sm" (click)="openReject(null)">Rejeter…</button>
        <button class="adm-btn sm" (click)="clearSelection()">Annuler</button>
      </div>
    }

    @if (loading()) { <div class="adm-empty">Chargement…</div> }
    @for (v of items(); track v.id; let i = $index) {
      <div class="adm-card" style="margin-bottom:12px" [style.outline]="i === cursor() ? '2px solid var(--q-accent)' : 'none'" (click)="cursor.set(i)">
        <div class="adm-row" style="align-items:flex-start">
          <input type="checkbox" [checked]="selected().has(v.id)" (change)="toggle(v.id)" (click)="$event.stopPropagation()" />
          <div style="width:min(360px,100%)">
            @if (v.preview?.video) { <video class="adm-video" controls preload="metadata" [src]="v.preview.video" [poster]="v.preview.thumbnail || ''"></video> }
            @else { <div class="adm-empty">Pas de fichier vidéo</div> }
          </div>
          <div style="flex:1;min-width:220px">
            <div class="adm-row">
              <span class="adm-chip" [class.bad]="v.priority >= 5" [class.warn]="v.priority >= 2 && v.priority < 5">priorité {{ v.priority }}</span>
              @if (v.reports_count > 0) { <span class="adm-chip bad">{{ v.reports_count }} signalement(s)</span> }
              <span class="adm-chip" [class.ok]="v.moderation_status === 'approved'" [class.bad]="v.moderation_status === 'rejected'" [class.warn]="v.moderation_status === 'flagged'">{{ v.moderation_status }}</span>
              <span class="adm-sub">{{ v.created_at | date:'dd/MM HH:mm' }}</span>
            </div>
            <p style="margin:6px 0"><strong>{{ v.product?.title || 'Annonce retirée' }}</strong>
              @if (v.product?.price) { <span class="adm-sub"> · {{ v.product.price }} F</span> }</p>
            <p class="adm-muted" style="max-height:60px;overflow:hidden">{{ v.product?.description }}</p>
            <p class="adm-sub">Vendeur : <strong>{{ v.user?.full_name }}</strong> · confiance {{ v.user?.trust_score }} ·
              {{ v.seller_history.videos_total }} vidéo(s), {{ v.seller_history.videos_rejected }} rejetée(s)
              @if (isNew(v.user?.created_at)) { <span class="adm-chip warn">compte récent</span> }</p>
            @if (v.moderation_reason) { <p class="adm-sub">Motif : {{ v.moderation_reason }}</p> }
            <div class="adm-row">
              @if (v.moderation_status !== 'approved') { <button class="adm-btn success sm" (click)="approve(v)">{{ v.moderation_status === 'pending' ? 'Approuver' : 'Rétablir' }}</button> }
              @if (v.moderation_status !== 'rejected') { <button class="adm-btn danger sm" (click)="openReject(v)">Rejeter</button> }
              @if (v.moderation_status === 'pending') { <button class="adm-btn warn sm" (click)="openReject(v, 'flagged')">Vérifier</button> }
              @if (v.product) { <a class="adm-btn sm" routerLink="../products" [queryParams]="{ open: v.product.id }">Fiche produit</a> }
              <a class="adm-btn sm" routerLink="../users" [queryParams]="{ open: v.user_id }">Vendeur</a>
            </div>
          </div>
        </div>
      </div>
    } @empty { @if (!loading()) { <div class="adm-empty">🎉 File vide.</div> } }

    @if (last() > 1) {
      <div class="adm-pager"><button class="adm-btn sm" [disabled]="page() <= 1" (click)="load(page() - 1)">‹</button>
        Page {{ page() }} / {{ last() }}<button class="adm-btn sm" [disabled]="page() >= last()" (click)="load(page() + 1)">›</button></div>
    }
  </div>

  @if (dlg(); as d) {
    <adm-modal [title]="d.mode === 'flagged' ? 'Mettre en vérification' : (d.video ? 'Rejeter la vidéo' : 'Rejeter la sélection')" [danger]="true" confirmLabel="Valider"
      [presets]="presets()" [busy]="busy()" [error]="error()" (cancel)="dlg.set(null)" (confirm)="doReject($event)">
      @if (d.video) {
        <label class="adm-label">Conséquence sur l'annonce</label>
        <select class="adm-input" [(ngModel)]="action"><option value="video_only">Garder l'annonce en ligne sans la vidéo</option><option value="hide_product">Masquer aussi l'annonce (cas grave)</option></select>
      }
      @if (d.mode !== 'flagged') { <label class="adm-label"><input type="checkbox" [(ngModel)]="strike" /> Ajouter un avertissement au vendeur (3 = suspension auto)</label> }
    </adm-modal>
  }`,
})
export class AdminModerationPage implements OnInit {
  private admin = inject(AdminService);
  private notif = inject(NotificationService);

  tabs = [{ key: 'pending', label: 'En attente' }, { key: 'flagged', label: 'En vérification' }, { key: 'rejected', label: 'Rejetées' }, { key: 'approved', label: 'Approuvées' }];
  status = signal('pending');
  items = signal<any[]>([]);
  loading = signal(true);
  page = signal(1);
  last = signal(1);
  cursor = signal(0);
  selected = signal<Set<string>>(new Set());
  presets = signal<string[]>([]);
  search = '';

  dlg = signal<{ video: any | null; mode: 'rejected' | 'flagged' } | null>(null);
  busy = signal(false);
  error = signal('');
  action = 'video_only';
  strike = true;
  mediaUrl = mediaUrl;

  ngOnInit() {
    this.admin.getRejectionReasons().subscribe(r => this.presets.set(Object.values(r.reasons)));
    this.load(1);
  }

  setStatus(s: string) { this.status.set(s); this.selected.set(new Set()); this.load(1); }

  load(page: number) {
    this.loading.set(true);
    this.admin.getVideoQueue(this.status(), page, this.search).subscribe({
      next: r => { this.items.set(r.data); this.page.set(r.current_page); this.last.set(r.last_page); this.cursor.set(0); this.loading.set(false); },
      error: e => { this.loading.set(false); this.notif.error(errMsg(e)); },
    });
  }

  clearSelection() { this.selected.set(new Set<string>()); }
  isNew(d?: string) { return !!d && Date.now() - new Date(d).getTime() < 3 * 86400000; }
  toggle(id: string) { const s = new Set(this.selected()); s.has(id) ? s.delete(id) : s.add(id); this.selected.set(s); }

  approve(v: any) {
    this.admin.moderateVideo(v.id, { status: 'approved' }).subscribe({
      next: () => { this.notif.success('Vidéo approuvée'); this.load(this.page()); }, error: e => this.notif.error(errMsg(e)),
    });
  }
  bulkApprove() {
    this.admin.bulkModerate([...this.selected()], 'approved').subscribe({
      next: () => { this.notif.success('Vidéos approuvées'); this.selected.set(new Set()); this.load(this.page()); }, error: e => this.notif.error(errMsg(e)),
    });
  }

  openReject(video: any | null, mode: 'rejected' | 'flagged' = 'rejected') {
    this.error.set(''); this.action = 'video_only'; this.strike = true; this.dlg.set({ video, mode });
  }

  doReject(res: ModalResult) {
    const d = this.dlg(); if (!d) return;
    this.busy.set(true);
    const req = d.video
      ? this.admin.moderateVideo(d.video.id, { status: d.mode, reason: res.reason, action: this.action, strike: this.strike })
      : this.admin.bulkModerate([...this.selected()], 'rejected', res.reason);
    req.subscribe({
      next: () => { this.busy.set(false); this.dlg.set(null); this.selected.set(new Set()); this.notif.success('Décision appliquée'); this.load(this.page()); },
      error: (e: any) => { this.busy.set(false); this.error.set(errMsg(e)); },
    });
  }

  @HostListener('window:keydown', ['$event'])
  onKey(e: KeyboardEvent) {
    const t = e.target as HTMLElement;
    if (this.dlg() || ['INPUT', 'TEXTAREA', 'SELECT'].includes(t.tagName) || e.ctrlKey || e.metaKey) return;
    const list = this.items(); const v = list[this.cursor()];
    switch (e.key.toLowerCase()) {
      case 'j': this.cursor.set(Math.min(list.length - 1, this.cursor() + 1)); break;
      case 'k': this.cursor.set(Math.max(0, this.cursor() - 1)); break;
      case 'a': if (v && v.moderation_status !== 'approved') this.approve(v); break;
      case 'r': if (v && v.moderation_status !== 'rejected') this.openReject(v); break;
      case 'f': if (v && v.moderation_status === 'pending') this.openReject(v, 'flagged'); break;
    }
  }
}
