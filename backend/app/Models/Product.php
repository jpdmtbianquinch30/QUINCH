<?php

namespace App\Models;

use App\Models\Traits\HasUuid;
use App\Models\Traits\Auditable;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Support\Str;

class Product extends Model
{
    use HasUuid, Auditable;

    protected $keyType = 'string';
    public $incrementing = false;

    protected $appends = ['poster_full_url'];

    protected $fillable = [
        'user_id',
        'type',
        'title',
        'slug',
        'description',
        'category_id',
        'price',
        'currency',
        'stock_quantity',
        'condition',
        'is_negotiable',
        'status',
        'video_id',
        'metadata',
        'images',
        'poster_url',
        'payment_methods',
        'delivery_option',
        'delivery_fee',
        'view_count',
        'like_count',
        'share_count',
        'expires_at',
    ];

    protected function casts(): array
    {
        return [
            'price' => 'float',
            'is_negotiable' => 'boolean',
            'metadata' => 'array',
            'payment_methods' => 'array',
            'delivery_fee' => 'integer',
            'view_count' => 'integer',
            'like_count' => 'integer',
            'share_count' => 'integer',
            'stock_quantity' => 'integer',
            'expires_at' => 'datetime',
        ];
    }

    protected static function booted(): void
    {
        static::creating(function (Product $product) {
            if (empty($product->slug)) {
                $product->slug = Str::slug($product->title) . '-' . Str::random(6);
            }
        });
    }

    // ─── Relationships ──────────────────────────────────────────────────
    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    public function category(): BelongsTo
    {
        return $this->belongsTo(Category::class);
    }

    public function video(): BelongsTo
    {
        return $this->belongsTo(ProductVideo::class, 'video_id');
    }

    public function transactions(): HasMany
    {
        return $this->hasMany(Transaction::class);
    }

    public function likedByUsers()
    {
        return $this->belongsToMany(User::class, 'product_likes')->withTimestamps();
    }

    public function savedByUsers()
    {
        return $this->belongsToMany(User::class, 'product_saves')->withTimestamps();
    }

    // ─── Scopes ─────────────────────────────────────────────────────────
    public function scopeActive($query)
    {
        return $query->where('status', 'active');
    }

    public function scopeAvailable($query)
    {
        return $query->whereIn('status', ['active', 'reserved']);
    }

    public function scopeVisible($query)
    {
        return $query->whereNotIn('status', ['paused', 'disabled']);
    }

    public function scopeByCategory($query, string $categoryId)
    {
        return $query->where('category_id', $categoryId);
    }

    public function scopeSearch($query, string $term)
    {
        return $query->whereFullText(['title', 'description'], $term);
    }

    public function scopePriceRange($query, ?float $min, ?float $max)
    {
        if ($min !== null) $query->where('price', '>=', $min);
        if ($max !== null) $query->where('price', '<=', $max);
        return $query;
    }

    // ─── Helpers ────────────────────────────────────────────────────────
    public function getFormattedPriceAttribute(): string
    {
        return number_format($this->price, 0, ',', '.') . ' ' . $this->currency;
    }

    public function isOwnedBy(User $user): bool
    {
        return $this->user_id === $user->id;
    }

    // ─── Poster URL Accessor (return full absolute URL) ─────────
    public function getPosterFullUrlAttribute(): ?string
    {
        $poster = $this->attributes['poster_url'] ?? null;
        if (!$poster) return null;
        if (str_starts_with($poster, 'http')) return $poster;
        if (str_starts_with($poster, '/storage/')) return url($poster);
        return url('/storage/' . $poster);
    }

    // ─── URL Accessor for images (return full absolute URLs) ─────────
    public function getImagesAttribute($value): array
    {
        if (!$value) return [];
        $images = is_string($value) ? json_decode($value, true) : $value;
        if (!$images || !is_array($images)) return [];

        return array_values(array_filter(array_map(function ($img) {
            if (!$img) return null;
            if (str_starts_with($img, 'http')) return $img;
            if (str_starts_with($img, '/storage/')) return url($img);
            return url('/storage/' . $img);
        }, $images)));
    }

    // ─── Mutator: ensure images are stored as JSON ─────────
    public function setImagesAttribute($value): void
    {
        if (is_array($value)) {
            $this->attributes['images'] = json_encode(array_values($value));
        } elseif (is_string($value)) {
            $this->attributes['images'] = $value;
        } else {
            $this->attributes['images'] = json_encode([]);
        }
    }
}
