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
  kyc_status: 'pending' | 'verified' | 'rejected';
  bio?: string;
  city?: string;
  region?: string;
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
  password: string;
  password_confirmation: string;
}
