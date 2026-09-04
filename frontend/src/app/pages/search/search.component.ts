import { Component, inject, signal } from '@angular/core';
import { Router } from '@angular/router';
import { DecimalPipe } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { ProductService } from '../../core/services/product.service';

@Component({
  selector: 'app-search',
  standalone: true,
  imports: [FormsModule, DecimalPipe],
  templateUrl: './search.component.html',
  styleUrl: './search.component.scss',
})
export class SearchComponent {
  private productService = inject(ProductService);
  private router = inject(Router);

  query = signal('');
  products = signal<any[]>([]);
  users = signal<any[]>([]);
  loading = signal(false);
  searched = signal(false);
  private debounceHandle: any;

  onInput(value: string) {
    this.query.set(value);
    clearTimeout(this.debounceHandle);
    if (!value.trim()) {
      this.products.set([]);
      this.users.set([]);
      this.searched.set(false);
      return;
    }
    this.debounceHandle = setTimeout(() => this.runSearch(value.trim()), 350);
  }

  private runSearch(q: string) {
    this.loading.set(true);
    this.productService.search(q).subscribe({
      next: (res: any) => {
        this.products.set(res.products || []);
        this.users.set(res.users || []);
        this.loading.set(false);
        this.searched.set(true);
      },
      error: () => { this.loading.set(false); this.searched.set(true); },
    });
  }

  goToProduct(slug: string) {
    this.router.navigate(['/product', slug]);
  }

  goToSeller(username: string) {
    this.router.navigate(['/seller', username]);
  }

  goBack() {
    this.router.navigate(['/feed']);
  }
}
