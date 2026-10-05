import { Component, inject, OnInit, OnDestroy, signal, ViewChild, ElementRef, AfterViewInit } from '@angular/core';
import { Subscription } from 'rxjs';
import { ActivatedRoute, Router, RouterLink } from '@angular/router';
import { DecimalPipe, Location } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { ProductService } from '../../core/services/product.service';
import { FavoriteService } from '../../core/services/favorite.service';
import { ShareService } from '../../core/services/share.service';
import { NegotiationService } from '../../core/services/negotiation.service';
import { ChatService } from '../../core/services/chat.service';
import { NotificationService } from '../../core/services/notification.service';
import { AnalyticsService } from '../../core/services/analytics.service';
import { AuthService } from '../../core/services/auth.service';
import { ReviewService, Review, ReviewStats } from '../../core/services/review.service';
import { Product } from '../../core/models/product.model';

@Component({
  selector: 'app-product-detail',
  standalone: true,
  imports: [DecimalPipe, FormsModule, RouterLink],
  templateUrl: './product-detail.component.html',
  styleUrl: './product-detail.component.scss',
})
export class ProductDetailComponent implements OnInit, OnDestroy, AfterViewInit {
  @ViewChild('detailVideo') detailVideoRef!: ElementRef<HTMLVideoElement>;

  private route = inject(ActivatedRoute);
  private router = inject(Router);
  private location = inject(Location);
  private productService = inject(ProductService);
  private favService = inject(FavoriteService);
  private shareService = inject(ShareService);
  private negotiationService = inject(NegotiationService);
  private chatService = inject(ChatService);
  private notify = inject(NotificationService);
  private analytics = inject(AnalyticsService);
  private reviewService = inject(ReviewService);
  auth = inject(AuthService);

  product = signal<any | null>(null);
  loading = signal(true);

  // UI State
  showShareModal = signal(false);
  showNegotiateModal = signal(false);
  showContactModal = signal(false);
  isFavorited = signal(false);
  activeMediaTab = signal<'video' | 'photos'>('video');

  // Video
  videoPlaying = signal(false);
  videoMuted = signal(true);
  videoProgress = signal(0);
  private progressInterval: any;

  // Images
  currentImgIdx = signal(0);

  // Fullscreen lightbox
  showFullscreen = signal(false);

  // Negotiation
  proposedPrice = 0;
  negotiateMessage = '';

  // Contact / Quote
  contactMessage = '';
  quoteMessage = '';
  showQuoteModal = signal(false);

  // Reviews
  reviews = signal<Review[]>([]);
  reviewStats = signal<ReviewStats | null>(null);
  loadingReviews = signal(false);
  newReviewRating = signal(0);
  newReviewHover = signal(0);
  newReviewComment = '';
  submittingReview = signal(false);
  reviewSubmitted = signal(false);

  // All known payment methods (master list) — source unique de vérité,
  // reflète PaymentGatewayFactory côté backend (voir ProductService).
  allPaymentMethods = ProductService.ALL_PAYMENT_METHODS;

  // Seller's accepted payment methods (filtered from product data)
  get sellerPaymentMethods() {
    const p = this.product();
    if (!p || !p.payment_methods || !Array.isArray(p.payment_methods) || p.payment_methods.length === 0) {
      return [];
    }
    return this.allPaymentMethods.filter(m => p.payment_methods.includes(m.id));
  }

  get hasSellerPaymentMethods(): boolean {
    return this.sellerPaymentMethods.length > 0;
  }

  private paramSub?: Subscription;
  private loadedSlug: string | null = null;

  ngOnInit() {
    // Angular réutilise le composant quand on passe de /product/a à /product/b :
    // sans cet abonnement, l'état de la 1re annonce (avis déjà publié, avis,
    // note…) restait affiché sur la 2e — c'est ce qui faisait « apparaître » un
    // commentaire sur une autre annonce du même vendeur.
    this.paramSub = this.route.paramMap.subscribe(params => {
      const slug = params.get('slug');
      if (slug && slug !== this.loadedSlug) {
        this.loadedSlug = slug;
        this.resetPerProductState();
        this.loadProductBySlug(slug);
      }
    });
  }

  ngOnDestroy() { this.paramSub?.unsubscribe(); }

