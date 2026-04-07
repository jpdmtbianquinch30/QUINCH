import { Component, inject, OnInit, signal } from '@angular/core';
import { Router, RouterLink } from '@angular/router';
import { DecimalPipe } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { AuthService } from '../../core/services/auth.service';
import { ProductService } from '../../core/services/product.service';
import { NotificationService } from '../../core/services/notification.service';
import { BadgeService, Badge } from '../../core/services/badge.service';
import { FollowService } from '../../core/services/follow.service';
import { UserService } from '../../core/services/user.service';

@Component({
  selector: 'app-profile',
  standalone: true,
  imports: [RouterLink, DecimalPipe, FormsModule],
  templateUrl: './profile.component.html',
  styleUrl: './profile.component.scss',
})
export class ProfileComponent implements OnInit {
  auth = inject(AuthService);
  private router = inject(Router);
  private productService = inject(ProductService);
  private notify = inject(NotificationService);
  private badgeService = inject(BadgeService);
  private followService = inject(FollowService);
  private userService = inject(UserService);

  user = this.auth.user;
  productsCount = signal(0);
  totalReceivedLikes = signal(0);
  myProducts = signal<any[]>([]);
  badges = signal<Badge[]>([]);
  followerCount = signal(0);
  followingCount = signal(0);

  likedProducts = signal<any[]>([]);
  likesCount = signal(0);
  profileTab = signal<'products' | 'likes'>('products');
  viewMode = signal<'grid' | 'list'>('grid');
  trustPercent = signal(0);

  // Upload
  uploadingAvatar = signal(false);
  uploadingCover = signal(false);

  // Image error tracking
  avatarError = signal(false);
  coverError = signal(false);

  // ─── Product Management Modal ──────────────────────────────────
  Math = Math;
  showManageModal = signal(false);
  managingProduct = signal<any>(null);
  manageStockQty = signal(1);
  manageUpdating = signal(false);
  showDeactivateConfirm = signal(false);
  deactivateType = signal<'paused' | 'disabled'>('paused');

  ngOnInit() {
    this.trustPercent.set(Math.round((this.user()?.trust_score || 0) * 100));
    this.loadProducts();
    this.loadLikes();
    this.loadBadges();
    this.loadFollowCounts();
  }

  loadProducts() {
    this.productService.getMyProducts().subscribe({
      next: (res: any) => {
        const products = res.data || res.products || [];
        this.myProducts.set(products);
        this.productsCount.set(products.length);
        this.totalReceivedLikes.set(products.reduce((sum: number, p: any) => sum + (p.like_count || 0), 0));
      },
    });
  }

  loadLikes() {
    this.productService.getMyLikes().subscribe({
      next: (res: any) => {
        const products = res.data || [];
        this.likedProducts.set(products);
        this.likesCount.set(products.length);
      },
    });
  }

  loadBadges() {
    this.badgeService.getMyBadges().subscribe({
      next: () => this.badges.set(this.badgeService.myBadges()),
    });
  }

  loadFollowCounts() {
    this.followService.getMyFollowers().subscribe({
      next: () => this.followerCount.set(this.followService.followerCount()),
    });
    this.followService.getMyFollowing().subscribe({
      next: () => this.followingCount.set(this.followService.followingCount()),
    });
  }

  getTrustColor(): string {
    const p = this.trustPercent();
    if (p >= 80) return 'var(--q-success)';
    if (p >= 50) return 'var(--q-warning)';
    return 'var(--q-danger)';
  }

  getProductStatusLabel(status: string): string {
    switch (status) {
      case 'active': return 'En vente';
      case 'sold': return 'Vendu';
      case 'draft': return 'Brouillon';
      case 'paused': return 'En pause';
      case 'disabled': return 'Desactive';
      case 'out_of_stock': return 'Epuise';
      default: return status;
    }
  }

  getProductStatusClass(status: string): string {
    switch (status) {
      case 'active': return 'status-active';
      case 'sold': return 'status-sold';
      case 'draft': return 'status-draft';
      case 'paused': return 'status-paused';
      case 'disabled': return 'status-disabled';
      default: return '';
    }
  }

