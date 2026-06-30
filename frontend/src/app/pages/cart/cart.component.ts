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
  checkoutMode = signal(false);
  selectedPayment = signal('');

  // Master list of all payment methods
  allPaymentMethods = [
    { id: 'orange_money', name: 'Orange Money', desc: 'Paiement mobile', icon: 'phone_android' },
    { id: 'wave', name: 'Wave', desc: 'Transfert rapide', icon: 'waves' },
    { id: 'free_money', name: 'Free Money', desc: 'Paiement mobile', icon: 'smartphone' },
    { id: 'cash_delivery', name: 'Paiement a la livraison', desc: 'Especes', icon: 'local_shipping' },
    { id: 'cash_hand', name: 'Especes (en main propre)', desc: 'Paiement direct', icon: 'payments' },
    { id: 'bank_transfer', name: 'Virement bancaire', desc: 'Transfert bancaire', icon: 'account_balance' },
  ];

  // Compute common payment methods across all cart items
  commonPaymentMethods = computed(() => {
    const items = this.cart.items();
    if (items.length === 0) return [];

    // Get payment methods for each product
    const methodSets = items
      .map(item => item.product.payment_methods || [])
      .filter(methods => methods.length > 0);

    if (methodSets.length === 0) return [];

    // Find intersection of all sets
    let common = methodSets[0];
    for (let i = 1; i < methodSets.length; i++) {
      common = common.filter(m => methodSets[i].includes(m));
    }

    return this.allPaymentMethods.filter(m => common.includes(m.id));
  });

  // Check if any items have no payment methods set
  hasItemsWithoutPayment = computed(() => {
    return this.cart.items().some(item => !item.product.payment_methods || item.product.payment_methods.length === 0);
  });

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

  startCheckout() {
    if (this.commonPaymentMethods().length > 0) {
      this.selectedPayment.set(this.commonPaymentMethods()[0].id);
    }
    this.checkoutMode.set(true);
  }

  processPayment() {
    if (!this.selectedPayment()) {
      this.notify.error('Veuillez choisir un moyen de paiement.');
      return;
    }
    this.notify.info('Paiement en cours de traitement...');
    setTimeout(() => {
      this.notify.success('Commande confirmee! Le vendeur a ete notifie.');
      this.cart.clearCart().subscribe();
      this.checkoutMode.set(false);
    }, 2000);
  }
}
