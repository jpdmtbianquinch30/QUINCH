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

    /**
     * Champs mass-assignables via User::create()/update($array). Les champs
     * privilégiés (rôle, statut du compte, scores de confiance, KYC,
     * premium, sécurité) sont volontairement EXCLUS d'ici : ils ne doivent
     * jamais pouvoir être écrits via une requête HTTP validée de façon trop
     * large (ex. $request->validated() qui grossirait par erreur). Ces
     * champs ne sont modifiables qu'en interne via forceFill()/attribution
     * directe + save() — voir generateOtp(), TrustScoreCalculator,
     * PremiumSubscription::activate(), AdminUserController.
     */
    protected $fillable = [
        'phone_number',
        'pending_phone_number',
        'email',
        'username',
        'full_name',
        'password',
        'avatar_url',
        'cover_url',
        'bio',
        'website',
        'seller_policies',
        'city',
        'region',
        'latitude',
        'longitude',
        'is_seller',
        'is_buyer',
        'phone_verified',
        'preferences',
        'onboarding_completed',
        'device_fingerprint',
        'ranking_opt_in',
        'ranking_anonymous',
    ];

        protected $hidden = [
        'password',
        'remember_token',
        'otp_code',
        'otp_expires_at',
        'otp_attempts',
        'device_fingerprint',
    ];

    protected $appends = ['is_online'];

        public const ONLINE_THRESHOLD_MINUTES = 5;

        protected function casts(): array
        {
            return [
            'password' => 'hashed',
            'kyc_data' => 'array',
            'preferences' => 'array',
            'seller_policies' => 'array',
            'is_seller' => 'boolean',
            'is_buyer' => 'boolean',
            'phone_verified' => 'boolean',
            'onboarding_completed' => 'boolean',
            'trust_score' => 'float',
            'is_premium' => 'boolean',
            'premium_expires_at' => 'datetime',
            'ranking_opt_in' => 'boolean',
            'ranking_anonymous' => 'boolean',
            'profile_views_count' => 'integer',
            'otp_expires_at' => 'datetime',
            'last_suspicious_activity' => 'datetime',
            'latitude' => 'float',
            'longitude' => 'float',
            'last_seen_at' => 'datetime',
            'suspended_until' => 'datetime',
            'anonymized_at' => 'datetime',
            'email_verified_at' => 'datetime',
            'false_reports_count' => 'integer',
    ];
}

protected function isOnline(): \Illuminate\Database\Eloquent\Casts\Attribute
{
    return \Illuminate\Database\Eloquent\Casts\Attribute::make(
        get: function () {
            if (!$this->last_seen_at) {
                return false;
            }
            return $this->last_seen_at->diffInMinutes(now()) < self::ONLINE_THRESHOLD_MINUTES;
        },
    );
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

    public function strikes(): HasMany
    {
        return $this->hasMany(UserStrike::class);
    }

    public function premiumSubscriptions(): HasMany
    {
        return $this->hasMany(PremiumSubscription::class);
    }
    /**
     * Un utilisateur est réellement premium si le flag est actif ET que la
     * date d'expiration n'est pas dépassée. On ne se fie jamais au seul
     * booléen `is_premium` : la désactivation à l'échéance se fait via le
     * scheduler (job ExpirePremiumSubscriptions), mais entre deux
     * exécutions ce contrôle évite qu'un abonnement expiré reste actif.
     */
    public function isPremiumActive(): bool
    {
        return $this->is_premium
            && $this->premium_expires_at !== null
            && $this->premium_expires_at->isFuture();
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

    /**
     * Suspendu = statut 'suspended' ET (pas de date de fin OU date de fin future).
     * Une suspension arrivée à échéance cesse donc de bloquer immédiatement ;
     * le job LiftExpiredSuspensions remet ensuite le statut à 'active' en base.
     */
    public function isSuspended(): bool
    {
        if ($this->account_status !== 'suspended') {
            return false;
        }

        return $this->suspended_until === null || $this->suspended_until->isFuture();
    }

    // ─── Staff : rôles & permissions (config/permissions.php) ──────────
    public function roleLevel(): int
    {
        return (int) (config('permissions.levels')[$this->role] ?? 0);
    }

    /** moderator, admin ou super_admin : accès au panneau d'administration. */
    public function isStaff(): bool
    {
        return $this->roleLevel() >= 1;
    }

    public function hasPermission(string $permission): bool
    {
        $granted = config('permissions.roles')[$this->role] ?? [];

        return in_array('*', $granted, true) || in_array($permission, $granted, true);
    }

    /**
     * Hiérarchie : on ne peut agir que sur un rôle STRICTEMENT inférieur au
     * sien, jamais sur soi-même (un admin ne touche pas à un autre admin,
     * personne ne touche à un super_admin).
     */
    public function canManage(User $target): bool
    {
        return $this->id !== $target->id && $this->roleLevel() > $target->roleLevel();
    }

    public function scopeStaff($query)
    {
        return $query->whereIn('role', ['moderator', 'admin', 'super_admin']);
    }

    /**
     * L'e-mail est l'identifiant de connexion : toujours stocké en minuscules
     * (index unique exact, comparaison sans fonction SQL donc indexable).
     */
    public function setEmailAttribute($value): void
    {
        $this->attributes['email'] = $value === null ? null : strtolower(trim((string) $value));
    }

    public function isBanned(): bool
    {
        return $this->account_status === 'banned';
    }

        public function generateOtp(): string
    {
        $otp = str_pad((string) random_int(0, 999999), 6, '0', STR_PAD_LEFT);

        // forceFill : ces champs ne sont pas dans $fillable (jamais assignables
        // via une requête externe). Un nouveau code remet le compteur d'essais à 0.
        $this->forceFill([
            'otp_code' => bcrypt($otp),
            'otp_expires_at' => now()->addMinutes((int) config('quinch.otp.ttl_minutes', 10)),
            'otp_attempts' => 0,
        ])->save();

        return $otp;
    }

    public function verifyOtp(string $otp): bool
    {
        if (!$this->otp_code || !$this->otp_expires_at || $this->otp_expires_at->isPast()) {
            return false;
        }

        $max = (int) config('quinch.otp.max_attempts', 5);

        // On "réserve" un essai de façon ATOMIQUE en base avant de comparer :
        // même 50 requêtes simultanées ne peuvent pas dépasser $max essais.
        // Si le quota est déjà épuisé, aucune ligne n'est modifiée -> refus,
        // même avec le bon code (il faut en redemander un).
        $reserved = static::whereKey($this->getKey())
            ->where('otp_attempts', '<', $max)
            ->increment('otp_attempts');

        if ($reserved === 0) {
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
