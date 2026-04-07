<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class FraudDetection extends Model
{
    protected $table = 'fraud_detections';

    protected $fillable = [
        'user_id',
        'detection_type',
        'confidence_score',
        'evidence',
        'status',
        'action_taken',
        'reviewed_by',
        'reviewed_at',
    ];

    protected function casts(): array
    {
        return [
            'confidence_score' => 'float',
            'evidence' => 'array',
            'reviewed_at' => 'datetime',
        ];
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    public function reviewer(): BelongsTo
    {
        return $this->belongsTo(User::class, 'reviewed_by');
    }

    public function scopePendingReview($query)
    {
        return $query->where('status', 'pending_review');
    }

    public function scopeHighConfidence($query)
    {
        return $query->where('confidence_score', '>=', 0.8);
    }
}