  private resetPerProductState() {
    this.product.set(null);
    this.loading.set(true);
    this.reviews.set([]);
    this.reviewStats.set(null);
    this.loadingReviews.set(false);
    this.newReviewRating.set(0);
    this.newReviewHover.set(0);
    this.newReviewComment = '';
    this.submittingReview.set(false);
    this.reviewSubmitted.set(false);
    this.currentImgIdx.set(0);
    this.showReportModal.set(false);
  }

  private loadProductBySlug(slug: string) {
    if (slug) {
      this.productService.getProduct(slug).subscribe({
        next: (res: any) => {
          if (this.loadedSlug !== slug) return; // réponse périmée
          const p = res.product || res.data || res;
          // Ensure type defaults
          if (!p.type) p.type = 'product';
          // Merge top-level fields (is_liked, is_saved, seller) into product
          if (res.is_liked !== undefined) p.is_liked = res.is_liked;
          if (res.is_saved !== undefined) p.is_saved = res.is_saved;
          if (res.seller && !p.seller) p.seller = res.seller;
          // Ensure images is always an array. Le backend garde volontairement
          // le poster (couverture) a part des "images" (photos supplementaires
          // du produit) — on ne les fusionne plus ici. Melanger les deux
          // faussait le compteur "Photos (N)" et forcait l'onglet Photos par
          // defaut meme sur un produit uniquement video (le poster suffisait
          // a rendre p.images non-vide), ce qui masquait systematiquement la
          // video a l'ouverture de la fiche produit.
          if (!p.images) p.images = [];

          if (res.is_saved !== undefined) this.isFavorited.set(res.is_saved);
          this.product.set(p);
          this.loading.set(false);
          this.analytics.trackProductView(p.id);
          this.productService.viewProduct(p.id).subscribe();

          // Onglet par defaut : la video prime quand elle existe (coeur de
          // l'experience QUINCH), sinon les vraies photos supplementaires.
          if (this.hasVideo()) {
            this.activeMediaTab.set('video');
          } else if (p.images?.length) {
            this.activeMediaTab.set('photos');
          }

          // Auto-play video after Angular renders the template
          // Must wait for the @if (hasVideo()) block to create the <video> element
          setTimeout(() => this.tryAutoPlayVideo(), 200);
          // Retry in case first attempt was too early
          setTimeout(() => this.tryAutoPlayVideo(), 800);

          // Load reviews for the seller
          this.loadReviews(p);

          // Check if navigated with #contact or #comments fragment
          const fragment = this.route.snapshot.fragment;
          if (fragment === 'contact') {
            setTimeout(() => this.openContact(), 300);
          } else if (fragment === 'comments') {
            setTimeout(() => {
              document.getElementById('reviews-section')?.scrollIntoView({ behavior: 'smooth' });
            }, 500);
          } else if (fragment === 'buy') {
            // Ancien lien « Acheter » (conservé pour les liens déjà partagés) :
            // QUINCH n'a plus d'achat en ligne, on ouvre la discussion à la place.
            setTimeout(() => this.openContact(), 300);
          }
        },
        error: () => { if (this.loadedSlug === slug) this.loading.set(false); },
      });
    }
  }

  ngAfterViewInit() {
    // Fallback: try auto-play if product was already loaded (from cache/resolver)
    if (this.product()) {
      setTimeout(() => this.tryAutoPlayVideo(), 200);
    }
  }

  // ─── Type helpers ──────────────────────────────────────
  isService(): boolean {
    return this.product()?.type === 'service';
  }

  isProduct(): boolean {
    return this.product()?.type !== 'service';
  }

  /** Check if the current user is the owner/seller of this product */
  isOwner(): boolean {
    const p = this.product();
    const userId = this.auth.user()?.id;
    if (!p || !userId) return false;
    // Check all possible seller ID sources
    const candidates = [p.seller?.id, p.user?.id, p.user_id];
    return candidates.some(id => id != null && String(id) === String(userId));
  }

  getTypeLabel(): string {
    return this.isService() ? 'Service' : 'Produit';
  }

  getTypeIcon(): string {
    return this.isService() ? 'handyman' : 'shopping_bag';
  }

  // ─── Navigation ────────────────────────────────────────
  goBack() {
  if (window.history.length > 1) {
    this.location.back();
  } else {
    this.router.navigate(['/feed']);
  }
}

  // ─── Like ──────────────────────────────────────────────
  toggleLike() {
    const p = this.product();
    if (!p) return;
    if (!this.auth.isAuthenticated()) { this.router.navigate(['/auth/login']); return; }
    p.is_liked = !p.is_liked;
    p.like_count += p.is_liked ? 1 : -1;
    this.product.set({ ...p });
    this.productService.likeProduct(p.id).subscribe();
    this.analytics.trackProductLike(p.id);
  }

