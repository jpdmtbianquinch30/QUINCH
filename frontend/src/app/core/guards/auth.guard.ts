import { inject } from '@angular/core';
import { CanActivateFn, Router } from '@angular/router';
import { AuthService } from '../services/auth.service';

export const authGuard: CanActivateFn = () => {
  const auth = inject(AuthService);
  const router = inject(Router);

  if (!auth.isAuthenticated()) {
    return router.createUrlTree(['/auth/login']);
  }

  // C'est le garde utilisé sur la quasi-totalité des routes authentifiées
  // (sell, cart, messages, premium, transactions, profile, settings...).
  // onboardingGuard vérifiait déjà phone_verified mais n'était en réalité
  // câblé sur AUCUNE route — un utilisateur non vérifié pouvait donc
  // atteindre n'importe quelle page en y accédant directement (ex. bouton
  // "retour" du navigateur depuis l'écran OTP).
  const user = auth.user();
  if (user && !user.phone_verified) {
    return router.createUrlTree(['/auth/verify-otp']);
  }

  return true;
};

export const guestGuard: CanActivateFn = () => {
  const auth = inject(AuthService);
  const router = inject(Router);

  if (auth.isAuthenticated() && !localStorage.getItem('quinch_token')) {
    auth.forceLogout();
  }

  if (!auth.isAuthenticated()) {
    return true;
  }

  if (auth.isAdmin()) {
    return router.createUrlTree(['/admin']);
  }

  const user = auth.user();
  // Vérifié en premier : sans ce check, un utilisateur inscrit mais pas
  // encore vérifié pouvait revenir sur /auth/login ou /auth/register (ex.
  // bouton "retour" du navigateur) et se faire rediriger direct vers
  // /onboarding ou /feed, contournant complètement l'écran OTP.
  if (user && !user.phone_verified) {
    return router.createUrlTree(['/auth/verify-otp']);
  }
  if (user && !user.onboarding_completed) {
    return router.createUrlTree(['/onboarding']);
  }

  return router.createUrlTree(['/feed']);
};

export const adminGuard: CanActivateFn = () => {
  const auth = inject(AuthService);
  const router = inject(Router);

  if (auth.isAuthenticated() && auth.isAdmin()) {
    return true;
  }

  return router.createUrlTree(['/auth/login']);
};

export const onboardingGuard: CanActivateFn = () => {
  const auth = inject(AuthService);
  const router = inject(Router);

  if (auth.isAuthenticated()) {
    const user = auth.user();
    // Même raison que dans guestGuard : le téléphone doit être vérifié
    // avant l'onboarding, sinon phone_verified reste false à vie pour
    // quiconque contourne l'écran OTP par navigation directe.
    if (user && !user.phone_verified) {
      return router.createUrlTree(['/auth/verify-otp']);
    }
    if (user && !user.onboarding_completed) {
      return router.createUrlTree(['/onboarding']);
    }
    return true;
  }
  return router.createUrlTree(['/auth/login']);
};
