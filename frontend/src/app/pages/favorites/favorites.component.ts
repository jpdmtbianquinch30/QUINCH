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
  activeTab = signal<'all' | 'collections'>('all');

  ngOnInit() {
    this.loading.set(true);
    this.favService.getFavorites().subscribe({ complete: () => this.loading.set(false) });
    this.favService.getCollections().subscribe();
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
}
