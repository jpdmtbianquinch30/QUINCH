import { Component, inject, signal, OnInit, computed } from '@angular/core';
import { DatePipe } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { RouterLink } from '@angular/router';
import { ProductService } from '../../core/services/product.service';
import { NotificationService } from '../../core/services/notification.service';
import { AuthService } from '../../core/services/auth.service';

@Component({
  selector: 'app-transactions',
  standalone: true,
  imports: [DatePipe, FormsModule, RouterLink],
  templateUrl: './transactions.component.html',
  styleUrl: './transactions.component.scss',
})
export class TransactionsComponent implements OnInit {
  private productService = inject(ProductService);
  private notify = inject(NotificationService);
  auth = inject(AuthService);

  purchases = signal<any[]>([]);
  sales = signal<any[]>([]);
  activeTab = signal<'purchases' | 'sales'>('purchases');
  loading = signal(true);

  // Filters
  statusFilter = signal('all');
  dateFilter = signal('all');
  searchQuery = signal('');

  // Detail
  expandedTxId = signal<string | null>(null);
  actionLoading = signal<string | null>(null);

  // Stats from backend
  stats = signal<any>({});

  // Computed stats
  totalSpent = computed(() => this.stats().total_spent || 0);
  totalEarned = computed(() => this.stats().total_earned || 0);
  completedCount = computed(() =>
    this.activeTab() === 'purchases' ? (this.stats().completed_purchases || 0) : (this.stats().completed_sales || 0)
  );
  pendingCount = computed(() =>
    this.activeTab() === 'purchases' ? (this.stats().pending_purchases || 0) : (this.stats().pending_sales || 0)
  );
  salesCount = computed(() => this.stats().sales_count || 0);
  purchasesCount = computed(() => this.stats().purchases_count || 0);

  // Filtered
  filteredTransactions = computed(() => {
    let items = this.activeTab() === 'purchases' ? this.purchases() : this.sales();

    const status = this.statusFilter();
    if (status !== 'all') {
      items = items.filter(tx => tx.payment_status === status);
    }

    const dateF = this.dateFilter();
    if (dateF !== 'all') {
      const now = new Date();
      let cutoff: Date;
      switch (dateF) {
        case '7d': cutoff = new Date(now.getTime() - 7 * 86400000); break;
        case '30d': cutoff = new Date(now.getTime() - 30 * 86400000); break;
        case '90d': cutoff = new Date(now.getTime() - 90 * 86400000); break;
        default: cutoff = new Date(0);
      }
      items = items.filter(tx => new Date(tx.created_at) >= cutoff);
    }

    const q = this.searchQuery().toLowerCase();
    if (q) {
      items = items.filter(tx =>
        tx.product?.title?.toLowerCase().includes(q) ||
        tx.id?.toLowerCase().includes(q) ||
        tx.buyer?.full_name?.toLowerCase().includes(q) ||
        tx.seller?.full_name?.toLowerCase().includes(q)
      );
    }

    return items;
  });

  ngOnInit() {
    this.loadHistory();
  }

  loadHistory() {
    this.loading.set(true);
    this.productService.getTransactionHistory().subscribe({
      next: (res: any) => {
        this.purchases.set(res.purchases?.data || []);
        this.sales.set(res.sales?.data || []);
        if (res.stats) this.stats.set(res.stats);
        this.loading.set(false);
      },
      error: () => this.loading.set(false),
    });
  }

  toggleExpand(txId: string) {
    this.expandedTxId.set(this.expandedTxId() === txId ? null : txId);
  }

  // ─── Seller Actions ──────────────
  acceptOrder(tx: any) {
    this.actionLoading.set(tx.id);
    this.productService.updateTransactionStatus(tx.id, 'processing').subscribe({
      next: (res: any) => {
        this.updateTxInList(res.transaction);
        this.notify.success('Commande acceptée!');
        this.actionLoading.set(null);
      },
      error: (err) => { this.notify.error(err.error?.message || 'Erreur'); this.actionLoading.set(null); },
    });
  }

  shipOrder(tx: any) {
    this.actionLoading.set(tx.id);
    this.productService.updateTransactionStatus(tx.id, 'shipped').subscribe({
      next: (res: any) => {
        this.updateTxInList(res.transaction);
        this.notify.success('Commande marquée comme expédiée!');
        this.actionLoading.set(null);
      },
      error: (err) => { this.notify.error(err.error?.message || 'Erreur'); this.actionLoading.set(null); },
    });
  }

  markDelivered(tx: any) {
    this.actionLoading.set(tx.id);
    this.productService.updateTransactionStatus(tx.id, 'delivered').subscribe({
      next: (res: any) => {
        this.updateTxInList(res.transaction);
        this.notify.success('Commande livrée avec succès!');
        this.actionLoading.set(null);
        this.loadHistory(); // refresh stats
      },
      error: (err) => { this.notify.error(err.error?.message || 'Erreur'); this.actionLoading.set(null); },
    });
  }

