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
        // Don't redirect if already on auth pages or if this is the login/register request itself
        const isAuthRequest = req.url.includes('auth/login') || req.url.includes('auth/register');
        if (!isAuthRequest) {
          auth.forceLogout(); // Clear both signals AND localStorage
          router.navigate(['/auth/login']);
        }
      }
      return throwError(() => error);
    })
  );
};
