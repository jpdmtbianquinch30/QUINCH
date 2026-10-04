import { Component, inject, signal, OnInit, computed } from '@angular/core';
import { ActivatedRoute, Router, RouterLink } from '@angular/router';
import { DatePipe, DecimalPipe } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { ApiService } from '../../core/services/api.service';
import { AuthService } from '../../core/services/auth.service';
import { FollowService } from '../../core/services/follow.service';
import { ReviewService, ReviewStats } from '../../core/services/review.service';
import { NotificationService } from '../../core/services/notification.service';
import { ProductService } from '../../core/services/product.service';

type SellerTab = 'products' | 'reviews' | 'about' | 'policies';

@Component({
  selector: 'app-seller-profile',
  standalone: true,
  imports: [RouterLink, DecimalPipe, DatePipe, FormsModule],
  templateUrl: './seller-profile.component.html',
  styleUrl: './seller-profile.component.scss',
})
export class SellerProfileComponent implements OnInit {
  private route = inject(ActivatedRoute);
contactSending() {
throw new Error('Method not implemented.');
}
  private router = inject(Router);
  private api = inject(ApiService);
  auth = inject(AuthService);
  private followService = inject(FollowService);
  private reviewService = inject(ReviewService);
  private notif = inject(NotificationService);

  // Data
  loading = signal(true);
  profile = signal<any>(null);
  products = signal<any[]>([]);
  allProducts = signal<any[]>([]);
  reviews = signal<any[]>([]);
  reviewStats = signal<ReviewStats | null>(null);

  // Tabs & state
  activeTab = signal<SellerTab>('products');
  isFollowing = signal(false);
  followLoading = signal(false);

  // Products filter/sort
  productFilter = signal('all');
  productSort = 'newest';
  productSearch = '';
  currentPage = signal(1);
  totalPages = signal(1);
  totalProducts = signal(0);

  // Review filter
  reviewFilter = signal('all');

  // Reponse du vendeur a un avis (uniquement visible sur son propre profil)
  isOwnProfile = computed(() => !!this.auth.user() && this.auth.user()!.id === this.profile()?.user?.id);
  replyingToReviewId = signal<string | null>(null);
  replyText = '';
  submittingReply = signal(false);

  // Modals
  showShareModal = signal(false);
  showContactModal = signal(false);
  showReportModal = signal(false);
  showMoreMenu = signal(false);

  // Contact form
  contactMessage = '';

  // Computed
  trustPercent = computed(() => Math.round((this.profile()?.user?.trust_score || 0) * 100));
  featuredProducts = computed(() => this.allProducts().slice(0, 4));
  filteredReviews = computed(() => {
    const filter = this.reviewFilter();
    const all = this.reviews();
    if (filter === 'all') return all;
    if (filter === '5') return all.filter(r => r.rating === 5);
    if (filter === '4') return all.filter(r => r.rating >= 4);
    if (filter === 'recent') return [...all].sort((a, b) => new Date(b.created_at).getTime() - new Date(a.created_at).getTime());
    return all;
  });

  private username = '';

  ngOnInit() {
    this.username = this.route.snapshot.params['username'];
    if (this.username) {
      this.loadProfile(this.username);
      this.loadProducts(this.username);
    }
  }

  loadProfile(username: string) {
    this.api.get(`users/${username}/profile`).subscribe({
      next: (res: any) => {
        this.profile.set(res);
        this.isFollowing.set(res.is_following);
        this.loading.set(false);
        if (res.user?.id) {
          this.loadReviews(res.user.id);
        }
      },
      error: () => this.loading.set(false),
    });
  }

  loadProducts(username: string, page = 1) {
    const params: any = { page, per_page: 12, sort: this.productSort };
    if (this.productSearch) params.q = this.productSearch;

    this.api.get(`users/${username}/products`, params).subscribe({
      next: (res: any) => {
        const prods = res.data || [];
        this.products.set(prods);
        if (page === 1) this.allProducts.set(prods);
        this.totalPages.set(res.last_page || 1);
        this.totalProducts.set(res.total || prods.length);
        this.currentPage.set(res.current_page || 1);
      },
    });
  }