  /** Get the best available thumbnail for a product (poster first) */
  getProductThumb(p: any): string | null {
    // 1) Poster image (image d'affiche) — highest priority
    if (p.poster_full_url) return p.poster_full_url;
    if (p.poster) return p.poster;
    if (p.poster_url) return p.poster_url;
    // 2) Video thumbnail
    if (p.video) {
      const thumb = p.video.thumbnail_url || p.video.thumbnail;
      if (thumb) return thumb;
    }
    // 3) First image
    if (p.images?.length) {
      return p.images[0];
    }
    return null;
  }

  hasVideo(p: any): boolean {
    return !!(p.video && (p.video.thumbnail_url || p.video.thumbnail || p.video.video_url || p.video.url));
  }

  /** Get the video streaming URL for a product */
  getProductVideoUrl(p: any): string | null {
    if (!p.video) return null;
    if (p.video.video_url) return p.video.video_url;
    if (p.video.url) return p.video.url;
    if (p.video.id) return '/api/v1/videos/' + p.video.id + '/stream';
    return null;
  }

  // ─── Avatar / Cover Upload ──────────────────────────────────
  onAvatarSelected(event: Event): void {
    const input = event.target as HTMLInputElement;
    const file = input.files?.[0];
    if (!file) return;
    if (file.size > 5 * 1024 * 1024) { this.notify.error('Image trop lourde (max 5 Mo).'); return; }
    this.uploadingAvatar.set(true);
    this.avatarError.set(false);
    this.userService.uploadAvatar(file).subscribe({
      next: (res: any) => {
        this.uploadingAvatar.set(false);
        this.avatarError.set(false);
        if (res.user) this.auth.updateUser(res.user);
        this.notify.success('Photo de profil mise a jour!');
      },
      error: () => { this.uploadingAvatar.set(false); this.notify.error("Erreur lors de l'upload."); },
    });
    input.value = '';
  }

  onCoverSelected(event: Event): void {
    const input = event.target as HTMLInputElement;
    const file = input.files?.[0];
    if (!file) return;
    if (file.size > 10 * 1024 * 1024) { this.notify.error('Image trop lourde (max 10 Mo).'); return; }
    this.uploadingCover.set(true);
    this.coverError.set(false);
    this.userService.uploadCover(file).subscribe({
      next: (res: any) => {
        this.uploadingCover.set(false);
        this.coverError.set(false);
        if (res.user) this.auth.updateUser(res.user);
        this.notify.success('Photo de couverture mise a jour!');
      },
      error: () => { this.uploadingCover.set(false); this.notify.error("Erreur lors de l'upload."); },
    });
    input.value = '';
  }

  onAvatarImgError(): void {
    this.avatarError.set(true);
  }

  onCoverImgError(): void {
    this.coverError.set(true);
  }

  onImgError(event: Event): void {
    const img = event.target as HTMLImageElement;
    img.style.display = 'none';
  }

  // ─── Product Management ──────────────────────────────────
  openManageModal(product: any, event: Event): void {
    event.preventDefault();
    event.stopPropagation();
    this.managingProduct.set(product);
    this.manageStockQty.set(product.stock_quantity ?? 1);
    this.showManageModal.set(true);
    this.showDeactivateConfirm.set(false);
    document.body.style.overflow = 'hidden';
  }

  closeManageModal(): void {
    this.showManageModal.set(false);
    this.managingProduct.set(null);
    this.showDeactivateConfirm.set(false);
    document.body.style.overflow = '';
  }

  updateStock(): void {
    const p = this.managingProduct();
    if (!p) return;
    const qty = this.manageStockQty();

    if (qty === 0) {
      // Stock is 0 → ask for deactivation type
      this.showDeactivateConfirm.set(true);
      return;
    }

    this.manageUpdating.set(true);
    const updateData: any = { stock_quantity: qty };
    // If product was paused and now has stock, reactivate it
    if (p.status === 'paused' && qty > 0) {
      updateData.status = 'active';
    }
    this.productService.updateProduct(p.id, updateData).subscribe({
      next: (res: any) => {
        this.manageUpdating.set(false);
        const updated = res.product || res;
        this.updateProductInList(p.id, updated);
        this.notify.success('Stock mis a jour!');
        this.closeManageModal();
      },
      error: () => {
        this.manageUpdating.set(false);
        this.notify.error('Erreur lors de la mise a jour du stock.');
      },
    });
  }

