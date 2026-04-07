<?php

namespace App\Models;

use App\Models\Traits\HasUuid;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasOne;

class ProductVideo extends Model
{
    use HasUuid;

    protected $keyType = 'string';
    public $incrementing = false;

    protected $appends = ['video_url', 'thumbnail_url'];

    protected $fillable = [
        'user_id',
        'video_path',
        'thumbnail_path',
        'duration_seconds',
        'format',
        'resolution',
        'width',
        'height',
        'quality_label',
        'source',
        'size_bytes',
        'hash_sha256',
        'processing_status',
        'moderation_status',
        'view_count',
        'engagement_score',
    ];

    protected function casts(): array
    {
        return [
            'duration_seconds' => 'integer',
            'size_bytes' => 'integer',
            'view_count' => 'integer',
            'engagement_score' => 'float',
        ];
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    public function product(): HasOne
    {
        return $this->hasOne(Product::class, 'video_id');
    }

    public function scopePending($query)
    {
        return $query->where('moderation_status', 'pending');
    }

    public function scopeApproved($query)
    {
        return $query->where('moderation_status', 'approved');
    }

    /**
     * Return the video URL via the streaming API endpoint.
     * Uses relative URL so the Angular dev proxy can forward it.
     */
    public function getVideoUrlAttribute(): ?string
    {
        if (!$this->video_path) return null;
        return '/api/v1/videos/' . $this->id . '/stream';
    }

    /**
     * Return the absolute video URL (for external sharing etc.).
     */
    public function getVideoAbsoluteUrlAttribute(): ?string
    {
        if (!$this->video_path) return null;
        return url('/api/v1/videos/' . $this->id . '/stream');
    }

    /**
     * Return the direct storage URL (works when symlink exists).
     */
    public function getVideoStorageUrlAttribute(): ?string
    {
        if (!$this->video_path) return null;
        return url('/storage/' . $this->video_path);
    }

    public function getThumbnailUrlAttribute(): ?string
    {
        if (!$this->thumbnail_path) return null;
        return '/api/v1/videos/' . $this->id . '/thumbnail';
    }
}
