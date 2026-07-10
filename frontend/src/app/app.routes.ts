import { Routes } from '@angular/router';
import { guestGuard, adminGuard } from './core/guards/auth.guard';

/**
 * QUINCH V1 — Ce frontend Angular ne sert plus que de panneau d'administration.
 * Le public (acheteurs/vendeurs) utilise exclusivement l'app Flutter.
 *
 * Les pages "grand public" (feed, marketplace, sell, cart, messages,
 * favorites, notifications, transactions, profile, settings, seller-profile,
 * product-detail, onboarding, register) existent toujours dans
 * `src/app/pages/` mais ne sont plus routées : elles dupliquaient l'app
 * Flutter et ne sont plus maintenues côté web. On les garde au cas où un
 * besoin de "version web publique" reviendrait plus tard, mais elles ne
 * doivent pas être exposées tant que ce n'est pas décidé et retesté.
 */
export const routes: Routes = [
  { path: '', redirectTo: 'auth/login', pathMatch: 'full' },

  // Connexion admin (seule page publique de cette app)
  {
    path: 'auth',
    canActivate: [guestGuard],
    children: [
      { path: 'login', loadComponent: () => import('./pages/auth/login/login.component').then(m => m.LoginComponent) },
    ]
  },

  // Panneau d'administration
  {
    path: 'admin',
    canActivate: [adminGuard],
    loadComponent: () => import('./pages/admin/admin-dashboard.component').then(m => m.AdminDashboardComponent),
  },

  // Tout le reste redirige vers la connexion admin
  { path: '**', redirectTo: 'auth/login' },
];
