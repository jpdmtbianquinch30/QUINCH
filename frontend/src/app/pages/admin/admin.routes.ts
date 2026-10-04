import { Routes } from '@angular/router';
import { AdminShellComponent } from './admin-shell.component';

export const ADMIN_ROUTES: Routes = [
  {
    path: '',
    component: AdminShellComponent,
    children: [
      { path: '', pathMatch: 'full', redirectTo: 'dashboard' },
      { path: 'dashboard', loadComponent: () => import('./pages/dashboard.component').then(m => m.AdminDashboardPage) },
      { path: 'inbox', loadComponent: () => import('./pages/inbox.component').then(m => m.AdminInboxPage) },
      { path: 'moderation', loadComponent: () => import('./pages/moderation.component').then(m => m.AdminModerationPage) },
      { path: 'products', loadComponent: () => import('./pages/products.component').then(m => m.AdminProductsPage) },
      { path: 'users', loadComponent: () => import('./pages/users.component').then(m => m.AdminUsersPage) },
      { path: 'transactions', loadComponent: () => import('./pages/transactions.component').then(m => m.AdminTransactionsPage) },
      { path: 'security', loadComponent: () => import('./pages/security.component').then(m => m.AdminSecurityPage) },
      { path: 'categories', loadComponent: () => import('./pages/categories.component').then(m => m.AdminCategoriesPage) },
      { path: 'notifications', loadComponent: () => import('./pages/notifications.component').then(m => m.AdminNotificationsPage) },
      { path: 'settings', loadComponent: () => import('./pages/settings.component').then(m => m.AdminSettingsPage) },
      { path: 'team', loadComponent: () => import('./pages/team.component').then(m => m.AdminTeamPage) },
    ],
  },
];
