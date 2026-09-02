import { Component, inject, OnInit, signal, computed } from '@angular/core';
import { RouterLink } from '@angular/router';
import { DecimalPipe } from '@angular/common';
import { CartService, CartItem } from '../../core/services/cart.service';
import { NotificationService } from '../../core/services/notification.service';

@Component({
  selector: 'app-cart',
  standalone: true,
  imports: [RouterLink, DecimalPipe],
  templateUrl: './cart.component.html',
  styleUrl: './cart.component.scss',
})
export class CartComponent implements OnInit {
  cart = inject(CartService);
  private notify = inject(NotificationService);
  loading = signal(false);

  // Le panier est une liste d'envies : Wave/Orange Money ne gèrent qu'une
  // transaction = un produit, un paiement groupé multi-vendeurs n'est pas
  // possible avec ces passerelles. L'achat réel se fait donc article par
  // article, directement depuis la fiche produit (déjà fonctionnel et
  // testé — voir WavePurchaseTest côté backend).

  // Items with delivery fees
  itemsWithDeliveryFee = computed(() => {
    return this.cart.items().filter(item =>
      item.product.delivery_option === 'fixed' && (item.product.delivery_fee || 0) > 0
    );
  });

  // Items where delivery needs to be arranged
  itemsDeliveryContact = computed(() => {
    return this.cart.items().filter(item =>
      item.product.delivery_option !== 'fixed' || !(item.product.delivery_fee || 0)
    );
  });

  ngOnInit() {
    this.loading.set(true);
    this.cart.loadCart().subscribe({ complete: () => this.loading.set(false) });
  }

  getItemThumb(item: CartItem): string {
    if (item.product.poster) return item.product.poster;
    if (item.product.images && item.product.images.length > 0) return item.product.images[0];
    if (item.product.video?.thumbnail) return item.product.video.thumbnail;
    return '';
  }

  getDeliveryLabel(item: CartItem): string {
    if (item.product.delivery_option === 'fixed' && (item.product.delivery_fee || 0) > 0) {
      return `+${this.formatNum(item.product.delivery_fee!)} F`;
    }
    return 'A convenir';
  }

  formatNum(n: number): string {
    return n.toLocaleString('fr-FR');
  }

  updateQty(item: CartItem, qty: number) {
    if (qty < 1) return;
    this.cart.updateQuantity(item.id, qty).subscribe();
  }

  removeItem(item: CartItem) {
    this.cart.removeItem(item.id).subscribe({
      next: () => this.notify.success('Produit retire du panier.'),
    });
  }

  clearAll() {
    this.cart.clearCart().subscribe({
      next: () => this.notify.success('Panier vide.'),
    });
  }
}
