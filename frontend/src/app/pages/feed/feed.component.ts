import {
  Component, inject, OnInit, signal, effect, OnDestroy,
  HostListener, ViewChildren, ViewChild, QueryList, ElementRef, AfterViewInit
} from '@angular/core';
import { Router } from '@angular/router';
import { DecimalPipe } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { ProductService } from '../../core/services/product.service';
import { ApiService } from '../../core/services/api.service';
import { CartService } from '../../core/services/cart.service';
import { ShareService } from '../../core/services/share.service';
import { FollowService } from '../../core/services/follow.service';
import { ChatService } from '../../core/services/chat.service';
import { NegotiationService } from '../../core/services/negotiation.service';
import { NotificationService } from '../../core/services/notification.service';
import { AnalyticsService } from '../../core/services/analytics.service';
import { AuthService } from '../../core/services/auth.service';
import { ReviewService, ReviewStats } from '../../core/services/review.service';
import { Subject, debounceTime, distinctUntilChanged } from 'rxjs';

@Component({
  selector: 'app-feed',
  standalone: true,
  imports: [DecimalPipe, FormsModule],
  templateUrl: './feed.component.html',
  styleUrl: './feed.component.scss',
})
export class FeedComponent implements OnInit, OnDestroy, AfterViewInit {
  @ViewChildren('videoPlayer') videoPlayers!: QueryList<ElementRef<HTMLVideoElement>>;
  @ViewChild('searchInput') searchInputRef!: ElementRef<HTMLInputElement>;
  private productService = inject(ProductService);
  private apiService = inject(ApiService);
  private cartService = inject(CartService);
  private shareService = inject(ShareService);
  private followService = inject(FollowService);
  private chatService = inject(ChatService);
  private negotiationService = inject(NegotiationService);
  private notify = inject(NotificationService);
  private analytics = inject(AnalyticsService);
  auth = inject(AuthService);
  private reviewService = inject(ReviewService);
  private router = inject(Router);

  products = signal<any[]>([]);
  loading = signal(false);
  currentIndex = signal(0);
  activeTab = signal<'following' | 'foryou' | 'friends'>('foryou');

  // Search
  showSearch = signal(false);
  searchQuery = signal('');
  searchResults = signal<{ products: any[]; users: any[] }>({ products: [], users: [] });
  searching = signal(false);
  private searchSubject = new Subject<string>();

  // Recent searches & suggestions
  recentSearches = signal<string[]>([]);
  suggestions = signal<any[]>([]);
  loadingSuggestions = signal(false);
  private readonly RECENT_KEY = 'quinch_recent_searches';
  private readonly MAX_RECENT = 8;

  // Video playback state
  playingIndex = signal<number>(0);
  private muted = signal(true);
  videoLoading = signal(false);
  videoPaused = signal(false);

  // Following state per seller
  followingMap = signal<Record<string, boolean>>({});

  // Double-click like animation
  showLikeAnim = signal(false);
  private clickTimer: any = null;

  // Cart added state per product
  cartAddedMap = signal<Record<string, boolean>>({});

  // ─── Detail Panel ─────────────────────────────────────────
  detailMode = signal(false);
  dp = signal<any>(null);        // full product data
  dpReviews = signal<any[]>([]);
  dpStats = signal<ReviewStats | null>(null);
  dpLoadingReviews = signal(false);
  dpImgIdx = signal(0);
  dpNewRating = signal(0);
  dpNewHover = signal(0);
  dpNewComment = '';
  dpSubmitting = signal(false);
  dpSubmitted = signal(false);
  dpAddingCart = signal(false);
  dpShowPayment = signal(false);
  dpShowContact = signal(false);
  dpShowNego = signal(false);
  dpShowQuote = signal(false);
  dpSending = signal(false);
  dpSelectedPay = signal('');
  dpProposedPrice = 0;
  dpNegoMsg = '';
  dpContactMsg = '';
  dpQuoteMsg = '';

  // Resize
  resizing = signal(false);
  private resizeStartX = 0;
  private resizeStartWidth = 0;
  private resizeBound: any = null;
  private resizeUpBound: any = null;

  // Progress bar
  videoProgress = signal(0);
  private progressInterval: any;

  private initialized = false;

  constructor() {
    // React to tab changes — only after init
    effect(() => {
      const tab = this.activeTab();
      if (!this.initialized) return;
      this.products.set([]);
      this.currentIndex.set(0);
      this.playingIndex.set(0);
      this.loadFeed();
    });

    // When currentIndex changes, play video
    effect(() => {
      const idx = this.currentIndex();
      this.playingIndex.set(idx);
      this.videoLoading.set(true);
      this.videoProgress.set(0);
      setTimeout(() => this.forcePlayCurrentVideo(), 100);
    });
  }

  ngOnInit() {
    // Load initial feed
    this.loadFeed();
    this.initialized = true;

    // Search
    this.searchSubject.pipe(
      debounceTime(300),
      distinctUntilChanged()
    ).subscribe(query => {
      if (query.length >= 2) {
        this.searching.set(true);
        this.productService.search(query).subscribe({
          next: (res: any) => {
            this.searchResults.set({
              products: res.products || [],
              users: res.users || [],
            });
            this.searching.set(false);
          },
          error: () => this.searching.set(false),
        });
      } else {
        this.searchResults.set({ products: [], users: [] });
      }
    });
  }

