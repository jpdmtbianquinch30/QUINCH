import { Injectable, inject } from '@angular/core';
import { Observable } from 'rxjs';
import { ApiService } from './api.service';

/** Informations légales publiques (GET /api/v1/legal/info), renseignées dans le .env du serveur. */
export interface LegalInfo {
  publisher: {
    name: string;
    status: string;
    address: string;
    registration: string;
    director: string;
  };
  cdp_receipt: string;
  contact_email: string;
  privacy_email: string;
  hosting: { provider: string; location: string };
  versions: { terms: string; privacy: string };
  retention: { anonymized_content_days: number; audit_logs_days: number };
}

@Injectable({ providedIn: 'root' })
export class LegalService {
  private api = inject(ApiService);

  getInfo(): Observable<LegalInfo> {
    return this.api.get<LegalInfo>('legal/info');
  }
}