  loadReviews(userId: string) {
    this.reviewService.getSellerReviews(userId).subscribe({
      next: (res: any) => {
        this.reviews.set(res.reviews?.data || res.reviews || []);
        // Normalise : le serveur peut renvoyer des chaînes ("4.5") ou omettre des
        // champs ; un seul .toFixed() sur une chaîne faisait planter tout l'onglet Avis.
        const s: any = res.stats || {};
        this.reviewStats.set({
          average: Number(s.average) || 0,
          total: Number(s.total) || 0,
          distribution: s.distribution || {},
          avg_delivery: Number(s.avg_delivery) || 0,
          avg_communication: Number(s.avg_communication) || 0,
          avg_accuracy: Number(s.avg_accuracy) || 0,
        });
      },
      error: () => {
        this.reviews.set([]);
        this.reviewStats.set(null);
      },
    });
  }

  // ─── Tab Navigation ──────────────────────────────────
  switchTab(tab: SellerTab) {
    this.activeTab.set(tab);
    // Scroll to top of content area
    document.querySelector('.seller-content')?.scrollIntoView({ behavior: 'smooth' });
  }

  // ─── Follow / Unfollow ───────────────────────────────
  toggleFollow() {
    const userId = this.profile()?.user?.id;
    if (!userId || !this.auth.isAuthenticated()) {
      this.router.navigate(['/auth/login']);
      return;
    }
    this.followLoading.set(true);
    if (this.isFollowing()) {
      this.followService.unfollow(userId).subscribe({
        next: () => {
          this.isFollowing.set(false);
          this.followLoading.set(false);
          this.profile.update(p => p ? { ...p, stats: { ...p.stats, follower_count: Math.max(0, p.stats.follower_count - 1) } } : p);
        },
        error: () => this.followLoading.set(false),
      });
    } else {
      this.followService.follow(userId).subscribe({
        next: (res: any) => {
          this.isFollowing.set(true);
          this.followLoading.set(false);
          if (res.is_mutual) {
            this.notif.success('Vous êtes maintenant amis! Vous pouvez discuter dans Messages.');
          } else {
            this.notif.success('Abonné!');
          }
          this.profile.update(p => p ? { ...p, stats: { ...p.stats, follower_count: p.stats.follower_count + 1 } } : p);
        },
        error: (err: any) => {
          this.followLoading.set(false);
          // 422 = already following — sync state
          if (err.status === 422) {
            this.isFollowing.set(true);
          }
        },
      });
    }
  }

  // ─── Product Filter / Sort ───────────────────────────
  onSortChange() {
    this.loadProducts(this.username);
  }

  onSearchProducts() {
    this.loadProducts(this.username);
  }

  goToPage(page: number) {
    if (page >= 1 && page <= this.totalPages()) {
      this.loadProducts(this.username, page);
    }
  }

  getPageNumbers(): number[] {
    const total = this.totalPages();
    const current = this.currentPage();
    const pages: number[] = [];
    const start = Math.max(1, current - 2);
    const end = Math.min(total, current + 2);
    for (let i = start; i <= end; i++) pages.push(i);
    return pages;
  }

  // ─── Contact ─────────────────────────────────────────
  openContact() {
    if (!this.auth.isAuthenticated()) { this.router.navigate(['/auth/login']); return; }
    if (this.isOwnProfile()) {
      this.notif.info('Ceci est votre propre profil.');
      return;
    }
    this.showContactModal.set(true);
  }

  contactSending = signal(false);

  sendMessage() {
    if (!this.contactMessage.trim() || this.contactSending()) return;
    const sellerId = this.profile()?.user?.id;
    if (!sellerId) return;

    this.contactSending.set(true);
    this.api.post('conversations/start', {
      seller_id: sellerId,
      message: this.contactMessage.trim(),
    }).subscribe({
      next: () => {
        this.contactSending.set(false);
        this.showContactModal.set(false);
        this.contactMessage = '';
        this.notif.success('Message envoye!');
        this.router.navigate(['/messages']);
      },
      error: (err: any) => {
        this.contactSending.set(false);
        // On affiche la vraie raison renvoyée par le serveur (compte non
        // vérifié, trop de messages, etc.) au lieu d'un message générique.
        this.notif.error(err?.error?.message || 'Erreur lors de l\'envoi.');
      },
    });
  }

  sendQuickMessage(msg: string) {
    this.contactMessage = msg;
    this.sendMessage();
  }

  // ─── Share ───────────────────────────────────────────
  openShare() {
    this.showShareModal.set(true);
  }