  ngOnDestroy() {
    this.searchSubject.complete();
    if (this.progressInterval) clearInterval(this.progressInterval);
  }

  // ─── Tab switch ──────────────────────────────────────
  switchTab(tab: 'following' | 'foryou' | 'friends') {
    if (tab === this.activeTab()) return;
    this.hasMorePages = true;
    this.loadingMore = false;
    this.activeTab.set(tab);
  }

  // ─── Feed Loading ──────────────────────────────────────
  loadFeed() {
    this.loading.set(true);

    // If auth-required tab but not authenticated, fall back to "foryou"
    if ((this.activeTab() === 'following' || this.activeTab() === 'friends') && !this.auth.isAuthenticated()) {
      this.activeTab.set('foryou');
    }

    let obs;
    switch (this.activeTab()) {
      case 'following':
        obs = this.productService.getFollowingFeed(1);
        break;
      case 'friends':
        obs = this.productService.getFriendsFeed(1);
        break;
      default:
        obs = this.productService.getFeed(1);
    }

    obs.subscribe({
      next: (res: any) => {
        const items = res.data || res.products || [];
        this.products.set(items);
        this.loading.set(false);
        const map: Record<string, boolean> = {};
        items.forEach((p: any) => {
          if (p.seller?.id) map[p.seller.id] = p.seller.is_following || false;
        });
        this.followingMap.set(map);
        if (items.length > 0) this.playingIndex.set(0);
      },
      error: () => this.loading.set(false),
    });
  }

  goNext(currentIdx: number) {
    if (currentIdx < this.products().length - 1) {
      this.currentIndex.set(currentIdx + 1);
      // Load more when approaching end (5 items before for smoother scrolling)
      if (currentIdx >= this.products().length - 5) this.loadMore();
    }
  }

  goPrev(currentIdx: number) {
    if (currentIdx > 0) this.currentIndex.set(currentIdx - 1);
  }

  private loadingMore = false;
  private hasMorePages = true;

  loadMore() {
    if (this.loadingMore || !this.hasMorePages) return;
    this.loadingMore = true;

    const page = Math.floor(this.products().length / 10) + 1;

    let obs;
    switch (this.activeTab()) {
      case 'following': obs = this.productService.getFollowingFeed(page); break;
      case 'friends': obs = this.productService.getFriendsFeed(page); break;
      default: obs = this.productService.getFeed(page);
    }

    obs.subscribe({
      next: (res: any) => {
        const newProducts = res.data || res.products || [];
        if (newProducts.length) {
          this.products.update(p => [...p, ...newProducts]);
          const map = { ...this.followingMap() };
          newProducts.forEach((p: any) => {
            if (p.seller?.id) map[p.seller.id] = p.seller.is_following || false;
          });
          this.followingMap.set(map);
        }
        // No more pages if we got fewer items than per_page
        if (newProducts.length < 10) this.hasMorePages = false;
        this.loadingMore = false;
      },
      error: () => { this.loadingMore = false; },
    });
  }

  // ─── Type helpers ──────────────────────────────────────
  isService(product: any): boolean {
    return product.type === 'service';
  }

  isProduct(product: any): boolean {
    return product.type !== 'service';
  }

  getTypeLabel(product: any): string {
    return product.type === 'service' ? 'SERVICE' : 'PRODUIT';
  }

  getPriceLabel(product: any): string {
    if (product.type === 'service') {
      return product.price ? `${this.formatPrice(product.price)} F` : 'Sur devis';
    }
    return `${this.formatPrice(product.price)} F CFA`;
  }

  formatPrice(price: number): string {
    if (!price) return '0';
    return price.toLocaleString('fr-FR');
  }

  getStockLabel(product: any): string {
    if (product.type === 'service') return 'Disponible';
    if (!product.stock_quantity || product.stock_quantity <= 0) return 'Rupture';
    if (product.stock_quantity <= 3) return `Plus que ${product.stock_quantity}`;
    return 'En stock';
  }

  isInStock(product: any): boolean {
    if (product.type === 'service') return true;
    return product.stock_quantity > 0;
  }

  // ─── Search ────────────────────────────────────────────
  openSearch() {
    this.showSearch.set(true);
    this.loadRecentSearches();
    this.loadSuggestions();
    // Focus input after Angular renders
    setTimeout(() => this.searchInputRef?.nativeElement?.focus(), 50);
  }

  closeSearch() {
    this.showSearch.set(false);
    this.searchQuery.set('');
    this.searchResults.set({ products: [], users: [] });
  }

  onSearchInput(value: string) {
    this.searchQuery.set(value);
    this.searchSubject.next(value);
  }

  goToProduct(slug: string) {
    this.saveRecentSearch(this.searchQuery());
    this.closeSearch();
    this.router.navigate(['/product', slug]);
  }