  // ─── Favorite ──────────────────────────────────────────
  toggleFavorite() {
    const p = this.product();
    if (!p) return;
    if (!this.auth.isAuthenticated()) { this.router.navigate(['/auth/login']); return; }
    this.favService.toggleFavorite(p.id).subscribe({
      next: (res: any) => {
        this.isFavorited.set(res.favorited);
        this.notify.success(res.favorited ? 'Ajoute aux favoris!' : 'Retire des favoris.');
      },
    });
  }

  // ─── Share ─────────────────────────────────────────────
  openShare() { this.showShareModal.set(true); }

  shareVia(platform: string) {
    const p = this.product();
    if (!p) return;
    this.shareService.trackShare(p.id, platform).subscribe();
    this.analytics.trackShare(p.id, platform);
    switch (platform) {
      case 'whatsapp': this.shareService.shareViaWhatsApp(p); break;
      case 'facebook': this.shareService.shareViaFacebook(p.slug); break;
      case 'copy': this.shareService.copyLink(p.slug); break;
      default: this.shareService.shareProduct(p);
    }
    this.showShareModal.set(false);
  }

  // ─── Negotiate ─────────────────────────────────────────
  openNegotiate() {
    if (!this.auth.isAuthenticated()) { this.router.navigate(['/auth/login']); return; }
    this.proposedPrice = Math.round((this.product()?.price || 0) * 0.85);
    this.showNegotiateModal.set(true);
  }

  submitNegotiation() {
    const p = this.product();
    if (!p || !this.proposedPrice) return;
    this.negotiationService.propose(p.id, this.proposedPrice, this.negotiateMessage).subscribe({
      next: () => {
        this.showNegotiateModal.set(false);
        this.notify.success('Votre offre a ete envoyee au vendeur!');
        this.negotiateMessage = '';
      },
      error: (err: any) => this.notify.error(err?.error?.message || 'Erreur lors de l\'envoi.'),
    });
  }

  // ─── Contact seller ────────────────────────────────────
  openContact() {
    if (!this.auth.isAuthenticated()) { this.router.navigate(['/auth/login']); return; }
    if (this.isOwner()) { this.notify.warning('Vous ne pouvez pas vous contacter vous-meme.'); return; }
    this.showContactModal.set(true);
  }

  sendContactMessage() {
    const p = this.product();
    const sellerId = p?.seller?.id || p?.user?.id || p?.user_id;
    if (!p || !sellerId || !this.contactMessage.trim()) return;
    if (this.isOwner()) { this.notify.warning('Vous ne pouvez pas vous contacter vous-meme.'); return; }
    this.chatService.startConversation(sellerId, this.contactMessage.trim(), p.id).subscribe({
      next: () => {
        this.showContactModal.set(false);
        this.notify.success('Message envoye!');
        this.contactMessage = '';
        this.router.navigate(['/messages']);
      },
      error: (err: any) => this.notify.error(err?.error?.message || 'Erreur lors de l\'envoi.'),
    });
  }

  // ─── Request quote (services) ──────────────────────────
  openQuote() {
    if (!this.auth.isAuthenticated()) { this.router.navigate(['/auth/login']); return; }
    if (this.isOwner()) { this.notify.warning('Vous ne pouvez pas vous contacter vous-meme.'); return; }
    this.showQuoteModal.set(true);
  }

  sendQuoteRequest() {
    const p = this.product();
    const sellerId = p?.seller?.id || p?.user?.id || p?.user_id;
    if (!p || !sellerId || !this.quoteMessage.trim()) return;
    if (this.isOwner()) { this.notify.warning('Vous ne pouvez pas vous contacter vous-meme.'); return; }
    const msg = `[Demande de devis] ${this.quoteMessage.trim()}`;
    this.chatService.startConversation(sellerId, msg, p.id).subscribe({
      next: () => {
        this.showQuoteModal.set(false);
        this.notify.success('Demande de devis envoyee!');
        this.quoteMessage = '';
        this.router.navigate(['/messages']);
      },
      error: (err: any) => this.notify.error(err?.error?.message || 'Erreur lors de l\'envoi.'),
    });
  }

