import { HttpInterceptorFn } from '@angular/common/http';
import { catchError, throwError } from 'rxjs';
import { inject } from '@angular/core';
import { Router } from '@angular/router';
import { AuthService } from '../services/auth.service';

export const errorInterceptor: HttpInterceptorFn = (req, next) => {
  const router = inject(Router);
  const auth = inject(AuthService);

  return next(req).pipe(
    catchError(error => {
            if (error.status === 401) {
        // Don't redirect if already on auth pages, if this is the
        // login/register request itself, or if it's a silent background
        // fetch sur une page de retour post-paiement (auth/me au boot,
        // lecture d'une transaction sur /transactions/:id/success ou
        // /error). Un hoquet réseau isolé sur ces appels ne doit pas
        // déconnecter une session par ailleurs valide (token toujours dans
        // localStorage) - ces pages gèrent déjà leur propre échec
        // silencieusement (ex: transaction-status affiche juste un état
        // "chargement" figé plutôt que de planter).
        const isAuthRequest = req.url.includes('auth/login') || req.url.includes('auth/register');
        const isSilentRefresh = req.url.includes('auth/me');
        const isPaymentReturnFetch = req.method === 'GET' && /\/transactions\/[^/]+$/.test(req.url);
        if (!isAuthRequest && !isSilentRefresh && !isPaymentReturnFetch) {
          auth.forceLogout();
          router.navigate(['/auth/login']);
        }
      }

      // Compte banni ou suspendu en cours de session : le backend coupe l'accès
      // (EnsureAccountActive). On déconnecte proprement au lieu d'afficher des erreurs
      // génériques sur chaque écran.
      const code = error.error?.error;
      if (error.status === 403 && (code === 'account_banned' || code === 'account_suspended')
          && !router.url.startsWith('/auth/') && auth.isAuthenticated()) {
        auth.forceLogout();
        router.navigate(['/auth/login']);
      }

      return throwError(() => error);
    })
  );
};
