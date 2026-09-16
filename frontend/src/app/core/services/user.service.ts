import { Injectable } from '@angular/core';
import { Observable } from 'rxjs';
import { ApiService } from './api.service';

@Injectable({ providedIn: 'root' })
export class UserService {
  constructor(private api: ApiService) {}

  getProfile(): Observable<any> {
    return this.api.get('user/profile');
  }

  updateProfile(data: Record<string, any>): Observable<any> {
    return this.api.put('user/profile', data);
  }

  uploadAvatar(file: File): Observable<any> {
    const fd = new FormData();
    fd.append('avatar', file);
    return this.api.upload('user/upload-avatar', fd);
  }

  uploadCover(file: File): Observable<any> {
    const fd = new FormData();
    fd.append('cover', file);
    return this.api.upload('user/upload-cover', fd);
  }

    // ─── Changement de numéro de téléphone ────────────────────────────────
  // Deux étapes : mot de passe requis pour demander le changement, puis
  // OTP envoyé au NOUVEAU numéro pour confirmer qu'il appartient bien à
  // l'utilisateur avant que phone_number ne change réellement en base.
  requestPhoneChange(newPhoneNumber: string, currentPassword: string): Observable<any> {
    return this.api.post('user/phone/request-change', {
      new_phone_number: newPhoneNumber,
      current_password: currentPassword,
    });
  }

  confirmPhoneChange(otp: string): Observable<any> {
    return this.api.post('user/phone/confirm-change', { otp });
  }
}

