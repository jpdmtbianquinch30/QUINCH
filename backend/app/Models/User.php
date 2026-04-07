<?php

namespace App\Models;

use App\Models\Traits\HasUuid;
use App\Models\Traits\Auditable;
use App\Models\Traits\TrustScorable;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Foundation\Auth\User as Authenticatable;
use Illuminate\Notifications\Notifiable;
use Laravel\Sanctum\HasApiTokens;
use Illuminate\Database\Eloquent\Relations\HasMany;

class User extends Authenticatable
{
    use HasApiTokens, HasFactory, Notifiable, HasUuid, TrustScorable;

    protected $keyType = 'string';
    public $incrementing = false;

    protected $fillable = [
        'phone_number',
        'email',
        'username',
        'full_name',
        'password',
        'avatar_url',
        'cover_url',
        'bio',
        'trust_score',
        'kyc_status',
        'kyc_data',
        'city',
        'region',
        'latitude',
        'longitude',
        'is_seller',
        'is_buyer',
        'role',
        'security_level',
        'account_status',
        'last_suspicious_activity',
        'otp_code',
        'otp_expires_at',
        'phone_verified',
        'preferences',
        'onboarding_completed',
        'device_fingerprint',
    ];

    protected $hidden = [
        'password',
        'remember_token',
        'otp_code',
        'otp_expires_at',
        'device_fingerprint',
    ];

    protected function casts(): array
    {
        return [
            'password' => 'hashed',
            'kyc_data' => 'array',
            'preferences' => 'array',
            'is_seller' => 'boolean',
            'is_buyer' => 'boolean',
            'phone_verified' => 'boolean',
            'onboarding_completed' => 'boolean',
            'trust_score' => 'float',
            'otp_expires_at' => 'datetime',
            'last_suspicious_activity' => 'datetime',
            'latitude' => 'float',
            'longitude' => 'float',
        ];
    }

    // ─── Relationships ──────────────────────────────────────────────────
    public function products(): HasMany
    {
        return $this->hasMany(Product::class);
    }

    public function videos(): HasMany
    {
        return $this->hasMany(ProductVideo::class);
    }

    public function purchasedTransactions(): HasMany
    {
        return $this->hasMany(Transaction::class, 'buyer_id');
    }

    public function soldTransactions(): HasMany
    {
        return $this->hasMany(Transaction::class, 'seller_id');
    }

    public function likedProducts()
    {
        return $this->belongsToMany(Product::class, 'product_likes')->withTimestamps();
    }

    public function savedProducts()
    {
        return $this->belongsToMany(Product::class, 'product_saves')->withTimestamps();
    }

    public function badges(): HasMany
    {
        return $this->hasMany(UserBadge::class);
    }

    public function followers()
    {
        return $this->hasMany(UserFollow::class, 'following_id');
    }

    public function following()
    {
        return $this->hasMany(UserFollow::class, 'follower_id');
    }

    public function reviewsReceived(): HasMany
    {
        return $this->hasMany(UserReview::class, 'seller_id');
    }

    public function reviewsGiven(): HasMany
    {
        return $this->hasMany(UserReview::class, 'reviewer_id');
    }

    public function reportsReceived(): HasMany
    {
        return $this->hasMany(UserReport::class, 'reported_user_id');
    }

    public function reportsMade(): HasMany
    {
        return $this->hasMany(UserReport::class, 'reporter_id');
    }

    public function blockedUsers()
    {
        return $this->belongsToMany(User::class, 'blocked_users', 'user_id', 'blocked_user_id')->withTimestamps();
    }

    // ─── Scopes ─────────────────────────────────────────────────────────
    public function scopeActive($query)
    {
        return $query->where('account_status', 'active');
    }

    public function scopeClients($query)
    {
        return $query->where('role', 'user');
    }

    public function scopeAdmins($query)
    {
        return $query->whereIn('role', ['admin', 'super_admin']);
    }

    public function scopeVerified($query)
    {
        return $query->where('kyc_status', 'verified');
    }

    public function isClient(): bool
    {
        return $this->role === 'user';
    }

    // ─── Helpers ────────────────────────────────────────────────────────
    public function isAdmin(): bool
    {
        return in_array($this->role, ['admin', 'super_admin']);
    }

    public function isSuperAdmin(): bool
    {
        return $this->role === 'super_admin';
    }

    public function isSuspended(): bool
    {
        return $this->account_status === 'suspended';
    }

    public function generateOtp(): string
    {
        $otp = str_pad(random_int(0, 999999), 6, '0', STR_PAD_LEFT);
        $this->update([
            'otp_code' => bcrypt($otp),
            'otp_expires_at' => now()->addMinutes(10),
        ]);
        return $otp;
    }

    public function verifyOtp(string $otp): bool
    {
        if (!$this->otp_expires_at || $this->otp_expires_at->isPast()) {
            return false;
        }
        return password_verify($otp, $this->otp_code);
    }

    public function getAccountAgeDaysAttribute(): int
    {
        return (int) $this->created_at->diffInDays(now());
    }

    // ─── URL Accessors (return full absolute URLs for frontend) ──────
    public function getAvatarUrlAttribute($value): ?string
    {
        if (!$value) return null;
        if (str_starts_with($value, 'http')) return $value;
        return url($value);
    }

    public function getCoverUrlAttribute($value): ?string
    {
        if (!$value) return null;
        if (str_starts_with($value, 'http')) return $value;
        return url($value);
    }
}
