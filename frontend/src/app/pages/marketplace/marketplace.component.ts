import { Component, inject, OnInit, OnDestroy, signal } from '@angular/core';
import { RouterLink, ActivatedRoute } from '@angular/router';
import { FormsModule } from '@angular/forms';
import { DecimalPipe } from '@angular/common';
import { Subject, Subscription, debounceTime, distinctUntilChanged, switchMap, of } from 'rxjs';
import { ProductService } from '../../core/services/product.service';
import { CartService } from '../../core/services/cart.service';
import { FavoriteService } from '../../core/services/favorite.service';
import { NotificationService } from '../../core/services/notification.service';
import { AnalyticsService } from '../../core/services/analytics.service';
import { AuthService } from '../../core/services/auth.service';
import { Product, Category } from '../../core/models/product.model';

@Component({
  selector: 'app-marketplace',
  standalone: true,
  imports: [RouterLink, FormsModule, DecimalPipe],
  templateUrl: './marketplace.component.html',
  styleUrl: './marketplace.component.scss',
})
export class MarketplaceComponent implements OnInit, OnDestroy {
  private productService = inject(ProductService);
  private cartService = inject(CartService);
  private favService = inject(FavoriteService);
  private notify = inject(NotificationService);
  private analytics = inject(AnalyticsService);
  private route = inject(ActivatedRoute);
  auth = inject(AuthService);

  products = signal<Product[]>([]);
  categories = signal<Category[]>([]);
  loading = signal(false);
  searchQuery = '';
  selectedCategory = signal('');
  selectedType = signal<'' | 'product' | 'service'>('');
  sortBy = signal('newest');
  priceMin = signal<number | null>(null);
  priceMax = signal<number | null>(null);
  condition = signal('');
  showFilters = signal(false);
  resultsCount = signal(0);

  private routeSub: Subscription | null = null;

  // Instant search
  private searchSubject = new Subject<string>();
  private searchSub: Subscription | null = null;
  suggestions = signal<Product[]>([]);
  showSuggestions = signal(false);
  recentSearches = signal<string[]>([]);
  searchFocused = signal(false);

  ngOnInit() {
    this.loadCategories();
    this.loadRecentSearches();
    this.setupInstantSearch();

    // Listen to query param changes (e.g. ?type=product or ?type=service)
    this.routeSub = this.route.queryParams.subscribe(params => {
      const type = params['type'];
      if (type === 'product' || type === 'service') {
        this.selectedType.set(type);
      } else {
        this.selectedType.set('');
      }
      this.loadProducts();
    });
  }

  ngOnDestroy() {
    this.searchSub?.unsubscribe();
    this.routeSub?.unsubscribe();
  }

  private setupInstantSearch() {
    this.searchSub = this.searchSubject.pipe(
      debounceTime(250),
      distinctUntilChanged(),
      switchMap(query => {
        if (!query || query.length < 2) {
          this.suggestions.set([]);
          this.showSuggestions.set(false);
          return of(null);
        }
        return this.productService.getProducts({ search: query, per_page: 6 });
      })
    ).subscribe({
      next: (res: any) => {
        if (res) {
          const items = res.data || res.products || [];
          this.suggestions.set(items.slice(0, 6));
          this.showSuggestions.set(items.length > 0);
        }
      }
    });
  }

  private loadRecentSearches() {
    try {
      const saved = localStorage.getItem('quinch_recent_searches');
      if (saved) this.recentSearches.set(JSON.parse(saved));
    } catch { /* ignore */ }
  }

  private saveRecentSearch(query: string) {
    if (!query.trim()) return;
    const recent = [query, ...this.recentSearches().filter(s => s !== query)].slice(0, 8);
    this.recentSearches.set(recent);
    localStorage.setItem('quinch_recent_searches', JSON.stringify(recent));
  }

  clearRecentSearches() {
    this.recentSearches.set([]);
    localStorage.removeItem('quinch_recent_searches');
  }

  onSearchInput(event: Event) {
    const value = (event.target as HTMLInputElement).value;
    this.searchQuery = value;
    this.searchSubject.next(value);

    // Also trigger full search for real-time results
    if (value.length >= 2) {
      this.loadProducts();
    } else if (value.length === 0) {
      this.loadProducts();
      this.showSuggestions.set(false);
    }
  }