  async shareVia(platform: string) {
    const url = `${window.location.origin}/seller/${this.profile()?.user?.username}`;
    const text = `Decouvrez ${this.profile()?.user?.full_name} sur QUINCH - ${this.trustPercent()}% de confiance`;

    switch (platform) {
      case 'whatsapp':
        window.open(`https://wa.me/?text=${encodeURIComponent(text + '\n' + url)}`, '_blank');
        break;
      case 'facebook':
        window.open(`https://www.facebook.com/sharer/sharer.php?u=${encodeURIComponent(url)}`, '_blank');
        break;
      case 'copy':
        try {
          await navigator.clipboard.writeText(url);
          this.notif.success('Lien copie!');
        } catch { this.notif.error('Erreur de copie'); }
        break;
      case 'native':
        if (navigator.share) {
          try { await navigator.share({ title: text, url }); } catch { /* cancelled */ }
        }
        break;
    }
    this.showShareModal.set(false);
  }

  // ─── Report ──────────────────────────────────────────
  reportProfile() {
    this.showMoreMenu.set(false);
    if (!this.auth.isAuthenticated()) { this.router.navigate(['/auth/login']); return; }
    if (this.isOwnProfile()) {
      this.notif.info('Vous ne pouvez pas vous signaler vous-même.');
      return;
    }
    this.reportReason = '';
    this.reportDescription = '';
    this.showReportModal.set(true);
  }

  reportReasons = [
    { id: 'harassment', label: 'Harcèlement' },
    { id: 'spam', label: 'Spam' },
    { id: 'inappropriate_content', label: 'Contenu inapproprié' },
    { id: 'fraud', label: 'Fraude / arnaque' },
    { id: 'impersonation', label: 'Usurpation d\'identité' },
    { id: 'other', label: 'Autre' },
  ];
  reportReason = '';
  reportDescription = '';
  reportSending = signal(false);

  submitReport() {
    const userId = this.profile()?.user?.id;
    if (!userId || !this.reportReason || this.reportSending()) return;

    this.reportSending.set(true);
    this.api.post(`users/${userId}/report`, {
      reason: this.reportReason,
      description: this.reportDescription.trim() || null,
    }).subscribe({
      next: () => {
        this.reportSending.set(false);
        this.showReportModal.set(false);
        this.notif.success('Signalement envoyé. Merci, notre équipe va l\'examiner.');
      },
      error: (err: any) => {
        this.reportSending.set(false);
        this.notif.error(err?.error?.message || 'Impossible d\'envoyer le signalement.');
      },
    });
  }

  // ─── Seller Review Reply ─────────────────────────────
  startReply(reviewId: string) {
    this.replyingToReviewId.set(reviewId);
    this.replyText = '';
  }

  cancelReply() {
    this.replyingToReviewId.set(null);
    this.replyText = '';
  }

  submitReply(reviewId: string) {
    if (!this.replyText.trim()) return;
    this.submittingReply.set(true);
    this.reviewService.respondToReview(reviewId, this.replyText.trim()).subscribe({
      next: (res: any) => {
        this.reviews.update(list => list.map(r => r.id === reviewId ? { ...r, ...res.review } : r));
        this.replyingToReviewId.set(null);
        this.replyText = '';
        this.submittingReply.set(false);
        this.notif.success('Reponse publiee!');
      },
      error: () => {
        this.submittingReply.set(false);
        this.notif.error('Erreur lors de la publication de la reponse.');
      },
    });
  }

  // ─── Review Helpers ──────────────────────────────────
  getStarArray(rating: number): number[] {
    return Array.from({ length: 5 }, (_, i) => i < Math.round(rating) ? 1 : 0);
  }

  getDistributionPercent(count: number): number {
    const total = this.reviewStats()?.total || 1;
    return Math.round((count / total) * 100);
  }

  // ─── Quick Messages ──────────────────────────────────
  quickMessages = [
    'Bonjour, je suis interesse par vos produits',
    'Est-ce que le produit est toujours disponible?',
    'Quel est votre meilleur prix?',
    'Quels sont vos delais de livraison?',
  ];

  // ─── Policies Data ──────────────────────────────────
  // Deduit des vrais produits publies par ce vendeur (payment_methods par
  // produit), au lieu d'une liste codee en dur identique pour tout le
  // monde. Mappe vers ProductService.ALL_PAYMENT_METHODS pour rester
  // coherent avec ce qui est reellement selectionnable a la publication
  // (et donc avec ce que PaymentGatewayFactory sait traiter cote backend).
  acceptedPaymentMethods = computed(() => {
    const ids = new Set<string>();
    for (const p of this.allProducts()) {
      const methods: string[] = Array.isArray(p.payment_methods) ? p.payment_methods : [];
      methods.forEach(m => ids.add(m));
    }
    return ProductService.ALL_PAYMENT_METHODS.filter(m => ids.has(m.id));
  });
}
