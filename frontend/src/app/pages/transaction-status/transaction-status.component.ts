import { Component, inject, OnInit, OnDestroy, signal } from '@angular/core';
import { ActivatedRoute, Router, RouterLink } from '@angular/router';
import { CommonModule } from '@angular/common';
import { ProductService } from '../../core/services/product.service';

@Component({
  selector: 'app-transaction-status',
  standalone: true,
  imports: [CommonModule, RouterLink],
  templateUrl: './transaction-status.component.html',
  styleUrl: './transaction-status.component.scss',
})
export class TransactionStatusComponent implements OnInit, OnDestroy {
  private route = inject(ActivatedRoute);
  private router = inject(Router);
  private productService = inject(ProductService);

  outcome = signal<'success' | 'error'>('success');
  loading = signal(true);
  transaction = signal<any>(null);
  private pollHandle: any = null;
  private attempts = 0;

  ngOnInit() {
    const outcome = this.route.snapshot.paramMap.get('outcome');
    this.outcome.set(outcome === 'error' ? 'error' : 'success');

    const id = this.route.snapshot.paramMap.get('id');
    if (!id) {
      this.loading.set(false);
      return;
    }

    // Le webhook de la passerelle peut arriver quelques secondes après le
    // retour de l'utilisateur sur cette page — on interroge la transaction
    // plusieurs fois avant d'abandonner, plutôt que d'afficher un état
    // "en attente" figé qui ne se met jamais à jour tout seul.
    this.fetchStatus(id);
  }

  private fetchStatus(id: string) {
    this.productService.getTransaction(id).subscribe({
      next: (res: any) => {
        this.transaction.set(res.transaction);
        this.loading.set(false);

        const stillPending = res.transaction?.payment_status === 'pending';
        if (stillPending && this.attempts < 6) {
          this.attempts++;
          this.pollHandle = setTimeout(() => this.fetchStatus(id), 5000);
        }
      },
      error: () => this.loading.set(false),
    });
  }

  ngOnDestroy() {
    if (this.pollHandle) clearTimeout(this.pollHandle);
  }

  goToTransactions() {
    this.router.navigate(['/transactions']);
  }
}