  onSearchFocus() {
    this.searchFocused.set(true);
    if (!this.searchQuery && this.recentSearches().length > 0) {
      this.showSuggestions.set(false); // Show recent searches panel instead
    }
  }

  onSearchBlur() {
    // Delay to allow click on suggestions
    setTimeout(() => {
      this.searchFocused.set(false);
      this.showSuggestions.set(false);
    }, 200);
  }

  selectSuggestion(product: Product) {
    this.searchQuery = product.title;
    this.showSuggestions.set(false);
    this.saveRecentSearch(product.title);
    this.loadProducts();
  }

  selectRecentSearch(query: string) {
    this.searchQuery = query;
    this.showSuggestions.set(false);
    this.loadProducts();
  }

  loadCategories() {
    this.productService.getCategories().subscribe({
      next: (res: any) => this.categories.set(res.categories || res.data || []),
    });
  }

  selectType(type: '' | 'product' | 'service') {
    this.selectedType.set(type);
    this.loadProducts();
  }

  loadProducts() {
    this.loading.set(true);
    const params: Record<string, any> = {
      q: this.searchQuery || undefined,
      category: this.selectedCategory() || undefined,
      condition: this.condition() || undefined,
      min_price: this.priceMin() || undefined,
      max_price: this.priceMax() || undefined,
      type: this.selectedType() || undefined,
    };

    this.productService.getProducts(params).subscribe({
      next: (res: any) => {
        this.products.set(res.data || res.products || []);
        this.resultsCount.set(res.total || this.products().length);
        this.loading.set(false);
        if (this.searchQuery) {
          this.analytics.trackSearch(this.searchQuery, this.products().length);
        }
      },
      error: () => this.loading.set(false),
    });
  }

  selectCategory(id: string) {
    this.selectedCategory.set(this.selectedCategory() === id ? '' : id);
    this.loadProducts();
  }

  onSearch() {
    this.showSuggestions.set(false);
    if (this.searchQuery) this.saveRecentSearch(this.searchQuery);
    this.loadProducts();
  }

  onSortChange(sort: string) {
    this.sortBy.set(sort);
    this.loadProducts();
  }

  applyFilters() {
    this.showFilters.set(false);
    this.loadProducts();
  }

  clearFilters() {
    this.priceMin.set(null);
    this.priceMax.set(null);
    this.condition.set('');
    this.selectedCategory.set('');
    this.selectedType.set('');
    this.searchQuery = '';
    this.sortBy.set('newest');
    this.loadProducts();
  }

  // ─── Media Helpers ──────────────────────────────────────
  getThumb(product: any): string | null {
    // 1. Poster image (main product image) — highest priority
    if (product.poster) return product.poster;
    if (product.poster_full_url) return product.poster_full_url;
    // 2. Video thumbnail
    const v = product.video;
    if (v) {
      if (v.thumbnail) return v.thumbnail;
      if (v.thumbnail_url) return v.thumbnail_url;
    }
    // 3. Images array
    if (product.images?.length) return product.images[0];
    // 4. Image field
    if (product.image) return product.image;
    return null;
  }

  hasVideo(product: any): boolean {
    return !!(product.video?.url || product.video?.video_url || product.video?.id);
  }

  onImgError(event: Event) {
    const img = event.target as HTMLImageElement;
    // Try falling back to the first image if this was a video thumbnail
    const card = img.closest('.card-media-inner');
    if (card) {
      img.style.display = 'none';
      // Show the fallback icon that's already in the DOM
      const fallbackIcon = card.querySelector('.material-icons');
      if (fallbackIcon) {
        (fallbackIcon as HTMLElement).style.display = 'inline-block';
      }
    } else {
      img.style.display = 'none';
    }
  }

  quickAddToCart(product: Product, event: Event) {
    event.preventDefault();
    event.stopPropagation();
    if (!this.auth.isAuthenticated()) return;
    this.cartService.addToCart(product.id).subscribe({
      next: () => {
        this.notify.success('Ajoute au panier!');
        this.analytics.trackAddToCart(product.id, product.price);
      },
    });
  }

  quickFavorite(product: Product, event: Event) {
    event.preventDefault();
    event.stopPropagation();
    if (!this.auth.isAuthenticated()) return;
    this.favService.toggleFavorite(product.id).subscribe({
      next: (res: any) => {
        this.notify.success(res.favorited ? 'Ajoute aux favoris!' : 'Retire des favoris.');
      },
    });
  }
}
