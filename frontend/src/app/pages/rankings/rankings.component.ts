import { Component, OnDestroy, OnInit, computed, inject, signal } from '@angular/core';
import { Router, RouterLink } from '@angular/router';
import { DecimalPipe } from '@angular/common';
import {
  RankingService,
  RankingKind,
  RankingUserEntry,
  RankingProductEntry,
} from '../../core/services/ranking.service';
import { AuthService } from '../../core/services/auth.service';
import { NotificationService } from '../../core/services/notification.service';

@Component({
  selector: 'app-rankings',
  standalone: true,
  imports: [RouterLink, DecimalPipe],
  templateUrl: './rankings.component.html',
  styleUrl: './rankings.component.scss',
})
export class RankingsComponent implements OnInit, OnDestroy {
  private ranking = inject(RankingService);
  private auth = inject(AuthService);
  private notify = inject(NotificationService);
  private router = inject(Router);

  // ─── Premium ────────────────────────────────────────────────────────────
  // Meme regle que app.ts (isPremiumActive) : is_premium seul ne suffit pas,
  // l'abonnement peut etre expire.
  isPremiumActive = computed(() => {
    const user = this.auth.user();
    if (!user?.is_premium) return false;
    if (!user.premium_expires_at) return false;
    return new Date(user.premium_expires_at) > new Date();
  });

  // ─── Etat ecran ─────────────────────────────────────────────────────────
  loadingPrefs = signal(true);
  optedIn = signal(false);
  anonymous = signal(false);

  activeTab = signal<RankingKind>('sellers');
  month = signal<string | null>(null);

  sellers = signal<RankingUserEntry[]>([]);
  buyers = signal<RankingUserEntry[]>([]);
  products = signal<RankingProductEntry[]>([]);
  profiles = signal<RankingUserEntry[]>([]);

  loadingRanking = signal(false);
  rankingError = signal<string | null>(null);

  // ─── Modale "s'ajouter au classement" ───────────────────────────────────
  showJoinModal = signal(false);
  joinAnonymous = signal(false);
  savingJoin = signal(false);

  private pollInterval?: ReturnType<typeof setInterval>;

  tabs: { key: RankingKind; label: string; icon: string }[] = [
    { key: 'sellers', label: 'Meilleurs vendeurs', icon: 'storefront' },
    { key: 'buyers', label: 'Meilleurs acheteurs', icon: 'shopping_bag' },
    { key: 'products', label: 'Produits les + vus', icon: 'visibility' },
    { key: 'profiles', label: 'Profils les + visités', icon: 'person_search' },
  ];

  currentUsername = computed(() => this.auth.user()?.username);

  ngOnInit() {
    if (!this.isPremiumActive()) {
      // Vue verrouillee : inutile d'appeler les endpoints de classement.
      this.loadingPrefs.set(false);
      return;
    }

    this.ranking.getPreferences().subscribe({
      next: (prefs) => {
        this.optedIn.set(prefs.ranking_opt_in);
        this.anonymous.set(prefs.ranking_anonymous);
        this.joinAnonymous.set(prefs.ranking_anonymous);
        this.loadingPrefs.set(false);
        this.loadActiveRanking();
        this.startPolling();
      },
      error: () => {
        this.loadingPrefs.set(false);
        this.rankingError.set("Impossible de charger vos préférences de classement.");
      },
    });
  }

  ngOnDestroy() {
    this.stopPolling();
  }

  private startPolling() {
    // Les classements evoluent avec l'activite des autres utilisateurs
    // (ventes, achats, vues) : on repolle l'onglet actif toutes les 20s pour
    // que le rang se mette a jour tout seul, sans que l'utilisateur ait a
    // rafraichir la page a chaque fois qu'il est depasse.
    this.pollInterval = setInterval(() => {
      if (!document.hidden) this.loadActiveRanking(true);
    }, 20000);
  }

  private stopPolling() {
    if (this.pollInterval) clearInterval(this.pollInterval);
  }

