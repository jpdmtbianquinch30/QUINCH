import { Component, inject, OnInit, signal, computed } from '@angular/core';
import { RouterLink } from '@angular/router';
import { DecimalPipe } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { CartService, CartItem } from '../../core/services/cart.service';
import { NotificationService } from '../../core/services/notification.service';
import { ProductService } from '../../core/services/product.service';
import { ChatService } from '../../core/services/chat.service';
import { Router } from '@angular/router';

@Component({
  selector: 'app-cart',
  standalone: true,
  imports: [RouterLink, DecimalPipe, FormsModule],
  templateUrl: './cart.component.html',
  styleUrl: './cart.component.scss',
})
export class CartComponent implements OnInit {
  cart = inject(CartService);
  private notify = inject(NotificationService);
  private productService = inject(ProductService);
  private chatService = inject(ChatService);
  private router = inject(Router);

  loading = signal(false);

  // Master list — source unique de vérité, reflète PaymentGatewayFactory.
  allPaymentMethods = ProductService.ALL_PAYMENT_METHODS;

  // Items with delivery fees
  itemsWithDeliveryFee = computed(() => {
    return this.cart.items().filter(item =>
      item.product.delivery_option === 'fixed' && (item.product.delivery_fee || 0) > 0
    );
  });

  itemsDeliveryContact = computed(() => {
    return this.cart.items().filter(item =>
      item.product.delivery_option !== 'fixed' || !(item.product.delivery_fee || 0)
    );
  });

  // ─── Achat en modale (par article, sans quitter le panier) ────────────
  buyingItem = signal<CartItem | null>(null);
  buyQuantity = signal(1);
  selectedPayment = signal('');
  deliveryAddressText = signal('');
  pendingTransactionId = signal<string | null>(null);
  submittingPurchase = signal(false);

  itemPaymentMethods = computed(() => {
    const item = this.buyingItem();
    if (!item?.product.payment_methods?.length) return [];
    return this.allPaymentMethods.filter(m => item.product.payment_methods!.includes(m.id));
  });

  // ─── Contact vendeur (par article, sans quitter le panier) ─────────────
  contactingItem = signal<CartItem | null>(null);
  contactMessage = signal('');
  sendingContact = signal(false);

  ngOnInit() {
    this.loading.set(true);
    this.cart.loadCart().subscribe({
      error: () => this.loading.set(false),
      complete: () => this.loading.set(false),
    });
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

  // ─── Achat direct depuis le panier ─────────────────────────────────────
  openBuyModal(item: CartItem) {
    if (!item.product.payment_methods?.length) {
      this.notify.info('Le vendeur n\'a pas configure de methode de paiement. Contactez-le directement.');
      this.openContactModal(item);
      return;
    }
    this.buyingItem.set(item);
    this.buyQuantity.set(1);
    this.selectedPayment.set('');
    this.deliveryAddressText.set('');
    this.pendingTransactionId.set(null);
  }

    incrementBuyQty() {
    const max = this.buyingItem()?.product.stock_quantity ?? 1;
    this.buyQuantity.update(q => Math.min(q + 1, max));
  }

  decrementBuyQty() {
    this.buyQuantity.update(q => Math.max(q - 1, 1));
  }

  confirmCartPurchase() {
    const item = this.buyingItem();
    if (!item || !this.selectedPayment()) return;

    this.submittingPurchase.set(true);
    this.productService.initiateTransaction({
      product_id: item.product_id,
      payment_method: this.selectedPayment(),
      delivery_type: 'delivery',
      delivery_address: { text: this.deliveryAddressText().trim() || 'À convenir avec le vendeur' },
      quantity: this.buyQuantity(),
    }).subscribe({
      next: (res: any) => {
        this.submittingPurchase.set(false);
        if (res.payment_url) {
          this.pendingTransactionId.set(res.transaction?.id ?? null);
          window.location.href = res.payment_url;
        } else {
          this.notify.error('Le lien de paiement est introuvable.');
        }
      },
      error: (err: any) => {
        this.submittingPurchase.set(false);
        this.notify.error(err?.error?.message || 'Erreur lors de l\'initialisation du paiement.');
      },
    });
  }

  cancelCartPurchase() {
    const id = this.pendingTransactionId();
    if (!id) {
      this.buyingItem.set(null);
      return;
    }
    this.productService.cancelTransaction(id).subscribe({
      next: () => {
        this.notify.info('Paiement annulé.');
        this.closeBuyModal();
      },
      error: (err: any) => {
        this.notify.error(err?.error?.message || 'Impossible d\'annuler pour le moment.');
        this.closeBuyModal();
      },
    });
  }

  closeBuyModal() {
    this.buyingItem.set(null);
    this.pendingTransactionId.set(null);
  }

  // ─── Contacter le vendeur depuis le panier ─────────────────────────────
  openContactModal(item: CartItem) {
    this.contactingItem.set(item);
    this.contactMessage.set(`Bonjour, je suis intéressé par "${item.product.title}" dans mon panier.`);
  }

  closeContactModal() {
    this.contactingItem.set(null);
  }

  sendCartContactMessage() {
    const item = this.contactingItem();
    const sellerId = item?.product.seller?.id;
    const message = this.contactMessage().trim();
    if (!item || !sellerId || !message) return;

    this.sendingContact.set(true);
    this.chatService.startConversation(sellerId, message, item.product_id).subscribe({
      next: () => {
        this.sendingContact.set(false);
        this.notify.success('Message envoyé !');
        this.closeContactModal();
        this.router.navigate(['/messages']);
      },
      error: (err: any) => {
        this.sendingContact.set(false);
        this.notify.error(err?.error?.message || 'Erreur lors de l\'envoi.');
      },
    });
  }
}
