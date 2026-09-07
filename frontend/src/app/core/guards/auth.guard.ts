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
  //
  // IMPORTANT : ce garde ne doit JAMAIS être posé sur la route
  // /auth/verify-otp elle-même (utiliser otpGuard ci-dessus à la place) —
  // sinon un utilisateur non vérifié qui arrive sur cette route se fait
  // rediriger... vers cette même route, en boucle infinie (page qui charge
  // à l'infini / navigateur qui gèle).
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

// Garde dédié à /auth/verify-otp uniquement : vérifie juste que
// l'utilisateur est connecté (le token est émis dès /auth/register, avant
// même la vérification du téléphone). Ne vérifie PAS phone_verified, sinon
// on obtient une redirection de cette route vers elle-même (boucle infinie).
export const otpGuard: CanActivateFn = () => {
  const auth = inject(AuthService);
  const router = inject(Router);

  if (!auth.isAuthenticated()) {
    return router.createUrlTree(['/auth/login']);
  }

  return true;
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
