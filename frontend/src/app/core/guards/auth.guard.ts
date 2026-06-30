import { inject } from '@angular/core';
import { CanActivateFn, Router } from '@angular/router';
import { AuthService } from '../services/auth.service';

export const authGuard: CanActivateFn = () => {
  const auth = inject(AuthService);
  const router = inject(Router);

  if (auth.isAuthenticated()) {
    return true;
  }

  return router.createUrlTree(['/auth/login']);
};

export const guestGuard: CanActivateFn = () => {
  const auth = inject(AuthService);
  const router = inject(Router);

  // Double-check: if signal says authenticated but localStorage is empty, force logout
  if (auth.isAuthenticated() && !localStorage.getItem('quinch_token')) {
    auth.forceLogout();
  }

  if (!auth.isAuthenticated()) {
    return true;
  }

  return router.createUrlTree(['/feed']);
};

export const adminGuard: CanActivateFn = () => {
  const auth = inject(AuthService);
  const router = inject(Router);

  if (auth.isAuthenticated() && auth.isAdmin()) {
    return true;
  }

  return router.createUrlTree(['/feed']);
};

export const onboardingGuard: CanActivateFn = () => {
  const auth = inject(AuthService);
  const router = inject(Router);

  if (auth.isAuthenticated()) {
    const user = auth.user();
    if (user && !user.onboarding_completed) {
      return router.createUrlTree(['/onboarding']);
    }
    return true;
  }
  return router.createUrlTree(['/auth/login']);
};
