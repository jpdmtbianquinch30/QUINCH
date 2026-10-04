import { Component, OnInit, computed, inject, signal } from '@angular/core';
import { FormsModule } from '@angular/forms';
import { AdminService } from '../../../core/services/admin.service';
import { NotificationService } from '../../../core/services/notification.service';
import { AdminModalComponent } from '../shared/admin-modal.component';
import { errMsg } from '../shared/admin-utils';

/** Interface complète des catégories (l'API existait sans écran) : créer, modifier, activer, réordonner, supprimer. */
@Component({
  selector: 'adm-categories',
  standalone: true,
  imports: [FormsModule, AdminModalComponent],
  styleUrl: '../shared/admin-common.scss',
  template: `
  <div class="adm-page">
    <div class="adm-row" style="margin-bottom:12px"><button class="adm-btn primary" (click)="startNew(null)">+ Catégorie principale</button><span class="adm-sub">Deux niveaux maximum. Une catégorie contenant des produits se désactive, elle ne se supprime pas.</span></div>
    @for (c of roots(); track c.id; let i = $index) {
      <div class="adm-card" style="margin-bottom:10px">
        <div class="adm-row">
          <span class="material-icons">{{ c.icon || 'category' }}</span>
          <strong>{{ c.name }}</strong><span class="adm-sub">{{ c.slug }} · {{ c.products_count }} produit(s)</span>
          @if (!c.is_active) { <span class="adm-chip bad">inactive</span> }
          <span style="flex:1"></span>
          <button class="adm-btn sm" [disabled]="i === 0" (click)="move(roots(), i, -1)">↑</button><button class="adm-btn sm" [disabled]="i === roots().length - 1" (click)="move(roots(), i, 1)">↓</button>
          <button class="adm-btn sm" (click)="startNew(c)">+ Sous-cat.</button><button class="adm-btn sm" (click)="edit(c)">Modifier</button>
          <button class="adm-btn sm" (click)="toggle(c)">{{ c.is_active ? 'Désactiver' : 'Activer' }}</button>
          <button class="adm-btn sm danger" (click)="askDelete(c)">Supprimer</button>
        </div>
        @for (s of childrenOf(c.id); track s.id; let j = $index) {
          <div class="adm-row" style="margin:8px 0 0 28px">
            <span class="material-icons" style="font-size:16px">subdirectory_arrow_right</span>{{ s.name }}<span class="adm-sub">{{ s.products_count }} produit(s)</span>
            @if (!s.is_active) { <span class="adm-chip bad">inactive</span> }<span style="flex:1"></span>
            <button class="adm-btn sm" [disabled]="j === 0" (click)="move(childrenOf(c.id), j, -1)">↑</button><button class="adm-btn sm" [disabled]="j === childrenOf(c.id).length - 1" (click)="move(childrenOf(c.id), j, 1)">↓</button>
            <button class="adm-btn sm" (click)="edit(s)">Modifier</button><button class="adm-btn sm" (click)="toggle(s)">{{ s.is_active ? 'Désactiver' : 'Activer' }}</button><button class="adm-btn sm danger" (click)="askDelete(s)">Supprimer</button>
          </div>
        }
      </div>
    } @empty { <div class="adm-empty">Aucune catégorie.</div> }
  </div>

  @if (form(); as f) {
    <div class="adm-overlay" (click)="form.set(null)"><div class="adm-modal" (click)="$event.stopPropagation()">
      <h3>{{ f.id ? 'Modifier la catégorie' : (f.parent_id ? 'Nouvelle sous-catégorie' : 'Nouvelle catégorie') }}</h3>
      <label class="adm-label">Nom</label><input class="adm-input" [(ngModel)]="f.name" />
      <label class="adm-label">Icône (nom Material Icons)</label><input class="adm-input" [(ngModel)]="f.icon" placeholder="ex. phone_iphone" />
      <label class="adm-label">Description</label><textarea class="adm-input" rows="2" [(ngModel)]="f.description"></textarea>
      <label class="adm-label"><input type="checkbox" [(ngModel)]="f.is_active" /> Active (visible dans l'application)</label>
      @if (error()) { <div class="adm-error">{{ error() }}</div> }
      <div class="adm-actions"><button class="adm-btn" (click)="form.set(null)">Annuler</button><button class="adm-btn primary" [disabled]="!f.name?.trim()" (click)="save()">Enregistrer</button></div>
    </div></div>
  }
  @if (del(); as c) { <adm-modal [title]="'Supprimer « ' + c.name + ' »'" [danger]="true" [needReason]="false" [busy]="busy()" [error]="error()" (cancel)="del.set(null)" (confirm)="doDelete()"></adm-modal> }`,
})
export class AdminCategoriesPage implements OnInit {
  private admin = inject(AdminService);
  private notif = inject(NotificationService);

  all = signal<any[]>([]);
  roots = computed(() => this.all().filter(c => !c.parent_id));
  form = signal<any>(null); del = signal<any>(null);
  busy = signal(false); error = signal('');

  ngOnInit() { this.load(); }
  childrenOf(id: string) { return this.all().filter(c => c.parent_id === id); }
  load() { this.admin.getCategories().subscribe(r => this.all.set(r.categories)); }

  startNew(parent: any | null) { this.error.set(''); this.form.set({ name: '', icon: '', description: '', is_active: true, parent_id: parent?.id ?? null }); }
  edit(c: any) { this.error.set(''); this.form.set({ ...c }); }

  save() {
    const f = this.form();
    const body = { name: f.name.trim(), icon: f.icon || null, description: f.description || null, is_active: !!f.is_active, parent_id: f.parent_id ?? null };
    (f.id ? this.admin.updateCategory(f.id, body) : this.admin.createCategory(body)).subscribe({
      next: () => { this.form.set(null); this.notif.success('Catégorie enregistrée'); this.load(); },
      error: e => this.error.set(errMsg(e)),
    });
  }

  toggle(c: any) { this.admin.updateCategory(c.id, { is_active: !c.is_active }).subscribe({ next: () => this.load(), error: e => this.notif.error(errMsg(e)) }); }

  move(list: any[], i: number, dir: number) {
    const ids = list.map(c => c.id); const j = i + dir;
    [ids[i], ids[j]] = [ids[j], ids[i]];
    this.admin.reorderCategories(ids).subscribe({ next: () => this.load(), error: e => this.notif.error(errMsg(e)) });
  }

  askDelete(c: any) { this.error.set(''); this.del.set(c); }
  doDelete() {
    this.busy.set(true);
    this.admin.deleteCategory(this.del().id).subscribe({
      next: () => { this.busy.set(false); this.del.set(null); this.notif.success('Catégorie supprimée'); this.load(); },
      error: e => { this.busy.set(false); this.error.set(errMsg(e)); },
    });
  }
}
