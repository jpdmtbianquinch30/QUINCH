import { Component, computed, inject, OnInit, signal } from '@angular/core';
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
export class App implements OnInit {
  auth = inject(AuthService);
  cart = inject(CartService);
  notif = inject(NotificationService);
  chat = inject(ChatService);
  fav = inject(FavoriteService);
  theme = inject(ThemeService);
  private router = inject(Router);

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

  /** Check if the sidebar "Produits" or "Services" link is active based on current URL query params */
  isActiveType(type: string): boolean {
    const url = this.currentUrl();
    return url.includes('/marketplace') && url.includes(`type=${type}`);
  }

    ngOnInit() {
    // Load all counts immediately when authenticated
    if (this.auth.isAuthenticated()) {
      this.cart.getCount().subscribe();
      this.notif.getUnreadCount().subscribe();
      this.chat.getConversations().subscribe();
      this.fav.getCount().subscribe();
    }

    // Referme le tiroir mobile à chaque changement de route
    this.router.events.pipe(filter(e => e instanceof NavigationEnd)).subscribe(() => {
      this.mobileMenuOpen.set(false);
    });

    // Listen for welcome notification
    window.addEventListener('quinch:welcome', ((event: CustomEvent) => {
      this.notif.info(event.detail);
    }) as EventListener);
  }
}
