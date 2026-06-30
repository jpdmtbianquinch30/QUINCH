import { Injectable } from '@angular/core';
import { Observable } from 'rxjs';
import { ApiService } from './api.service';

export interface Review {
  id: string;
  reviewer: { id: string; full_name: string; username: string; avatar_url: string };
  rating: number;
  comment: string;
  delivery_rating: number | null;
  communication_rating: number | null;
  accuracy_rating: number | null;
  seller_response: string | null;
  seller_responded_at: string | null;
  created_at: string;
}

export interface ReviewStats {
  average: number;
  total: number;
  distribution: Record<number, number>;
  avg_delivery: number;
  avg_communication: number;
  avg_accuracy: number;
}

@Injectable({ providedIn: 'root' })
export class ReviewService {
  constructor(private api: ApiService) {}

  getSellerReviews(userId: string): Observable<{ reviews: any; stats: ReviewStats }> {
    return this.api.get(`users/${userId}/reviews`);
  }

  createReview(data: { seller_id: string; transaction_id?: string; rating: number; comment?: string; delivery_rating?: number; communication_rating?: number; accuracy_rating?: number }): Observable<any> {
    return this.api.post('reviews', data);
  }

  respondToReview(reviewId: string, response: string): Observable<any> {
    return this.api.post(`reviews/${reviewId}/respond`, { response });
  }
}