  goToSeller(username: string) {
    this.saveRecentSearch(this.searchQuery());
    this.closeSearch();
    this.router.navigate(['/seller', username]);
  }

  // ─── Recent Searches ─────────────────────────────────
  private loadRecentSearches() {
    try {
      const stored = localStorage.getItem(this.RECENT_KEY);
      this.recentSearches.set(stored ? JSON.parse(stored) : []);
    } catch {
      this.recentSearches.set([]);
    }
  }

  saveRecentSearch(query: string) {
    if (!query || query.trim().length < 2) return;
    const trimmed = query.trim();
    let recent = this.recentSearches();
    // Remove duplicate then add to front
    recent = [trimmed, ...recent.filter(r => r.toLowerCase() !== trimmed.toLowerCase())];
    // Keep max
    recent = recent.slice(0, this.MAX_RECENT);
    this.recentSearches.set(recent);
    localStorage.setItem(this.RECENT_KEY, JSON.stringify(recent));
  }

  useRecentSearch(query: string) {
    this.searchQuery.set(query);
    this.searchSubject.next(query);
    setTimeout(() => this.searchInputRef?.nativeElement?.focus(), 50);
  }

  removeRecentSearch(query: string, event: Event) {
    event.stopPropagation();
    const recent = this.recentSearches().filter(r => r !== query);
    this.recentSearches.set(recent);
    localStorage.setItem(this.RECENT_KEY, JSON.stringify(recent));
  }

  clearRecentSearches() {
    this.recentSearches.set([]);
    localStorage.removeItem(this.RECENT_KEY);
  }

  // ─── Suggestions ──────────────────────────────────────
  private loadSuggestions() {
    if (this.suggestions().length > 0) return; // Already loaded
    this.loadingSuggestions.set(true);
    const endpoint = this.auth.isAuthenticated() ? 'search/suggestions' : 'search/trending';
    this.apiService.get<any>(endpoint).subscribe({
      next: (res: any) => {
        this.suggestions.set(res.suggestions || []);
        this.loadingSuggestions.set(false);
      },
      error: () => this.loadingSuggestions.set(false),
    });
  }

  searchSuggestion(suggestion: any) {
    this.saveRecentSearch(suggestion.title);
    this.closeSearch();
    this.router.navigate(['/product', suggestion.slug]);
  }

  // ─── Follow / Unfollow ─────────────────────────────────
  toggleFollow(product: any, event: Event) {
    event.stopPropagation();
    if (!this.auth.isAuthenticated()) { this.router.navigate(['/auth/login']); return; }
    const sellerId = product.seller?.id;
    if (!sellerId) return;

    const isFollowing = this.followingMap()[sellerId];
    if (isFollowing) {
      this.followService.unfollow(sellerId).subscribe({
        next: () => {
          this.followingMap.update(m => ({ ...m, [sellerId]: false }));
          this.notify.success('Desabonne');
        },
        error: () => this.notify.error('Erreur'),
      });
    } else {
      this.followService.follow(sellerId).subscribe({
        next: (res: any) => {
          this.followingMap.update(m => ({ ...m, [sellerId]: true }));
          if (res.is_mutual) {
            this.notify.success('Vous êtes maintenant amis! Vous pouvez discuter dans Messages.');
          } else {
            this.notify.success('Abonné!');
          }
        },
        error: () => this.notify.error('Erreur'),
      });
    }
  }

  isFollowing(sellerId: string): boolean {
    return this.followingMap()[sellerId] || false;
  }

  viewSellerProfile(product: any, event: Event) {
    event.stopPropagation();
    const username = product.seller?.username;
    if (username) this.router.navigate(['/seller', username]);
  }

  // ─── Like ──────────────────────────────────────────────
  toggleLike(product: any) {
    if (!this.auth.isAuthenticated()) { this.router.navigate(['/auth/login']); return; }
    product.is_liked = !product.is_liked;
    product.like_count += product.is_liked ? 1 : -1;
    this.productService.toggleLike(product.id).subscribe({
      error: () => {
        product.is_liked = !product.is_liked;
        product.like_count += product.is_liked ? 1 : -1;
      }
    });
  }

  onVideoDoubleClick(product: any, event: Event) {
    event.preventDefault();
    event.stopPropagation();
    // Cancel the pending single-click (pause) so double-click only likes
    if (this.clickTimer) { clearTimeout(this.clickTimer); this.clickTimer = null; }
    if (!this.auth.isAuthenticated()) { this.router.navigate(['/auth/login']); return; }
    if (!product.is_liked) {
      product.is_liked = true;
      product.like_count += 1;
      this.productService.toggleLike(product.id).subscribe({
        error: () => { product.is_liked = false; product.like_count -= 1; }
      });
    }
    this.showLikeAnim.set(true);
    setTimeout(() => this.showLikeAnim.set(false), 800);
  }

