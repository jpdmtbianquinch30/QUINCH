import { Injectable, inject } from '@angular/core';
import { Observable } from 'rxjs';
import { ApiService } from './api.service';
import { NotificationService } from './notification.service';

export interface ShareOption {
  id: string;
  name: string;
  icon: string;
  url?: string;
}

@Injectable({ providedIn: 'root' })
export class ShareService {
  private api = inject(ApiService);
  private notify = inject(NotificationService);

  trackShare(productId: string, platform: string): Observable<any> {
    return this.api.post<any>('shares/track', { product_id: productId, platform });
  }

  getShareData(slug: string): Observable<any> {
    return this.api.get<any>(`products/${slug}/share-data`);
  }

  async shareProduct(product: { title: string; slug: string; price: number }) {
    const url = `${window.location.origin}/product/${product.slug}`;
    const text = `${product.title} - ${product.price} F CFA sur QUINCH`;

    // Try native Web Share API
    if (navigator.share) {
      try {
        await navigator.share({ title: product.title, text, url });
        this.notify.success('Partagé avec succès!');
        return;
      } catch (e) { /* User cancelled or not supported */ }
    }

    // Fallback: copy to clipboard
    try {
      await navigator.clipboard.writeText(`${text}\n${url}`);
      this.notify.success('Lien copié dans le presse-papier!');
    } catch {
      this.notify.error('Impossible de copier le lien.');
    }
  }

  shareViaWhatsApp(product: { title: string; slug: string; price: number }) {
    const url = `${window.location.origin}/product/${product.slug}`;
    window.open(`https://wa.me/?text=${encodeURIComponent(`${product.title} - ${product.price} F\n${url}`)}`, '_blank');
  }

  shareViaFacebook(slug: string) {
    const url = `${window.location.origin}/product/${slug}`;
    window.open(`https://www.facebook.com/sharer/sharer.php?u=${encodeURIComponent(url)}`, '_blank');
  }

  copyLink(slug: string) {
    const url = `${window.location.origin}/product/${slug}`;
    navigator.clipboard.writeText(url).then(
      () => this.notify.success('Lien copié!'),
      () => this.notify.error('Erreur lors de la copie')
    );
  }
}
