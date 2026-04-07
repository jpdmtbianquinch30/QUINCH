<?php

namespace App\Models;

use App\Models\Traits\HasUuid;
use Illuminate\Database\Eloquent\Model;

class UserReview extends Model
{
    use HasUuid;
    protected $keyType = 'string';
    public $incrementing = false;

    protected $fillable = [
        'reviewer_id', 'seller_id', 'transaction_id', 'rating', 'comment',
        'delivery_rating', 'communication_rating', 'accuracy_rating',
        'seller_response', 'seller_responded_at',
    ];

    protected function casts(): array
    {
        return [
            'rating' => 'integer',
            'delivery_rating' => 'float',
            'communication_rating' => 'float',
            'accuracy_rating' => 'float',
            'seller_responded_at' => 'datetime',
        ];
    }

    public function reviewer() { return $this->belongsTo(User::class, 'reviewer_id'); }
    public function seller() { return $this->belongsTo(User::class, 'seller_id'); }
    public function transaction() { return $this->belongsTo(Transaction::class); }
}
