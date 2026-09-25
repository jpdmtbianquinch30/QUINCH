import { Component, computed, inject, OnInit, OnDestroy, signal, effect } from '@angular/core';
import { RouterOutlet, RouterLink, RouterLinkActive, Router, NavigationEnd } from '@angular/router';
import { AuthService } from './core/services/auth.service';
import { CartService } from './core/services/cart.service';
import { NotificationService } from './core/services/notification.service';
import { ChatService } from './core/services/chat.service';
import { FavoriteService } from './core/services/favorite.service';
import { ThemeService } from './core/services/theme.service';
import { ToastComponent } from './shared/toast/toast.component';
import { filter, map } from 'rxjs';
import { toSignal } from '@angular/core/rxjs-interop';

@Component({
  selector: 'app-root',
  imports: [RouterOutlet, RouterLink, RouterLinkActive, ToastComponent],
  templateUrl: './app.html',
  styleUrl: './app.scss'
})
export class App implements OnInit, OnDestroy {
  auth = inject(AuthService);
  cart = inject(CartService);
  notif = inject(NotificationService);
  chat = inject(ChatService);
  fav = inject(FavoriteService);
  theme = inject(ThemeService);
  private router = inject(Router);
  private countsInterval: any = null;

  constructor() {
    // Reagit a la connexion/deconnexion — pas seulement au chargement initial.
    // Avant ce fix, se connecter sans recharger la page (SPA, ce qui est le cas
    // normal) laissait panier/notifs/messages a 0 jusqu'au prochain F5, et rien
    // ne rafraichissait plus ces compteurs ensuite tant qu'on restait sur l'app.
    effect(() => {
      if (this.auth.isAuthenticated()) {
        this.refreshCounts();
        this.startCountsPolling();
      } else {
        this.stopCountsPolling();
      }
    });
  }

  private currentUrl = toSignal(
    this.router.events.pipe(
      filter(e => e instanceof NavigationEnd),
      map(e => (e as NavigationEnd).url)
    ),
    { initialValue: '' }
  );

  showSidebar = computed(() => {
    const url = this.currentUrl();
    const hiddenRoutes = ['/auth/', '/onboarding', '/videos'];
    return !hiddenRoutes.some(r => url.includes(r));
  });

    mobileMenuOpen = signal(false);

  toggleMobileMenu() {
    this.mobileMenuOpen.update(v => !v);
  }

  closeMobileMenu() {
    this.mobileMenuOpen.set(false);
  }

  isFullscreen = computed(() => {
    const url = this.currentUrl();
    // /feed est maintenant une grille normale (topbar, sidebar filtres,
    // navigation visible) — seul /videos reprend le plein écran immersif
    // que /feed avait avant le redesign.
    return url.startsWith('/videos') || url.startsWith('/messages');
  });

  isPremiumActive = computed(() => {
    const user = this.auth.user();
    if (!user?.is_premium) return false;
    if (!user.premium_expires_at) return false;
    return new Date(user.premium_expires_at) > new Date();
  });

  /** Check if the sidebar "Produits" or "Services" link is active based on current URL query params */
  isActiveType(type: string): boolean {
    const url = this.currentUrl();
    return url.includes('/marketplace') && url.includes(`type=${type}`);
  }

    ngOnInit() {
    // Referme le tiroir mobile à chaque changement de route
    this.router.events.pipe(filter(e => e instanceof NavigationEnd)).subscribe(() => {
      this.mobileMenuOpen.set(false);
    });

    // Listen for welcome notification
    window.addEventListener('quinch:welcome', ((event: CustomEvent) => {
      this.notif.info(event.detail);
    }) as EventListener);
  }

  ngOnDestroy() {
    this.stopCountsPolling();
  }

  /** Panier, notifications non lues, conversations (→ chat.unreadTotal). Favoris inclus pour cohérence. */
  private refreshCounts() {
    this.cart.getCount().subscribe();
    this.notif.getUnreadCount().subscribe();
    this.chat.getConversations().subscribe();
    this.fav.getCount().subscribe();
  }

  private startCountsPolling() {
    if (this.countsInterval) return; // deja actif, evite le doublon
    this.countsInterval = setInterval(() => {
      // Inutile d'interroger le serveur si l'onglet est en arriere-plan.
      if (document.visibilityState === 'hidden') return;
      this.refreshCounts();
    }, 25000);
  }

  private stopCountsPolling() {
    if (this.countsInterval) {
      clearInterval(this.countsInterval);
      this.countsInterval = null;
    }
  }
}