  // ─── Cart (products only) ─────────────────────────────
  addToCart(product: any, event: Event) {
    event.stopPropagation();
    if (!this.auth.isAuthenticated()) { this.router.navigate(['/auth/login']); return; }
    this.cartService.addToCart(product.id).subscribe({
      next: () => {
        this.cartAddedMap.update(m => ({ ...m, [product.id]: true }));
        this.notify.success('Ajoute au panier!');
        setTimeout(() => {
          this.cartAddedMap.update(m => ({ ...m, [product.id]: false }));
        }, 3000);
      },
      error: () => this.notify.error('Erreur ajout panier'),
    });
  }

  isInCart(productId: string): boolean {
    return this.cartAddedMap()[productId] || false;
  }

  // ─── Contact (services) ────────────────────────────────
  contactSeller(product: any, event: Event) {
    event.stopPropagation();
    if (!this.auth.isAuthenticated()) { this.router.navigate(['/auth/login']); return; }
    this.router.navigate(['/product', product.slug], { fragment: 'contact' });
  }

  // ─── Comment ───────────────────────────────────────────
  openCommentPanel(product: any, event: Event) {
    event.stopPropagation();
    if (!this.auth.isAuthenticated()) { this.router.navigate(['/auth/login']); return; }
    this.router.navigate(['/product', product.slug], { fragment: 'comments' });
  }

  // ─── Save / Favorite ──────────────────────────────────
  toggleSave(product: any, event: Event) {
    event.stopPropagation();
    if (!this.auth.isAuthenticated()) { this.router.navigate(['/auth/login']); return; }
    const wasSaved = product.is_saved;
    product.is_saved = !product.is_saved;
    this.productService.toggleSave(product.id).subscribe({
      next: (res: any) => this.notify.success(res.saved ? 'Ajoute aux favoris!' : 'Retire des favoris.'),
      error: () => { product.is_saved = wasSaved; },
    });
  }

  // ─── Share ─────────────────────────────────────────────
  shareProduct(product: any, event: Event) {
    event.stopPropagation();
    this.shareService.shareProduct(product);
    if (this.auth.isAuthenticated()) {
      this.productService.shareProduct(product.id).subscribe();
    }
  }

  // ─── Report ────────────────────────────────────────────
  reportProduct(product: any, event: Event) {
    event.stopPropagation();
    if (!this.auth.isAuthenticated()) { this.router.navigate(['/auth/login']); return; }
    this.notify.success('Signalement envoye. Merci!');
  }

  // ─── Navigation ────────────────────────────────────────
  goToDetail(product: any) {
    this.router.navigate(['/product', product.slug]);
  }

  formatCount(n: number): string {
    if (!n) return '0';
    if (n >= 1000000) return (n / 1000000).toFixed(1) + 'M';
    if (n >= 1000) return (n / 1000).toFixed(1) + 'k';
    return String(n);
  }

  redirectToLogin() {
    this.router.navigate(['/auth/login']);
  }


  // ─── Media helpers ─────────────────────────────────────
  getMediaUrl(product: any): string | null {
    // Poster image takes priority as the main display image
    if (product.poster) return product.poster;
    if (product.poster_full_url) return product.poster_full_url;
    if (product.video?.thumbnail) return product.video.thumbnail;
    if (product.video?.thumbnail_url) return product.video.thumbnail_url;
    if (product.images?.length) return product.images[0];
    return null;
  }

  getVideoUrl(product: any): string | null {
    if (product.video?.url) return product.video.url;
    if (product.video?.video_url) return product.video.video_url;
    // Fallback: build URL from video ID
    if (product.video?.id) return `/api/v1/videos/${product.video.id}/stream`;
    return null;
  }

  hasVideo(product: any): boolean {
    return !!(this.getVideoUrl(product));
  }

  // ─── Wheel Navigation ─────────────────────────────────
  private scrollLocked = false;

  onWheel(event: WheelEvent): void {
    // Allow native scroll inside the detail panel
    if (this.detailMode()) {
      const target = event.target as HTMLElement;
      if (target.closest('.feed-detail-panel') || target.closest('.fd-resize-handle')) return;
    }
    event.preventDefault();
    if (this.scrollLocked || this.showSearch() || this.detailMode()) return;
    if (Math.abs(event.deltaY) < 4) return;
    this.scrollLocked = true;

    if (event.deltaY > 0 && this.currentIndex() < this.products().length - 1) {
      this.goNext(this.currentIndex());
    } else if (event.deltaY < 0 && this.currentIndex() > 0) {
      this.goPrev(this.currentIndex());
    }
    setTimeout(() => { this.scrollLocked = false; }, 1000);
  }

  @HostListener('window:keydown', ['$event'])
  onKeyDown(event: KeyboardEvent): void {
    if (this.showSearch() || this.detailMode()) {
      if (event.key === 'Escape' && this.detailMode()) this.closeDetail();
      return;
    }
    if (event.key === 'ArrowDown' || event.key === 'j') {
      event.preventDefault();
      if (this.currentIndex() < this.products().length - 1) this.goNext(this.currentIndex());
    } else if (event.key === 'ArrowUp' || event.key === 'k') {
      event.preventDefault();
      this.goPrev(this.currentIndex());
    } else if (event.key === 'm') {
      this.muted.update(m => !m);
    }
  }

