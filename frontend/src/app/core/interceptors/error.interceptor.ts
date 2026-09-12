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
        const isAuthRequest = req.url.includes('auth/login') || req.url.includes('auth/register');
        const isSilentRefresh = req.url.includes('auth/me');
        if (!isAuthRequest && !isSilentRefresh) {
          auth.forceLogout();
          router.navigate(['/auth/login']);
        }
      }
      return throwError(() => error);
    })
  );
};
