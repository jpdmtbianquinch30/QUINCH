import { Component, inject, OnInit, signal, computed } from '@angular/core';
import { Router, RouterLink } from '@angular/router';
import { DecimalPipe } from '@angular/common';
import { ProductService } from '../../core/services/product.service';
import { FavoriteService } from '../../core/services/favorite.service';
import { NotificationService } from '../../core/services/notification.service';
import { AuthService } from '../../core/services/auth.service';
import { Product, Category } from '../../core/models/product.model';

@Component({
  selector: 'app-feed',
  standalone: true,
  imports: [RouterLink, DecimalPipe],
  templateUrl: './feed.component.html',
  styleUrl: './feed.component.scss',
})
export class FeedComponent implements OnInit {
  private productService = inject(ProductService);
  private favService = inject(FavoriteService);
  private notify = inject(NotificationService);
  private router = inject(Router);
  auth = inject(AuthService);

  products = signal<Product[]>([]);
  categories = signal<Category[]>([]);
  loading = signal(true);
  loadingMore = signal(false);
  currentPage = signal(1);
  lastPage = signal(1);
  selectedCategory = signal<string | null>(null);
  selectedType = signal<'all' | 'product' | 'service'>('all');

  videoProducts = computed(() => this.products().filter(p => !!p.video));

  // Vrai total du catalogue (pas juste ce qui est chargé à l'écran) —
  // récupéré via deux requêtes légères dédiées (per_page: 1, on ne lit que
  // le champ "total" de la pagination), indépendantes du scroll infini.
  // Avant : comptait products()/services() dans la page déjà chargée,
  // donc le chiffre changeait et grossissait au fil du scroll au lieu de
  // représenter le vrai total.
  productsCount = signal(0);
  servicesCount = signal(0);

  ngOnInit() {
    this.loadData();
  }

  private loadCounts() {
    const categoryParams: Record<string, any> = {};
    if (this.selectedCategory()) categoryParams['category_id'] = this.selectedCategory();

    this.productService.getFeed(1, { ...categoryParams, type: 'product', per_page: 1 }).subscribe({
      next: (res: any) => this.productsCount.set(res.total ?? 0),
    });
    this.productService.getFeed(1, { ...categoryParams, type: 'service', per_page: 1 }).subscribe({
      next: (res: any) => this.servicesCount.set(res.total ?? 0),
    });
  }

  loadData() {
    this.loading.set(true);
    const params = this.buildParams();
    this.productService.getFeed(1, params).subscribe({
      next: (res: any) => {
        this.products.set(res.data || []);
        this.lastPage.set(res.last_page || 1);
        this.currentPage.set(1);
        this.loading.set(false);
      },
      error: () => this.loading.set(false),
    });
    this.productService.getCategories().subscribe({
      next: (res: any) => this.categories.set(res.categories || []),
    });
    this.loadCounts();
  }

  loadMore() {
    if (this.loadingMore() || this.currentPage() >= this.lastPage()) return;
    this.loadingMore.set(true);
    const params = this.buildParams();
    this.productService.getFeed(this.currentPage() + 1, params).subscribe({
      next: (res: any) => {
        this.products.update(list => [...list, ...(res.data || [])]);
        this.currentPage.update(p => p + 1);
        this.loadingMore.set(false);
      },
      error: () => this.loadingMore.set(false),
    });
  }

  onScroll(event: Event) {
    const el = event.target as HTMLElement;
    if (el.scrollTop + el.clientHeight > el.scrollHeight - 400) {
      this.loadMore();
    }
  }

  private buildParams(): Record<string, any> {
    const params: Record<string, any> = {};
    if (this.selectedCategory()) params['category_id'] = this.selectedCategory();
    if (this.selectedType() !== 'all') params['type'] = this.selectedType();
    return params;
  }

  setType(type: 'all' | 'product' | 'service') {
    if (this.selectedType() === type) return;
    this.selectedType.set(type);
    this.loadData();
  }

  filterByCategory(catId: string) {
    this.selectedCategory.set(this.selectedCategory() === catId ? null : catId);
    this.loadData();
  }

  resetFilters() {
    this.selectedCategory.set(null);
    this.selectedType.set('all');
    this.loadData();
  }

  openSearch() {
    this.router.navigate(['/search']);
  }

  openVideoFeed(startProduct?: Product) {
    const videos = this.videoProducts();
    const idx = startProduct ? videos.indexOf(startProduct) : 0;
    this.router.navigate(['/videos'], { state: { videos, initialIndex: idx >= 0 ? idx : 0 } });
  }

  openProduct(product: Product) {
    if (product.video) {
      this.openVideoFeed(product);
      return;
    }
    this.router.navigate(['/product', product.slug]);
  }

  toggleSave(product: Product, event: Event) {
    event.stopPropagation();
    if (!this.auth.isAuthenticated()) { this.router.navigate(['/auth/login']); return; }
    const previous = product.is_saved;
    product.is_saved = !previous;
    this.products.update(list => [...list]);
    this.favService.toggleFavorite(product.id).subscribe({
      error: () => {
        product.is_saved = previous;
        this.products.update(list => [...list]);
        this.notify.error('Erreur lors de la sauvegarde.');
      },
    });
  }

  getThumb(product: Product): string {
    return product.poster_full_url || product.poster || product.images?.[0] || '';
  }

  videoBannerSubtitle(): string {
    const videos = this.videoProducts();
    const products = videos.filter(p => p.type !== 'service').length;
    const services = videos.filter(p => p.type === 'service').length;
    if (products > 0 && services > 0) return `${products} produits · ${services} services en vidéo`;
    if (services > 0) return `${services} services en vidéo`;
    return `${products} produits en vidéo`;
  }

  categoryIcon(name: string): string {
    const icons: Record<string, string> = {
      'Téléphones & Tech': 'smartphone',
      'Mode & Accessoires': 'checkroom',
      'Alimentation': 'restaurant',
      'Électroménager': 'electrical_services',
      'Immobilier': 'home',
      'Automobile': 'directions_car',
      'Services': 'build',
      'Emploi': 'work',
      'Beauté': 'face',
      'Sport & Loisirs': 'sports',
    };
    return icons[name] || 'category';
  }
}