  // ─── AfterViewInit ─────────────────────────────────────
  ngAfterViewInit() {
    this.videoPlayers.changes.subscribe(() => {
      setTimeout(() => this.forcePlayCurrentVideo(), 50);
    });
  }

  private forcePlayCurrentVideo(): void {
    if (!this.videoPlayers || this.videoPlayers.length === 0) {
      this.videoLoading.set(false);
      return;
    }
    const videoEl = this.videoPlayers.first?.nativeElement;
    if (!videoEl) { this.videoLoading.set(false); return; }

    this.videoPaused.set(false);
    videoEl.muted = true;
    if (videoEl.readyState >= 2) {
      this.playVideo(videoEl);
    } else {
      videoEl.addEventListener('canplay', () => this.playVideo(videoEl), { once: true });
      videoEl.load();
    }
  }

  private playVideo(videoEl: HTMLVideoElement): void {
    // Always start muted to comply with browser autoplay policies
    videoEl.muted = true;
    const promise = videoEl.play();
    if (promise) {
      promise
        .then(() => {
          this.videoLoading.set(false);
          this.startProgressTracking(videoEl);
          // Keep muted - user must explicitly unmute via the button
        })
        .catch(() => {
          // Retry muted if first attempt fails
          videoEl.muted = true;
          videoEl.play()
            .then(() => {
              this.videoLoading.set(false);
              this.startProgressTracking(videoEl);
            })
            .catch(() => this.videoLoading.set(false));
        });
    } else {
      this.videoLoading.set(false);
    }
  }

  private startProgressTracking(videoEl: HTMLVideoElement): void {
    if (this.progressInterval) clearInterval(this.progressInterval);
    this.progressInterval = setInterval(() => {
      if (videoEl.duration) {
        this.videoProgress.set((videoEl.currentTime / videoEl.duration) * 100);
      }
    }, 100);
  }

  onVideoCanPlay(index: number, event: Event): void {
    const videoEl = event.target as HTMLVideoElement;
    if (videoEl.paused) this.playVideo(videoEl);
  }

  onVideoPlaying(): void {
    this.videoLoading.set(false);
  }

  onVideoError(index: number): void {
    console.error('Video error at index:', index);
    this.videoLoading.set(false);
  }

  isMuted(): boolean {
    return this.muted();
  }

  toggleMute(event: Event): void {
    event.stopPropagation();
    this.muted.update(m => !m);
    const videoEl = this.videoPlayers?.first?.nativeElement;
    if (videoEl) videoEl.muted = this.muted();
  }

  toggleVideoPlayPause(event: Event): void {
    event.stopPropagation();
    // Delay to distinguish from double-click (like)
    if (this.clickTimer) return; // Already waiting
    this.clickTimer = setTimeout(() => {
      this.clickTimer = null;
      const videoEl = this.videoPlayers?.first?.nativeElement;
      if (!videoEl) return;
      if (videoEl.paused) {
        videoEl.play().then(() => this.videoPaused.set(false)).catch(() => {});
      } else {
        videoEl.pause();
        this.videoPaused.set(true);
      }
    }, 250);
  }

  // ─── Detail Panel Methods ─────────────────────────────────

  openDetail(product: any, event: Event) {
    event.stopPropagation();
    this.dp.set(product);
    this.dpImgIdx.set(0);
    this.dpSubmitted.set(false);
    this.dpNewRating.set(0);
    this.dpNewComment = '';
    this.dpContactMsg = '';
    this.dpQuoteMsg = '';
    this.dpNegoMsg = '';
    this.dpProposedPrice = 0;
    this.dpShowContact.set(false);
    this.dpShowQuote.set(false);
    this.dpShowNego.set(false);
    this.dpSending.set(false);
    this.detailMode.set(true);
    // Video continues playing — user controls pause themselves
    // Load full product + reviews
    this.productService.getProduct(product.slug).subscribe({
      next: (res: any) => {
        const full = res.product || res.data || res;
        const sellerData = res.seller || {};
        // Merge: keep feed's seller data, enrich with show endpoint's seller data + full product
        this.dp.set({
          ...product,
          ...full,
          seller: { ...product.seller, ...sellerData },
          // Preserve interaction states from show endpoint
          is_liked: res.is_liked ?? product.is_liked,
          is_saved: res.is_saved ?? product.is_saved,
          // Ensure metadata is available (from full product or feed)
          metadata: full.metadata || product.metadata || {},
          // Ensure full description (not truncated)
          description: full.description || product.description,
        });
      }
    });
    const sid = product.seller?.id;
    if (sid) {
      this.dpLoadingReviews.set(true);
      this.reviewService.getSellerReviews(sid).subscribe({
        next: (r: any) => {
          const reviewsList = r.reviews?.data || r.reviews || [];
          this.dpReviews.set(reviewsList);
          this.dpStats.set(r.stats || null);
          this.dpLoadingReviews.set(false);
          // Check if current user already reviewed
          const myId = this.auth.user()?.id;
          if (myId && reviewsList.some((rv: any) => String(rv.reviewer_id || rv.reviewer?.id) === String(myId))) {
            this.dpSubmitted.set(true);
          }
        },
        error: () => this.dpLoadingReviews.set(false),
      });
    }
  }