  // ─── Video helpers ─────────────────────────────────────
  getProductVideoUrl(): string | null {
    const p = this.product();
    if (!p || !p.video) return null;
    // Try all possible URL fields
    const video = p.video as any;
    if (video.video_url) return video.video_url;
    if (video.url) return video.url;
    // Fallback: build URL from video ID
    if (video.id) return `/api/v1/videos/${video.id}/stream`;
    return null;
  }

  getProductThumbnail(): string | null {
    const p = this.product();
    if (!p) return null;
    // Poster image is the main product image
    if (p.poster) return p.poster;
    if (p.poster_full_url) return p.poster_full_url;
    if (!p.video) return p.images?.[0] || null;
    const video = p.video as any;
    if (video.thumbnail_url) return video.thumbnail_url;
    if (video.thumbnail) return video.thumbnail;
    return p.images?.[0] || null;
  }

  hasVideo(): boolean {
    return !!this.getProductVideoUrl();
  }

  getVideoThumbnail(): string | null {
    const p = this.product();
    if (!p?.video) return null;
    const video = p.video as any;
    return video.thumbnail_url || video.thumbnail || null;
  }

  private autoPlayAttempts = 0;

  private tryAutoPlayVideo(): void {
    const videoEl = this.detailVideoRef?.nativeElement;
    if (!videoEl) {
      if (this.autoPlayAttempts < 15) {
        this.autoPlayAttempts++;
        setTimeout(() => this.tryAutoPlayVideo(), 300);
      }
      return;
    }

    // Ensure muted for autoplay policy
    videoEl.muted = true;

    // If using <source> child, we need to call load() explicitly
    videoEl.load();

    // Wait for data to load, then play
    const attemptPlay = () => {
      const playPromise = videoEl.play();
      if (playPromise) {
        playPromise.then(() => {
          this.videoPlaying.set(true);
          this.startProgressTracking(videoEl);
        }).catch(() => {
          // Autoplay blocked - user will need to click play
          this.videoPlaying.set(false);
        });
      }
    };

    if (videoEl.readyState >= 2) {
      attemptPlay();
    } else {
      videoEl.addEventListener('loadeddata', () => attemptPlay(), { once: true });
    }
  }

  /** Called when video data has loaded (loadeddata event) */
  onVideoLoaded(event: Event): void {
    const video = event.target as HTMLVideoElement;
    video.muted = true;
    const playPromise = video.play();
    if (playPromise) {
      playPromise.then(() => {
        this.videoPlaying.set(true);
        this.startProgressTracking(video);
      }).catch(() => {
        this.videoPlaying.set(false);
      });
    }
  }

  /** Called when the video actually starts playing (playing event) */
  onVideoPlaying(): void {
    this.videoPlaying.set(true);
    const videoEl = this.detailVideoRef?.nativeElement;
    if (videoEl) this.startProgressTracking(videoEl);
  }

  /** Called when the video is paused (pause event) */
  onVideoPaused(): void {
    this.videoPlaying.set(false);
  }

  onVideoPlayError(): void {
    console.error('Video play error for URL:', this.getProductVideoUrl());
    this.videoPlaying.set(false);
  }

  private startProgressTracking(videoEl: HTMLVideoElement): void {
    if (this.progressInterval) clearInterval(this.progressInterval);
    this.progressInterval = setInterval(() => {
      if (videoEl.duration) {
        this.videoProgress.set((videoEl.currentTime / videoEl.duration) * 100);
      }
    }, 200);
  }

  /** Clic sur la barre de progression : se place à la position cliquée. */
  seekVideo(event: MouseEvent): void {
    event.stopPropagation();
    const videoEl = this.detailVideoRef?.nativeElement;
    const bar = event.currentTarget as HTMLElement | null;
    if (!videoEl || !bar || !isFinite(videoEl.duration) || videoEl.duration <= 0) return;
    const rect = bar.getBoundingClientRect();
    if (rect.width <= 0) return;
    const ratio = Math.min(1, Math.max(0, (event.clientX - rect.left) / rect.width));
    videoEl.currentTime = ratio * videoEl.duration;
    this.videoProgress.set(ratio * 100);
  }

  toggleVideoMute(): void {
    this.videoMuted.update(m => !m);
    const videoEl = this.detailVideoRef?.nativeElement;
    if (videoEl) videoEl.muted = this.videoMuted();
  }

