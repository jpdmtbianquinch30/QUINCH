import { Injectable, signal } from '@angular/core';
import { Observable, tap } from 'rxjs';
import { ApiService } from './api.service';

export interface FollowUser {
  id: string;
  full_name: string;
  username: string;
  avatar_url: string;
  trust_score: number;
}

@Injectable({ providedIn: 'root' })
export class FollowService {
  myFollowers = signal<FollowUser[]>([]);
  myFollowing = signal<FollowUser[]>([]);
  followerCount = signal(0);
  followingCount = signal(0);

  constructor(private api: ApiService) {}

  follow(userId: string): Observable<any> {
    return this.api.post(`follow/${userId}`, {});
  }

  unfollow(userId: string): Observable<any> {
    return this.api.delete(`unfollow/${userId}`);
  }

  getMyFollowers(): Observable<any> {
    return this.api.get('my-followers').pipe(
      tap((res: any) => {
        this.myFollowers.set((res.data || []).map((f: any) => f.follower));
        this.followerCount.set(res.total || (res.data || []).length);
      })
    );
  }

  getMyFollowing(): Observable<any> {
    return this.api.get('my-following').pipe(
      tap((res: any) => {
        this.myFollowing.set((res.data || []).map((f: any) => f.following));
        this.followingCount.set(res.total || (res.data || []).length);
      })
    );
  }

  getUserFollowers(userId: string): Observable<any> {
    return this.api.get(`users/${userId}/followers`);
  }

  getUserFollowing(userId: string): Observable<any> {
    return this.api.get(`users/${userId}/following`);
  }

  getFollowCounts(userId: string): Observable<any> {
    return this.api.get(`users/${userId}/follow-counts`);
  }

  /** Get list of mutual friends */
  getMyFriends(): Observable<any> {
    return this.api.get('my-friends');
  }

  /** Check if a specific user is a mutual friend */
  isFriend(userId: string): Observable<any> {
    return this.api.get(`users/${userId}/is-friend`);
  }
}