  closeDetail() {
    this.detailMode.set(false);
    this.dp.set(null);
    this.dpReviews.set([]);
    this.dpStats.set(null);
    this.dpShowPayment.set(false); this.dpShowContact.set(false);
    this.dpShowNego.set(false); this.dpShowQuote.set(false);
    // Reset any inline flex style from drag-resize
    document.querySelectorAll('.slide-inner .video-card').forEach((el: any) => {
      el.style.flex = '';
      el.style.maxWidth = '';
    });
  }

  // ─── Resize Handle ────────────────────────────────────────────
  startResize(e: MouseEvent) {
    e.preventDefault();
    this.resizing.set(true);
    this.resizeStartX = e.clientX;
    // Find the video card in split mode
    const slide = (e.target as HTMLElement).closest('.slide-inner');
    const videoCard = slide?.querySelector('.video-card') as HTMLElement;
    if (videoCard) this.resizeStartWidth = videoCard.getBoundingClientRect().width;
    this.resizeBound = this.onResize.bind(this, slide as HTMLElement);
    this.resizeUpBound = this.stopResize.bind(this);
    document.addEventListener('mousemove', this.resizeBound);
    document.addEventListener('mouseup', this.resizeUpBound);
    document.body.style.userSelect = 'none';
    document.body.style.cursor = 'col-resize';
  }

  onResize(slide: HTMLElement, e: MouseEvent) {
    const dx = e.clientX - this.resizeStartX;
    const newW = Math.max(250, Math.min(this.resizeStartWidth + dx, window.innerWidth - 300));
    const videoCard = slide?.querySelector('.video-card') as HTMLElement;
    if (videoCard) {
      videoCard.style.flex = `0 0 ${newW}px`;
      videoCard.style.maxWidth = `${newW}px`;
    }
  }

  stopResize() {
    this.resizing.set(false);
    document.removeEventListener('mousemove', this.resizeBound);
    document.removeEventListener('mouseup', this.resizeUpBound);
    document.body.style.userSelect = '';
    document.body.style.cursor = '';
  }

  // Helpers
  dpIsService(): boolean { return this.dp()?.type === 'service'; }
  dpIsProduct(): boolean { return !this.dpIsService(); }
  dpTypeIcon(): string { return this.dpIsService() ? 'handyman' : 'shopping_bag'; }
  dpTypeLabel(): string { return this.dpIsService() ? 'Service' : 'Produit'; }
  dpSellerAvatar(): string | null { const p = this.dp(); return p?.seller?.avatar_url || p?.seller?.avatar || null; }
  dpSellerName(): string { const p = this.dp(); return p?.seller?.full_name || p?.seller?.username || 'Vendeur'; }
  dpSellerUsername(): string { return this.dp()?.seller?.username || ''; }
  dpTrustScore(): number { return this.dp()?.seller?.trust_score || 0; }
  dpSellerCity(): string { return this.dp()?.seller?.city || ''; }
  dpCondition(): string {
    const c = this.dp()?.condition;
    if (c === 'new') return 'Neuf'; if (c === 'like_new') return 'Comme neuf';
    if (c === 'good') return 'Bon etat'; if (c === 'fair') return 'Etat correct';
    return c || 'Non precise';
  }
  starArray = [1, 2, 3, 4, 5];
  dpDistPct(star: number): number {
    const s = this.dpStats(); if (!s?.total) return 0;
    return ((s.distribution?.[star] || 0) / s.total) * 100;
  }
  dpTimeAgo(d: string): string {
    if (!d) return '';
    const ms = Date.now() - new Date(d).getTime();
    const m = Math.floor(ms / 60000); if (m < 60) return `Il y a ${m}min`;
    const h = Math.floor(m / 60); if (h < 24) return `Il y a ${h}h`;
    const j = Math.floor(h / 24); if (j < 30) return `Il y a ${j}j`;
    return `Il y a ${Math.floor(j / 30)} mois`;
  }

  // Delivery helpers
  dpDeliveryLabel(): string {
    const p = this.dp();
    if (!p) return 'Non precise';
    if (p.delivery_option === 'fixed' && p.delivery_fee > 0) {
      return p.delivery_fee.toLocaleString('fr-FR') + ' F CFA';
    }
    if (p.delivery_option === 'fixed') return 'Frais a definir';
    return 'A convenir avec le vendeur';
  }

  // Payment methods
  allPaymentMethods = [
    { id: 'orange_money', name: 'Orange Money', icon: 'phone_android' },
    { id: 'wave', name: 'Wave', icon: 'waves' },
    { id: 'free_money', name: 'Free Money', icon: 'smartphone' },
    { id: 'cash_delivery', name: 'Paiement a la livraison', icon: 'local_shipping' },
    { id: 'cash_hand', name: 'Especes (en main propre)', icon: 'payments' },
    { id: 'bank_transfer', name: 'Virement bancaire', icon: 'account_balance' },
  ];