  markOutOfStock(): void {
    this.manageStockQty.set(0);
    this.showDeactivateConfirm.set(true);
  }

  confirmDeactivation(type: 'paused' | 'disabled'): void {
    const p = this.managingProduct();
    if (!p) return;
    this.manageUpdating.set(true);
    this.productService.updateProduct(p.id, { stock_quantity: 0, status: type }).subscribe({
      next: (res: any) => {
        this.manageUpdating.set(false);
        const updated = res.product || res;
        this.updateProductInList(p.id, updated);
        this.notify.success(type === 'paused'
          ? 'Produit desactive temporairement. Vous pouvez le reactiver a tout moment.'
          : 'Produit desactive definitivement.');
        this.closeManageModal();
      },
      error: () => {
        this.manageUpdating.set(false);
        this.notify.error('Erreur lors de la desactivation.');
      },
    });
  }

  reactivateProduct(): void {
    const p = this.managingProduct();
    if (!p) return;
    const qty = this.manageStockQty() > 0 ? this.manageStockQty() : 1;
    this.manageUpdating.set(true);
    this.productService.updateProduct(p.id, { status: 'active', stock_quantity: qty }).subscribe({
      next: (res: any) => {
        this.manageUpdating.set(false);
        const updated = res.product || res;
        this.updateProductInList(p.id, updated);
        this.notify.success('Produit reactive avec succes!');
        this.closeManageModal();
      },
      error: () => {
        this.manageUpdating.set(false);
        this.notify.error('Erreur lors de la reactivation.');
      },
    });
  }

  deleteProduct(): void {
    const p = this.managingProduct();
    if (!p) return;
    if (!confirm('Etes-vous sur de vouloir supprimer definitivement ce produit ? Cette action est irreversible.')) return;
    this.manageUpdating.set(true);
    this.productService.deleteProduct(p.id).subscribe({
      next: () => {
        this.manageUpdating.set(false);
        this.myProducts.update(list => list.filter(item => item.id !== p.id));
        this.productsCount.update(c => c - 1);
        this.notify.success('Produit supprime.');
        this.closeManageModal();
      },
      error: () => {
        this.manageUpdating.set(false);
        this.notify.error('Erreur lors de la suppression.');
      },
    });
  }

  private updateProductInList(id: string, updated: any): void {
    this.myProducts.update(list =>
      list.map(p => p.id === id ? { ...p, ...updated } : p)
    );
  }

  isProductInactive(p: any): boolean {
    return p.status === 'paused' || p.status === 'disabled';
  }

  getStockLabel(p: any): string {
    const qty = p.stock_quantity ?? 0;
    if (qty === 0) return 'Epuise';
    if (qty <= 3) return `${qty} restant(s)`;
    return `${qty} en stock`;
  }

  getStockClass(p: any): string {
    const qty = p.stock_quantity ?? 0;
    if (qty === 0) return 'stock-out';
    if (qty <= 3) return 'stock-low';
    return 'stock-ok';
  }

  // Navigation
  editProfile() { this.router.navigate(['/profile/edit']); }
  openSettings() { this.router.navigate(['/settings']); }
  openMyPurchases() { this.router.navigate(['/transactions'], { queryParams: { tab: 'purchases' } }); }
  addProduct() { this.router.navigate(['/sell']); }

  async shareProfile() {
    const url = `${window.location.origin}/seller/${this.user()?.username}`;
    if (navigator.share) {
      try { await navigator.share({ title: 'Mon profil QUINCH', url }); } catch {}
    } else {
      try { await navigator.clipboard.writeText(url); this.notify.success('Lien copie!'); } catch {}
    }
  }

  logout() {
    this.auth.logout();
    this.notify.success('Deconnexion reussie.');
  }
}
