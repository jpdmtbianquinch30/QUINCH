class User {
  final String id;
  final String fullName;
  final String phoneNumber;
  final String? username;
  final String? email;
  final String? avatar;
  final String? avatarUrl;
  final String? cover;
  final String? coverUrl;
  final String? bio;
  final String? location;
  final String? region;
  final String? city;
  final String role;
  final double trustScore;
  final bool isVerified;
  final bool isKycVerified;
  final int followersCount;
  final int followingCount;
  final int productsCount;
  final DateTime createdAt;

  User({
    required this.id,
    required this.fullName,
    required this.phoneNumber,
    this.username,
    this.email,
    this.avatar,
    this.avatarUrl,
    this.cover,
    this.coverUrl,
    this.bio,
    this.location,
    this.region,
    this.city,
    required this.role,
    required this.trustScore,
    required this.isVerified,
    required this.isKycVerified,
    required this.followersCount,
    required this.followingCount,
    required this.productsCount,
    required this.createdAt,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    final avatar    = json['avatar'] as String?;
    final cover     = json['cover'] as String?;
    final baseUrl   = json['base_url'] as String? ?? '';

    return User(
      id:             json['id']?.toString() ?? '',
      fullName:       json['full_name'] as String? ?? json['name'] as String? ?? '',
      phoneNumber:    json['phone_number'] as String? ?? '',
      username:       json['username'] as String?,
      email:          json['email'] as String?,
      avatar:         avatar,
      avatarUrl:      json['avatar_url'] as String? ?? (avatar != null && avatar.startsWith('http') ? avatar : (avatar != null ? '$baseUrl/storage/$avatar' : null)),
      cover:          cover,
      coverUrl:       json['cover_url'] as String? ?? (cover != null && cover.startsWith('http') ? cover : (cover != null ? '$baseUrl/storage/$cover' : null)),
      bio:            json['bio'] as String?,
      location:       json['location'] as String?,
      region:         json['region'] as String?,
      city:           json['city'] as String?,
      role:           json['role'] as String? ?? 'user',
      trustScore:     (json['trust_score'] as num?)?.toDouble() ?? 0.0,
      isVerified:     json['is_verified'] as bool? ?? false,
      isKycVerified:  json['is_kyc_verified'] as bool? ?? false,
      followersCount: json['followers_count'] as int? ?? 0,
      followingCount: json['following_count'] as int? ?? 0,
      productsCount:  json['products_count'] as int? ?? 0,
      createdAt:      DateTime.tryParse(json['created_at'] as String? ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id':               id,
    'full_name':        fullName,
    'phone_number':     phoneNumber,
    'username':         username,
    'email':            email,
    'avatar':           avatar,
    'cover':            cover,
    'bio':              bio,
    'location':         location,
    'region':           region,
    'city':             city,
    'role':             role,
    'trust_score':      trustScore,
    'is_verified':      isVerified,
    'is_kyc_verified':  isKycVerified,
    'followers_count':  followersCount,
    'following_count':  followingCount,
    'products_count':   productsCount,
    'created_at':       createdAt.toIso8601String(),
  };

  bool get isAdmin => role == 'admin' || role == 'super_admin';

  User copyWith({
    String? fullName,
    String? username,
    String? email,
    String? avatar,
    String? avatarUrl,
    String? cover,
    String? coverUrl,
    String? bio,
    String? location,
    String? region,
    String? city,
    double? trustScore,
    bool? isVerified,
    bool? isKycVerified,
    int? followersCount,
    int? followingCount,
    int? productsCount,
  }) {
    return User(
      id:             id,
      fullName:       fullName ?? this.fullName,
      phoneNumber:    phoneNumber,
      username:       username ?? this.username,
      email:          email ?? this.email,
      avatar:         avatar ?? this.avatar,
      avatarUrl:      avatarUrl ?? this.avatarUrl,
      cover:          cover ?? this.cover,
      coverUrl:       coverUrl ?? this.coverUrl,
      bio:            bio ?? this.bio,
      location:       location ?? this.location,
      region:         region ?? this.region,
      city:           city ?? this.city,
      role:           role,
      trustScore:     trustScore ?? this.trustScore,
      isVerified:     isVerified ?? this.isVerified,
      isKycVerified:  isKycVerified ?? this.isKycVerified,
      followersCount: followersCount ?? this.followersCount,
      followingCount: followingCount ?? this.followingCount,
      productsCount:  productsCount ?? this.productsCount,
      createdAt:      createdAt,
    );
  }
}

class AuthResponse {
  final String token;
  final String tokenType;
  final User user;

  AuthResponse({
    required this.token,
    required this.tokenType,
    required this.user,
  });

  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    return AuthResponse(
      token:     json['token'] as String? ?? json['access_token'] as String? ?? '',
      tokenType: json['token_type'] as String? ?? 'Bearer',
      user:      User.fromJson(json['user'] as Map<String, dynamic>),
    );
  }
}