  confirmReceipt(tx: any) {
    this.actionLoading.set(tx.id);
    this.productService.updateTransactionStatus(tx.id, 'completed').subscribe({
      next: (res: any) => {
        this.updateTxInList(res.transaction);
        this.notify.success('Réception confirmée!');
        this.actionLoading.set(null);
        this.loadHistory();
      },
      error: (err) => { this.notify.error(err.error?.message || 'Erreur'); this.actionLoading.set(null); },
    });
  }

  cancelOrder(tx: any) {
    this.actionLoading.set(tx.id);
    this.productService.updateTransactionStatus(tx.id, 'cancelled').subscribe({
      next: (res: any) => {
        this.updateTxInList(res.transaction);
        this.notify.success('Commande annulée.');
        this.actionLoading.set(null);
        this.loadHistory();
      },
      error: (err) => { this.notify.error(err.error?.message || 'Erreur'); this.actionLoading.set(null); },
    });
  }

  private updateTxInList(updatedTx: any) {
    if (!updatedTx) return;
    const updateFn = (list: any[]) => list.map(t => t.id === updatedTx.id ? { ...t, ...updatedTx } : t);
    this.purchases.update(updateFn);
    this.sales.update(updateFn);
  }

  // ─── Helpers ──────────────
  formatPrice(amount: number): string {
    if (!amount) return '0 F';
    return new Intl.NumberFormat('fr-SN').format(amount) + ' F';
  }

  getStatusLabel(status: string): string {
    const labels: Record<string, string> = {
      pending: 'En attente', processing: 'En cours', completed: 'Terminé',
      failed: 'Échoué', refunded: 'Remboursé', cancelled: 'Annulé',
    };
    return labels[status] || status;
  }

  getStatusIcon(status: string): string {
    const icons: Record<string, string> = {
      pending: 'schedule', processing: 'local_shipping', completed: 'check_circle',
      failed: 'cancel', refunded: 'replay', cancelled: 'block',
    };
    return icons[status] || 'help';
  }

  getStatusClass(status: string): string {
    const classes: Record<string, string> = {
      pending: 'status-warning', processing: 'status-info', completed: 'status-success',
      failed: 'status-danger', refunded: 'status-muted', cancelled: 'status-danger',
    };
    return classes[status] || '';
  }

  getPaymentLabel(method: string): string {
    const labels: Record<string, string> = {
      orange_money: 'Orange Money', wave: 'Wave', free_money: 'Free Money',
      cash_delivery: 'Paiement à la livraison',
    };
    return labels[method] || method;
  }

  getPaymentIcon(method: string): string {
    const icons: Record<string, string> = {
      orange_money: '🟠', wave: '🔵', free_money: '🟢', cash: '💵', cash_delivery: '📦',
    };
    return icons[method] || '💳';
  }

  getDeliveryLabel(type: string): string {
    const labels: Record<string, string> = {
      pickup: 'Retrait sur place', delivery: 'Livraison', meetup: 'Rencontre',
    };
    return labels[type] || type;
  }

  getDeliveryIcon(type: string): string {
    const icons: Record<string, string> = {
      pickup: 'store', delivery: 'local_shipping', meetup: 'handshake',
    };
    return icons[type] || 'local_shipping';
  }

  /** Step progress for status timeline */
  getStatusStep(status: string): number {
    const steps: Record<string, number> = {
      pending: 1, processing: 2, completed: 3, failed: 0, cancelled: 0, refunded: 0,
    };
    return steps[status] || 0;
  }

  getOtherUser(tx: any): any {
    return this.activeTab() === 'purchases' ? tx.seller : tx.buyer;
  }

  getShortId(id: string): string {
    return id ? id.substring(0, 8).toUpperCase() : '';
  }

  isSeller(tx: any): boolean {
    return tx.seller_id === this.auth.user()?.id;
  }

  timeAgo(dateStr: string): string {
    if (!dateStr) return '';
    const d = new Date(dateStr);
    const now = new Date();
    const diff = now.getTime() - d.getTime();
    const mins = Math.floor(diff / 60000);
    if (mins < 1) return 'à l\'instant';
    if (mins < 60) return `il y a ${mins}min`;
    const hrs = Math.floor(mins / 60);
    if (hrs < 24) return `il y a ${hrs}h`;
    const days = Math.floor(hrs / 24);
    if (days < 7) return `il y a ${days}j`;
    return d.toLocaleDateString('fr-FR', { day: 'numeric', month: 'short' });
  }
}
