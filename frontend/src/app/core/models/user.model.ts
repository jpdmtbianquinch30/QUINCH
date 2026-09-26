import { Badge } from "../services/badge.service";

export interface User {
  id: string;
  phone_number: string;
  email?: string;
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
  role: 'user' | 'admin' | 'super_admin'; // 'user' = client, 'admin'/'super_admin' = admin
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
  demo_otp?: string;
}

export interface LoginRequest {
  phone_number: string;
  password: string;
}

export interface RegisterRequest {
  phone_number: string;
  full_name: string;
  username: string;
  password: string;
  password_confirmation: string;
}

export interface VerifyOtpRequest {
  phone_number: string;
  otp: string;
}

export interface ResendOtpResponse {
  message: string;
  demo_otp?: string;
}
