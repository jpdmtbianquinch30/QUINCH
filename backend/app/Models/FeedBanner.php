<?php

namespace App\Models;

use App\Models\Traits\HasUuid;
use Illuminate\Database\Eloquent\Model;

class FeedBanner extends Model
{
    use HasUuid;

    protected $keyType = 'string';
    public $incrementing = false;

    protected $appends = ['image_url'];

    protected $fillable = [
        'title', 'image_path', 'link_url', 'is_active',
        'starts_at', 'ends_at', 'city', 'sort_order', 'created_by',
    ];

    protected function casts(): array
    {
        return [
            'is_active' => 'boolean',
            'starts_at' => 'datetime',
            'ends_at' => 'datetime',
            'sort_order' => 'integer',
        ];
    }

    public function getImageUrlAttribute(): ?string
    {
        $path = $this->attributes['image_path'] ?? null;
        if (!$path) {
            return null;
        }
        return \App\Support\MediaUrl::for($path);
    }

    /** Bannières diffusables maintenant (active + dans la fenêtre de planning). */
    public function scopeLive($query)
    {
        return $query->where('is_active', true)
            ->where(fn ($q) => $q->whereNull('starts_at')->orWhere('starts_at', '<=', now()))
            ->where(fn ($q) => $q->whereNull('ends_at')->orWhere('ends_at', '>=', now()));
    }
}