  selectTab(tab: RankingKind) {
    if (this.activeTab() === tab) return;
    this.activeTab.set(tab);
    this.loadActiveRanking();
  }

  private loadActiveRanking(silent = false) {
    const tab = this.activeTab();
    if (!silent) {
      this.loadingRanking.set(true);
      this.rankingError.set(null);
    }

    const done = () => this.loadingRanking.set(false);
    const fail = () => {
      done();
      if (!silent) this.rankingError.set("Impossible de charger ce classement pour le moment.");
    };

    switch (tab) {
      case 'sellers':
        this.ranking.getSellers().subscribe({
          next: (res) => { this.sellers.set(res.ranking); this.month.set(res.month); done(); },
          error: fail,
        });
        break;
      case 'buyers':
        this.ranking.getBuyers().subscribe({
          next: (res) => { this.buyers.set(res.ranking); this.month.set(res.month); done(); },
          error: fail,
        });
        break;
      case 'products':
        this.ranking.getProducts().subscribe({
          next: (res) => { this.products.set(res.ranking); done(); },
          error: fail,
        });
        break;
      case 'profiles':
        this.ranking.getProfiles().subscribe({
          next: (res) => { this.profiles.set(res.ranking); done(); },
          error: fail,
        });
        break;
    }
  }

  goToPremium(): void {
    this.router.navigate(['/premium']);
  }

  // ─── Rejoindre / quitter le classement ──────────────────────────────────

  openJoinModal() {
    this.joinAnonymous.set(this.anonymous());
    this.showJoinModal.set(true);
  }

  closeJoinModal() {
    if (this.savingJoin()) return;
    this.showJoinModal.set(false);
  }

  confirmJoin() {
    this.savingJoin.set(true);
    this.ranking.updatePreferences({ opt_in: true, anonymous: this.joinAnonymous() }).subscribe({
      next: (res) => {
        this.optedIn.set(res.ranking_opt_in);
        this.anonymous.set(res.ranking_anonymous);
        this.savingJoin.set(false);
        this.showJoinModal.set(false);
        this.notify.success('Vous participez désormais aux classements !');
        // On recharge tout de suite pour que l'utilisateur se voie apparaître.
        this.loadActiveRanking();
      },
      error: () => {
        this.savingJoin.set(false);
        this.notify.error("Impossible de vous ajouter au classement pour le moment.");
      },
    });
  }

  leaveRanking() {
    this.ranking.updatePreferences({ opt_in: false }).subscribe({
      next: (res) => {
        this.optedIn.set(res.ranking_opt_in);
        this.notify.success('Vous ne figurez plus dans les classements.');
        this.loadActiveRanking();
      },
      error: () => this.notify.error('Action impossible pour le moment.'),
    });
  }

  toggleAnonymous(value: boolean) {
    const previous = this.anonymous();
    this.anonymous.set(value);
    this.ranking.updatePreferences({ opt_in: true, anonymous: value }).subscribe({
      next: () => this.notify.success(value ? 'Vous apparaîtrez de façon anonyme.' : 'Votre nom sera affiché dans les classements.'),
      error: () => {
        this.anonymous.set(previous);
        this.notify.error('Action impossible pour le moment.');
      },
    });
  }

  // ─── Aide d'affichage ────────────────────────────────────────────────────

  rankMedal(rank: number): string | null {
    if (rank === 1) return 'gold';
    if (rank === 2) return 'silver';
    if (rank === 3) return 'bronze';
    return null;
  }

  isCurrentUser(entry: RankingUserEntry): boolean {
    return !entry.anonymous && !!entry.username && entry.username === this.currentUsername();
  }

  criteriaText(): string {
    switch (this.activeTab()) {
      case 'sellers':
        return 'Classement basé sur le montant total des ventes confirmées ce mois-ci.';
      case 'buyers':
        return "Classement basé sur le montant total des achats confirmés ce mois-ci.";
      case 'products':
        return 'Classement basé sur le nombre de vues du produit (le vendeur doit être Premium et participer).';
      case 'profiles':
        return 'Classement basé sur le nombre de visites du profil.';
    }
  }
}