  toggleVideoPlay(): void {
    const videoEl = this.detailVideoRef?.nativeElement;
    if (!videoEl) return;
    if (videoEl.paused) {
      videoEl.muted = true;
      // If video hasn't loaded yet, try loading first
      if (videoEl.readyState === 0) {
        videoEl.load();
      }
      const p = videoEl.play();
      if (p) {
        p.then(() => this.videoPlaying.set(true)).catch(() => {
          this.videoPlaying.set(false);
        });
      }
    } else {
      videoEl.pause();
      this.videoPlaying.set(false);
    }
  }

  // ─── Reviews ──────────────────────────────────────────
  private loadReviews(p: any): void {
    const sellerId = p?.seller?.id || p?.user?.id;
    if (!sellerId) return;
    this.loadingReviews.set(true);
    this.reviewService.getSellerReviews(sellerId, p.id).subscribe({
      next: (res: any) => {
        if (this.product()?.id !== p.id) return; // réponse d'une annonce déjà quittée
        const reviewsList = res.reviews?.data || res.reviews || [];
        this.reviews.set(reviewsList);
        this.reviewStats.set(res.stats || null);
        this.loadingReviews.set(false);

        // Check if current user already reviewed this seller
        const myId = this.auth.user()?.id;
        if (myId) {
          const alreadyReviewed = reviewsList.some(
            (r: any) => String(r.reviewer_id || r.reviewer?.id) === String(myId)
          );
          if (alreadyReviewed) {
            this.reviewSubmitted.set(true);
          }
        }
      },
      error: () => this.loadingReviews.set(false),
    });
  }

  setReviewRating(stars: number): void {
    this.newReviewRating.set(stars);
  }

  submitReview(): void {
    const p = this.product();
    const sellerId = p?.seller?.id || p?.user?.id;
    if (!p || !sellerId || !this.newReviewRating()) return;
    if (!this.auth.isAuthenticated()) { this.router.navigate(['/auth/login']); return; }

    this.submittingReview.set(true);
    this.reviewService.createReview({
      seller_id: sellerId,
      product_id: p.id,
      rating: this.newReviewRating(),
      comment: this.newReviewComment.trim() || undefined,
    }).subscribe({
      next: () => {
        this.submittingReview.set(false);
        this.reviewSubmitted.set(true);
        this.notify.success('Avis publie! Merci pour votre retour.');
        this.newReviewComment = '';
        this.newReviewRating.set(0);
        // Reload reviews
        this.loadReviews(p);
      },
      error: (err: any) => {
        this.submittingReview.set(false);
        this.notify.error(err?.error?.message || 'Erreur lors de la publication de l\'avis.');
      },
    });
  }

  getStarArray(): number[] {
    return [1, 2, 3, 4, 5];
  }

  getDistributionPercent(stars: number): number {
    const stats = this.reviewStats();
    if (!stats || !stats.total) return 0;
    return ((stats.distribution[stars] || 0) / stats.total) * 100;
  }

  getTimeAgo(dateStr: string): string {
    const now = new Date();
    const date = new Date(dateStr);
    const diffMs = now.getTime() - date.getTime();
    const diffDays = Math.floor(diffMs / (1000 * 60 * 60 * 24));
    if (diffDays === 0) return "Aujourd'hui";
    if (diffDays === 1) return 'Hier';
    if (diffDays < 7) return `Il y a ${diffDays} jours`;
    if (diffDays < 30) return `Il y a ${Math.floor(diffDays / 7)} sem.`;
    if (diffDays < 365) return `Il y a ${Math.floor(diffDays / 30)} mois`;
    return `Il y a ${Math.floor(diffDays / 365)} an(s)`;
  }

  // ─── Report ────────────────────────────────────────────
  showReportModal = signal(false);
  reportReason = '';
  reportDescription = '';
  submittingReport = signal(false);

  reportThisProduct() {
    if (!this.auth.isAuthenticated()) { this.router.navigate(['/auth/login']); return; }
    this.reportReason = '';
    this.reportDescription = '';
    this.showReportModal.set(true);
  }

  submitReport() {
    const p = this.product();
    if (!p || !this.reportReason) return;
    this.submittingReport.set(true);
    this.productService.reportProduct(p.id, this.reportReason, this.reportDescription || undefined).subscribe({
      next: () => {
        this.submittingReport.set(false);
        this.showReportModal.set(false);
        this.notify.success('Signalement envoye. Notre equipe va examiner ce contenu. Merci!');
      },
      error: (err) => {
        this.submittingReport.set(false);
        if (err?.status === 409) {
          this.showReportModal.set(false);
          this.notify.success(err?.error?.message || 'Vous avez deja signale ce contenu. Il est en cours de traitement.');
        } else {
          this.notify.error('Erreur lors de l\'envoi du signalement.');
        }
      },
    });
  }

