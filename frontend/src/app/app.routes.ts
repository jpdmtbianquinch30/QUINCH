import { Routes } from '@angular/router';
import { guestGuard, adminGuard, authGuard } from './core/guards/auth.guard';

export const routes: Routes = [
  { path: '', redirectTo: 'feed', pathMatch: 'full' },

  // ─── Auth (public, redirige si deja connecte) ───────────────────────────
  {
    path: 'auth',
    canActivate: [guestGuard],
    children: [
      { path: 'login', loadComponent: () => import('./pages/auth/login/login.component').then(m => m.LoginComponent) },
      { path: 'register', loadComponent: () => import('./pages/auth/register/register.component').then(m => m.RegisterComponent) },
    ]
  },

  // ─── Onboarding ──────────────────────────────────────────────────────────
  {
    path: 'onboarding',
    canActivate: [authGuard],
    loadComponent: () => import('./pages/onboarding/onboarding.component').then(m => m.OnboardingComponent),
  },

  // ─── Pages publiques ─────────────────────────────────────────────────────
  { path: 'feed', loadComponent: () => import('./pages/feed/feed.component').then(m => m.FeedComponent) },
  { path: 'marketplace', loadComponent: () => import('./pages/marketplace/marketplace.component').then(m => m.MarketplaceComponent) },
  { path: 'product/:slug', loadComponent: () => import('./pages/product-detail/product-detail.component').then(m => m.ProductDetailComponent) },
  { path: 'seller/:username', loadComponent: () => import('./pages/seller-profile/seller-profile.component').then(m => m.SellerProfileComponent) },

  // ─── Pages necessitant un compte ─────────────────────────────────────────
  { path: 'sell', canActivate: [authGuard], loadComponent: () => import('./pages/sell/sell.component').then(m => m.SellComponent) },
  { path: 'cart', canActivate: [authGuard], loadComponent: () => import('./pages/cart/cart.component').then(m => m.CartComponent) },
  { path: 'messages', canActivate: [authGuard], loadComponent: () => import('./pages/messages/messages.component').then(m => m.MessagesComponent) },
  { path: 'favorites', canActivate: [authGuard], loadComponent: () => import('./pages/favorites/favorites.component').then(m => m.FavoritesComponent) },
  { path: 'notifications', canActivate: [authGuard], loadComponent: () => import('./pages/notifications/notifications.component').then(m => m.NotificationsComponent) },
  { path: 'transactions', canActivate: [authGuard], loadComponent: () => import('./pages/transactions/transactions.component').then(m => m.TransactionsComponent) },
  { path: 'transactions/:id/:outcome', canActivate: [authGuard], loadComponent: () => import('./pages/transaction-status/transaction-status.component').then(m => m.TransactionStatusComponent) },
  { path: 'profile', canActivate: [authGuard], loadComponent: () => import('./pages/profile/profile.component').then(m => m.ProfileComponent) },
  { path: 'profile/edit', canActivate: [authGuard], loadComponent: () => import('./pages/edit-profile/edit-profile.component').then(m => m.EditProfileComponent) },
  { path: 'settings', canActivate: [authGuard], loadComponent: () => import('./pages/settings/settings.component').then(m => m.SettingsComponent) },

  // ─── Panneau d'administration ────────────────────────────────────────────
  {
    path: 'admin',
    canActivate: [adminGuard],
    loadComponent: () => import('./pages/admin/admin-dashboard.component').then(m => m.AdminDashboardComponent),
  },

  { path: '**', redirectTo: 'feed' },
];