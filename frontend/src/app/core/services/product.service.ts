import { Injectable } from '@angular/core';
import { Observable } from 'rxjs';
import { ApiService } from './api.service';
import { FeedResponse, Product, Category, Transaction } from '../models/product.model';

@Injectable({ providedIn: 'root' })
export class ProductService {
  constructor(private api: ApiService) {}

  getFeed(page: number = 1, params?: Record<string, any>): Observable<FeedResponse> {
    return this.api.get<FeedResponse>('products/feed', { page, per_page: 10, ...params });
  }

  getFollowingFeed(page: number = 1): Observable<FeedResponse> {
    return this.api.get<FeedResponse>('products/feed', { page, per_page: 10, tab: 'following' });
  }

  getFriendsFeed(page: number = 1): Observable<FeedResponse> {
    return this.api.get<FeedResponse>('products/friends-feed', { page, per_page: 10 });
  }

  search(query: string): Observable<any> {
    return this.api.get('search', { q: query });
  }

  getProduct(slug: string): Observable<any> {
    return this.api.get(`products/${slug}`);
  }

  getProducts(params?: Record<string, any>): Observable<any> {
    return this.api.get('products/feed', params);
  }

  createProduct(data: any, imageFiles?: File[]): Observable<any> {
    if (imageFiles && imageFiles.length > 0) {
      const formData = new FormData();
      // Append all text fields
      Object.keys(data).forEach(key => {
        if (data[key] !== null && data[key] !== undefined && data[key] !== '') {
          formData.append(key, data[key]);
        }
      });
      // Append image files
      imageFiles.forEach(file => {
        formData.append('image_files[]', file);
      });
      return this.api.upload('products', formData);
    }
    return this.api.post('products', data);
  }

  createProductWithPoster(formData: FormData): Observable<any> {
    return this.api.upload('products', formData);
  }

  updateProduct(id: string, data: any): Observable<any> {
    return this.api.put(`products/${id}`, data);
  }

  deleteProduct(id: string): Observable<any> {
    return this.api.delete(`products/${id}`);
  }

  getMyProducts(): Observable<any> {
    return this.api.get('my-products');
  }

  getMyLikes(): Observable<any> {
    return this.api.get('my-likes');
  }

  uploadVideo(file: File): Observable<any> {
    const formData = new FormData();
    formData.append('video', file);
    return this.api.upload('products/upload-video', formData);
  }

  uploadVideoRaw(formData: FormData): Observable<any> {
    return this.api.upload('products/upload-video', formData);
  }

  getCategories(): Observable<{ categories: Category[] }> {
    return this.api.get<{ categories: Category[] }>('categories');
  }

  // Interactions
  viewProduct(productId: string): Observable<any> {
    return this.api.post(`products/${productId}/view`);
  }

  toggleLike(productId: string): Observable<{ liked: boolean; like_count: number }> {
    return this.api.post(`products/${productId}/like`);
  }

  likeProduct(productId: string): Observable<any> {
    return this.toggleLike(productId);
  }

  shareProduct(productId: string): Observable<any> {
    return this.api.post(`products/${productId}/share`);
  }

  toggleSave(productId: string): Observable<{ saved: boolean }> {
    return this.api.post(`products/${productId}/save`);
  }

  // Transactions
  initiateTransaction(data: any): Observable<any> {
    return this.api.post('transactions/initiate', data);
  }

  confirmTransaction(transactionId: string): Observable<any> {
    return this.api.post(`transactions/${transactionId}/confirm`);
  }

  getTransactionHistory(): Observable<any> {
    return this.api.get('transactions/history');
  }

  getTransaction(transactionId: string): Observable<any> {
    return this.api.get(`transactions/${transactionId}`);
  }

  updateTransactionStatus(transactionId: string, status: string, note?: string): Observable<any> {
    return this.api.put(`transactions/${transactionId}/status`, { status, note });
  }

  disputeTransaction(transactionId: string, reason: string): Observable<any> {
    return this.api.post(`transactions/${transactionId}/dispute`, { reason });
  }
}