  // ─── Condition label ───────────────────────────────────
  getConditionLabel(): string {
    const conditions: Record<string, string> = {
      new: 'Neuf', like_new: 'Comme neuf', good: 'Bon etat', fair: 'Passable',
    };
    return conditions[this.product()?.condition || ''] || 'N/A';
  }

  // ─── Seller helpers ────────────────────────────────────
  getSellerName(): string {
    const p = this.product();
    return p?.seller?.full_name || p?.seller?.name || p?.user?.full_name || 'Vendeur';
  }

  getSellerAvatar(): string | null {
    const p = this.product();
    return p?.seller?.avatar || p?.seller?.avatar_url || p?.user?.avatar_url || null;
  }

  getSellerCity(): string | null {
    const p = this.product();
    return p?.seller?.city || p?.user?.city || null;
  }

  getSellerTrustScore(): number {
    const p = this.product();
    return p?.seller?.trust_score || p?.user?.trust_score || 0;
  }

  getSellerUsername(): string {
    const p = this.product();
    return p?.seller?.username || p?.user?.username || '';
  }

  getSellerKycVerified(): boolean {
    const p = this.product();
    return (p?.seller?.kyc_status || p?.user?.kyc_status) === 'verified';
  }

  /** Badges reels du vendeur (verifie, top vendeur, etc.) — visibles pour tout
   * le monde, y compris le vendeur lui-meme en train de consulter sa propre
   * fiche produit. */
  getSellerBadges(): any[] {
    const p = this.product();
    return p?.seller?.badges || p?.user?.badges || [];
  }

  // ─── Fullscreen lightbox ─────────────────────────────────
  openFullscreen(): void {
    this.showFullscreen.set(true);
    document.body.style.overflow = 'hidden';
  }

  closeFullscreen(): void {
    this.showFullscreen.set(false);
    document.body.style.overflow = '';
  }

  // ─── Images ────────────────────────────────────────────
  prevImg(event: Event): void {
    event.stopPropagation();
    const p = this.product();
    if (!p?.images?.length) return;
    this.currentImgIdx.update(i => i > 0 ? i - 1 : p.images!.length - 1);
  }

  nextImg(event: Event): void {
    event.stopPropagation();
    const p = this.product();
    if (!p?.images?.length) return;
    this.currentImgIdx.update(i => i < p.images!.length - 1 ? i + 1 : 0);
  }

  onMediaError(event: Event): void {
    const el = event.target as HTMLImageElement;
    el.style.opacity = '0';
  }

  formatPrice(price: number): string {
    if (!price) return '0';
    return price.toLocaleString('fr-FR');
  }

  // ─── Hashtag & Mention Formatting ─────────────────
  formatDescription(text: string): string {
    if (!text) return '';
    const escaped = text.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
    let formatted = escaped.replace(/#(\w+)/g, '<span class="hashtag">#$1</span>');
    formatted = formatted.replace(/@(\w+)/g, '<span class="mention">@$1</span>');
    // Convert newlines to <br>
    formatted = formatted.replace(/\n/g, '<br>');
    return formatted;
  }

  getServiceTypeLabel(): string {
    const map: Record<string, string> = {
      online: 'A distance',
      in_person: 'En personne',
      both: 'En personne ou a distance',
    };
    return map[this.product()?.metadata?.service_type || ''] || 'A convenir';
  }

  getServiceAvailability(): string {
    return this.product()?.metadata?.availability || 'A convenir avec le prestataire';
  }

  getServiceDuration(): string {
    return this.product()?.metadata?.duration || '';
  }

  getServiceArea(): string {
    return this.product()?.metadata?.service_area || '';
  }

  getServiceExperience(): string {
    const years = this.product()?.metadata?.experience_years;
    if (!years) return '';
    return `${years} an${Number(years) > 1 ? 's' : ''} d'experience`;
  }

  getServicePriceTypeLabel(): string {
    const map: Record<string, string> = {
      fixed: 'Prix fixe',
      starting: 'A partir de',
      hourly: 'Tarif horaire',
      quote: 'Sur devis',
    };
    return map[this.product()?.metadata?.price_type || 'fixed'] || 'Prix fixe';
  }
}
