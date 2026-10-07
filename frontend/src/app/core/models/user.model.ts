import { Badge } from "../services/badge.service";

export interface User {
  id: string;
  email: string;
  email_verified?: boolean;
  /** Facultatif : information de profil, plus un identifiant. */
  phone_number?: string | null;
  username?: string;
  full_name: string;
  avatar_url?: string;
  cover_url?: string;
  trust_score: number;
  trust_level: string;
  trust_badge: string;
  badges?: Badge[];
  kyc_status: 'pending' | 'verified' | 'rejected';
  is_premium?: boolean;
  premium_expires_at?: string | null;
  bio?: string;
  city?: string;
  region?: string;
  is_seller?: boolean;
  is_buyer?: boolean;
  website?: string;
  seller_policies?: {
    returns_accepted: boolean;
    return_window_days: number;
    warranty_offered: boolean;
    warranty_duration_months: number;
    delivery_available: boolean;
    pickup_available: boolean;
    negotiable_by_default: boolean;
  } | null;
  role: 'user' | 'moderator' | 'admin' | 'super_admin'; // 'user' = client, le reste = staff
  phone_verified: boolean;
  onboarding_completed: boolean;
  preferences?: UserPreferences;
  created_at: string;
}

export interface UserPreferences {
  categories?: string[];
  location?: { city: string; region: string };
}

export interface AuthResponse {
  message: string;
  user: User;
  token: string;
}

export interface LoginRequest {
  email: string;
  password: string;
}

export interface RegisterRequest {
  email: string;
  full_name: string;
  username: string;
  password: string;
  password_confirmation: string;
  /** Consentement aux conditions d'utilisation et à la politique de confidentialité. */
  accept_terms: boolean;
}
