export interface Product {
  id: string;
  type: 'product' | 'service';
  title: string;
  slug: string;
  description?: string;
  price: number;
  stock_quantity?: number;
  formatted_price: string;
  currency: string;
  condition: 'new' | 'like_new' | 'good' | 'fair';
  is_negotiable: boolean;
  status: 'draft' | 'active' | 'sold' | 'reserved' | 'expired' | 'paused' | 'disabled';
  view_count: number;
  like_count: number;
  share_count: number;
  is_liked?: boolean;
  is_saved?: boolean;
  video?: ProductVideo;
  images?: string[];
  poster?: string;
  poster_full_url?: string;
  poster_url?: string;
  delivery_option?: 'fixed' | 'contact';
  delivery_fee?: number;
  payment_methods?: string[];
  category?: Category;
  seller?: SellerInfo;
  // Backend may also return as `user`
  user?: SellerInfo;
  created_at: string;
}

export interface ProductVideo {
  id: string;
  url: string;
  thumbnail: string;
  duration: number;
}

export interface Category {
  id: string;
  name: string;
  slug: string;
  icon: string;
  description?: string;
  children?: Category[];
}

export interface SellerInfo {
  id: string;
  name?: string;
  full_name?: string;
  username?: string;
  avatar?: string;
  avatar_url?: string;
  trust_score: number;
  trust_badge?: string;
  city?: string;
  region?: string;
  products_count?: number;
  member_since?: string;
  is_following?: boolean;
}

export interface FeedResponse {
  data: Product[];
  current_page: number;
  last_page: number;
  per_page: number;
  total: number;
}

export interface Transaction {
  id: string;
  buyer_id: string;
  seller_id: string;
  product_id: string;
  amount: number;
  currency: string;
  payment_method: string;
  payment_status: string;
  delivery_type: string;
  transaction_fee: number;
  product?: Product;
  seller?: SellerInfo;
  buyer?: SellerInfo;
  created_at: string;
  completed_at?: string;
}
