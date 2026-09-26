import { Component, inject, signal, ElementRef, ViewChild, AfterViewInit } from '@angular/core';
import { Router } from '@angular/router';
import { DecimalPipe, Location } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { ProductService } from '../../core/services/product.service';
import { OnInit } from '@angular/core';
import { ApiService } from '../../core/services/api.service';
import { AuthService } from '../../core/services/auth.service';

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
  private api = inject(ApiService);
private auth = inject(AuthService);
private location = inject(Location);

defaultProducts = signal<any[]>([]);
defaultSellers = signal<any[]>([]);
loadingDefaults = signal(false);

ngOnInit() {
  this.loadDefaultSuggestions();
}

  @ViewChild('searchInput') searchInput?: ElementRef<HTMLInputElement>;

  ngAfterViewInit() {
    setTimeout(() => this.searchInput?.nativeElement?.focus(), 0);
  }

private loadDefaultSuggestions() {
  this.loadingDefaults.set(true);
  const endpoint = this.auth.isAuthenticated() ? 'search/suggestions' : 'search/trending';
  this.api.get<any>(endpoint).subscribe({
    next: (res: any) => {
      this.defaultProducts.set(res.suggestions || []);
      this.defaultSellers.set(res.sellers || []);
      this.loadingDefaults.set(false);
    },
    error: () => this.loadingDefaults.set(false),
  });
}

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
  if (window.history.length > 1) {
    this.location.back();
  } else {
    this.router.navigate(['/feed']); // '/profile' pour edit-profile
  }
}
}
