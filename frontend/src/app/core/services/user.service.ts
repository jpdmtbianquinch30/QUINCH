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

  // ─── Numéro de téléphone FACULTATIF ───────────────────────────────────
  // Information de profil uniquement : ni connexion ni récupération de compte
  // (c'est l'e-mail). `null` supprime le numéro.
  updatePhone(phoneNumber: string | null): Observable<any> {
    return this.api.put('user/phone', { phone_number: phoneNumber });
  }
}