  dpPaymentMethods(): { id: string; name: string; icon: string }[] {
    const p = this.dp();
    if (!p?.payment_methods?.length) return [];
    return this.allPaymentMethods.filter(m => p.payment_methods.includes(m.id));
  }

  dpSellerMemberSince(): string { return this.dp()?.seller?.member_since || ''; }

  // ─── Service Metadata Helpers ─────────────────────────────────
  private dpMeta(key: string): any {
    const p = this.dp();
    return p?.metadata?.[key] || null;
  }

  dpServiceType(): string {
    const t = this.dpMeta('service_type');
    if (t === 'online') return 'En ligne';
    if (t === 'in_person') return 'Sur place';
    if (t === 'both') return 'En ligne et sur place';
    return 'Non precise';
  }

  dpServiceTypeIcon(): string {
    const t = this.dpMeta('service_type');
    if (t === 'online') return 'language';
    if (t === 'in_person') return 'store';
    if (t === 'both') return 'swap_horiz';
    return 'miscellaneous_services';
  }

  dpAvailability(): string {
    const a = this.dpMeta('availability');
    if (a === 'everyday') return 'Tous les jours';
    if (a === 'weekdays') return 'Lundi - Vendredi';
    if (a === 'weekends') return 'Weekends uniquement';
    if (a === 'appointment') return 'Sur rendez-vous';
    if (a === 'custom') return 'Horaires personnalises';
    return a || 'Non precise';
  }

  dpDuration(): string {
    const d = this.dpMeta('duration');
    if (d === '30min') return '30 minutes';
    if (d === '1h') return '1 heure';
    if (d === '2h') return '2 heures';
    if (d === 'half_day') return 'Demi-journee';
    if (d === 'full_day') return 'Journee entiere';
    if (d === 'custom') return 'Variable';
    return d || 'Non precise';
  }

  dpServiceArea(): string { return this.dpMeta('service_area') || 'Non precise'; }
  dpExperience(): string {
    const y = this.dpMeta('experience_years');
    if (!y) return 'Non precise';
    return y + (Number(y) > 1 ? ' ans' : ' an');
  }

  dpPriceType(): string {
    const t = this.dpMeta('price_type');
    if (t === 'fixed') return 'Prix fixe';
    if (t === 'starting') return 'A partir de';
    if (t === 'hourly') return 'Tarif horaire';
    if (t === 'quote') return 'Sur devis';
    return 'Non precise';
  }

  dpPriceTypeIcon(): string {
    const t = this.dpMeta('price_type');
    if (t === 'fixed') return 'sell';
    if (t === 'starting') return 'trending_up';
    if (t === 'hourly') return 'schedule';
    if (t === 'quote') return 'request_quote';
    return 'payments';
  }

  dpCreatedAt(): string {
    const p = this.dp();
    if (!p?.created_at) return '';
    return this.dpTimeAgo(p.created_at);
  }

  dpSetRating(r: number) { this.dpNewRating.set(r); }
  dpSubmitReview() {
    const p = this.dp(); if (!p?.seller?.id || !this.dpNewRating()) return;
    this.dpSubmitting.set(true);
    this.reviewService.createReview({ seller_id: p.seller.id, rating: this.dpNewRating(), comment: this.dpNewComment || undefined }).subscribe({
      next: () => { this.dpSubmitting.set(false); this.dpSubmitted.set(true); this.notify.success('Avis publie!'); },
      error: (err: any) => { this.dpSubmitting.set(false); this.notify.error(err?.error?.message || 'Erreur lors de la publication.'); },
    });
  }

  // Images
  dpImages(): string[] {
    const p = this.dp(); if (!p) return [];
    const imgs: string[] = [];
    // Poster first
    const poster = p.poster || p.poster_full_url;
    if (poster && !imgs.includes(poster)) imgs.push(poster);
    if (p.images?.length) p.images.forEach((i: string) => { if (i && !imgs.includes(i)) imgs.push(i); });
    if (!imgs.length) { const t = p.video?.thumbnail_url || p.video?.thumbnail; if (t) imgs.push(t); }
    return imgs;
  }
  dpNextImg() { const l = this.dpImages().length; if (l > 1) this.dpImgIdx.update(i => (i + 1) % l); }
  dpPrevImg() { const l = this.dpImages().length; if (l > 1) this.dpImgIdx.update(i => i === 0 ? l - 1 : i - 1); }

  // CTAs
  dpBuyNow() { this.dpShowPayment.set(true); }
  dpAddToCart() {
    const p = this.dp(); if (!p) return;
    this.dpAddingCart.set(true);
    this.cartService.addToCart(p.id).subscribe({
      next: () => { this.dpAddingCart.set(false); this.notify.success('Ajoute au panier!'); },
      error: () => { this.dpAddingCart.set(false); this.notify.error('Erreur'); },
    });
  }
  dpIsOwner(): boolean {
    const p = this.dp();
    const userId = this.auth.user()?.id;
    if (!p || !userId) return false;
    const candidates = [p.seller?.id, p.user?.id, p.user_id];
    return candidates.some((id: any) => id != null && String(id) === String(userId));
  }

