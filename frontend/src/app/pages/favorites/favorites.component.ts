import { Component, inject, OnInit, signal } from '@angular/core';
import { RouterLink } from '@angular/router';
import { DecimalPipe } from '@angular/common';
import { FavoriteService, FavoriteItem } from '../../core/services/favorite.service';
import { NotificationService } from '../../core/services/notification.service';
import { CartService } from '../../core/services/cart.service';

@Component({
  selector: 'app-favorites',
  standalone: true,
  imports: [RouterLink, DecimalPipe],
  templateUrl: './favorites.component.html',
  styleUrl: './favorites.component.scss',
})
export class FavoritesComponent implements OnInit {
  favService = inject(FavoriteService);
  private cartService = inject(CartService);
  private notify = inject(NotificationService);

  loading = signal(false);

  ngOnInit() {
    this.loading.set(true);
    this.favService.getFavorites().subscribe({ complete: () => this.loading.set(false) });
  }

  removeFavorite(item: FavoriteItem) {
    this.favService.toggleFavorite(item.product_id).subscribe({
      next: () => {
        this.notify.success('Retiré des favoris.');
        this.favService.getFavorites().subscribe();
      },
    });
  }

  addToCart(item: FavoriteItem) {
    this.cartService.addToCart(item.product_id).subscribe({
      next: () => this.notify.success('Ajouté au panier!'),
      error: () => this.notify.error('Erreur lors de l\'ajout au panier'),
    });
  }

  // ─── Media Helper ────────────────────────────────────────
  // Avant : ne regardait que product.video.thumbnail, donc tout produit
  // sans vidéo (l'immense majorité des annonces, en photos) retombait sur
  // le placeholder "image" gris au lieu de sa vraie photo. Même ordre de
  // priorité que marketplace.component.ts::getThumb() pour rester cohérent
  // avec le reste de l'app.
  getThumb(product: any): string | null {
    if (!product) return null;
    if (product.poster) return product.poster;
    if (product.poster_full_url) return product.poster_full_url;
    const v = product.video;
    if (v) {
      if (v.thumbnail) return v.thumbnail;
      if (v.thumbnail_url) return v.thumbnail_url;
    }
    if (product.images?.length) return product.images[0];
    if (product.image) return product.image;
    return null;
  }
}
