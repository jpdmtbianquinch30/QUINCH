class User {
  final String id;
  final String phoneNumber;
  final String? email;
  final String? username;
  final String fullName;
  final String? avatarUrl;
  final String? coverUrl;
  final double trustScore;
  final String trustLevel;
  final String trustBadge;
  final String kycStatus;
  final String? bio;
  final String? city;
  final String? region;
  final String? location;
  final int followersCount;
  final int followingCount;
  final bool isOnline;
  final String role;
  final bool phoneVerified;
  final bool onboardingCompleted;
  final UserPreferences? preferences;
  final String createdAt;

  User({
    required this.id,
    required this.phoneNumber,
    this.email,
    this.username,
    required this.fullName,
    this.avatarUrl,
    this.coverUrl,
    this.trustScore = 0.5,
    this.trustLevel = 'new',
    this.trustBadge = '',
    this.kycStatus = 'pending',
    this.bio,
    this.city,
    this.region,
    this.location,
    this.followersCount = 0,
    this.followingCount = 0,
    this.isOnline = false,
    this.role = 'user',
    this.phoneVerified = false,
    this.onboardingCompleted = false,
    this.preferences,
    required this.createdAt,
  });

  bool get isAdmin => role == 'admin' || role == 'super_admin';

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id']?.toString() ?? '',
      phoneNumber: json['phone_number'] ?? '',
      email: json['email'],
      username: json['username'],
      fullName: json['full_name'] ?? '',
      avatarUrl: json['avatar_url'],
      coverUrl: json['cover_url'],
      trustScore: (json['trust_score'] ?? 0.5).toDouble(),
      trustLevel: json['trust_level'] ?? 'new',
      trustBadge: json['trust_badge'] ?? '',
      kycStatus: json['kyc_status'] ?? 'pending',
      bio: json['bio'],
      city: json['city'],
      region: json['region'],
      location: json['location'] ?? json['city'],
      followersCount: json['followers_count'] ?? 0,
      followingCount: json['following_count'] ?? 0,
      isOnline: json['is_online'] ?? false,
      role: json['role'] ?? 'user',
      phoneVerified: json['phone_verified'] ?? false,
      onboardingCompleted: json['onboarding_completed'] ?? false,
      preferences: json['preferences'] != null
          ? UserPreferences.fromJson(json['preferences'])
          : null,
      createdAt: json['created_at'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'phone_number': phoneNumber,
      'email': email,
      'username': username,
      'full_name': fullName,
      'avatar_url': avatarUrl,
      'cover_url': coverUrl,
      'trust_score': trustScore,
      'trust_level': trustLevel,
      'trust_badge': trustBadge,
      'kyc_status': kycStatus,
      'bio': bio,
      'city': city,
      'region': region,
      'role': role,
      'phone_verified': phoneVerified,
      'onboarding_completed': onboardingCompleted,
      'created_at': createdAt,
    };
  }
}

class UserPreferences {
  final List<String>? categories;
  final Map<String, String>? location;

  UserPreferences({this.categories, this.location});

  factory UserPreferences.fromJson(Map<String, dynamic> json) {
    return UserPreferences(
      categories: json['categories'] != null
          ? List<String>.from(json['categories'])
          : null,
      location: json['location'] != null
          ? Map<String, String>.from(json['location'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'categories': categories,
      'location': location,
    };
  }
}

class AuthResponse {
  final String message;
  final User user;
  final String token;
  final String? demoOtp;

  AuthResponse({
    required this.message,
    required this.user,
    required this.token,
    this.demoOtp,
  });

  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    return AuthResponse(
      message: json['message'] ?? '',
      user: User.fromJson(json['user']),
      token: json['token'] ?? '',
      demoOtp: json['demo_otp'],
    );
  }
}