  private dpGetSellerId(): string | null {
    const p = this.dp();
    return p?.seller?.id || p?.user?.id || p?.user_id || null;
  }

  dpSendContact() {
    const p = this.dp();
    const sellerId = this.dpGetSellerId();
    if (!p || !sellerId || !this.dpContactMsg.trim()) return;
    if (this.dpIsOwner()) { this.notify.warning('Vous ne pouvez pas vous contacter vous-meme.'); return; }
    this.dpSending.set(true);
    this.chatService.startConversation(sellerId, this.dpContactMsg.trim(), p.id).subscribe({
      next: () => {
        this.dpSending.set(false);
        this.dpShowContact.set(false);
        this.notify.success('Message envoye!');
        this.dpContactMsg = '';
        this.router.navigate(['/messages']);
      },
      error: (err: any) => {
        this.dpSending.set(false);
        this.notify.error(err?.error?.message || 'Erreur lors de l\'envoi.');
      },
    });
  }

  dpSendQuote() {
    const p = this.dp();
    const sellerId = this.dpGetSellerId();
    if (!p || !sellerId || !this.dpQuoteMsg.trim()) return;
    if (this.dpIsOwner()) { this.notify.warning('Vous ne pouvez pas vous contacter vous-meme.'); return; }
    this.dpSending.set(true);
    const msg = `[Demande de devis] ${this.dpQuoteMsg.trim()}`;
    this.chatService.startConversation(sellerId, msg, p.id).subscribe({
      next: () => {
        this.dpSending.set(false);
        this.dpShowQuote.set(false);
        this.notify.success('Demande de devis envoyee!');
        this.dpQuoteMsg = '';
        this.router.navigate(['/messages']);
      },
      error: (err: any) => {
        this.dpSending.set(false);
        this.notify.error(err?.error?.message || 'Erreur lors de l\'envoi.');
      },
    });
  }

  dpSendNego() {
    const p = this.dp();
    if (!p || !this.dpProposedPrice) return;
    if (this.dpIsOwner()) { this.notify.warning('Vous ne pouvez pas negocier votre propre annonce.'); return; }
    this.dpSending.set(true);
    this.negotiationService.propose(p.id, this.dpProposedPrice, this.dpNegoMsg).subscribe({
      next: () => {
        this.dpSending.set(false);
        this.dpShowNego.set(false);
        this.notify.success('Offre envoyee au vendeur!');
        this.dpProposedPrice = 0;
        this.dpNegoMsg = '';
      },
      error: (err: any) => {
        this.dpSending.set(false);
        this.notify.error(err?.error?.message || 'Erreur lors de l\'envoi.');
      },
    });
  }
  dpConfirmPay() { this.notify.success('Paiement confirme!'); this.dpShowPayment.set(false); }
  dpToggleLike() {
    const p = this.dp(); if (!p || !this.auth.isAuthenticated()) return;
    p.is_liked = !p.is_liked; p.like_count = (p.like_count || 0) + (p.is_liked ? 1 : -1);
    this.dp.set({ ...p }); this.productService.toggleLike(p.id).subscribe({ error: () => { p.is_liked = !p.is_liked; p.like_count += p.is_liked ? 1 : -1; this.dp.set({ ...p }); } });
  }
  dpToggleSave() {
    const p = this.dp(); if (!p || !this.auth.isAuthenticated()) return;
    p.is_saved = !p.is_saved; this.dp.set({ ...p }); this.productService.toggleSave(p.id).subscribe({ error: () => { p.is_saved = !p.is_saved; this.dp.set({ ...p }); } });
  }
  dpShare() { const p = this.dp(); if (p) { this.shareService.shareProduct(p); this.productService.shareProduct(p.id).subscribe(); } }
  dpReport() { this.notify.success('Signalement envoye. Merci!'); }
  dpGoFull() { const s = this.dp()?.slug; if (s) { this.closeDetail(); this.router.navigate(['/product', s]); } }

  payMethods = [
    { id: 'om', name: 'Orange Money', icon: 'phone_android', desc: 'Paiement via Orange Money' },
    { id: 'wave', name: 'Wave', icon: 'waves', desc: 'Paiement via Wave' },
    { id: 'free', name: 'Free Money', icon: 'smartphone', desc: 'Paiement via Free Money' },
    { id: 'card', name: 'Carte bancaire', icon: 'credit_card', desc: 'Visa, Mastercard' },
  ];

  onImgError(event: Event): void {
    const img = event.target as HTMLImageElement;
    img.style.opacity = '0';
  }

  // ─── Hashtag & Mention Formatting ─────────────────
  formatDescription(text: string): string {
    if (!text) return '';
    // Escape HTML first
    const escaped = text.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
    // Replace #hashtags
    let formatted = escaped.replace(/#(\w+)/g, '<span class="hashtag">#$1</span>');
    // Replace @mentions
    formatted = formatted.replace(/@(\w+)/g, '<span class="mention">@$1</span>');
    return formatted;
  }
}
