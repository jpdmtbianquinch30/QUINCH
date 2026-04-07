<?php

namespace App\Models;

use App\Models\Traits\HasUuid;
use Illuminate\Database\Eloquent\Model;

class Negotiation extends Model
{
    use HasUuid;
    protected $keyType = 'string';
    public $incrementing = false;

    protected $fillable = [
        'buyer_id', 'seller_id', 'product_id', 'proposed_price',
        'counter_price', 'status', 'buyer_message', 'seller_message', 'expires_at',
    ];

    protected function casts(): array
    {
        return ['proposed_price' => 'float', 'counter_price' => 'float', 'expires_at' => 'datetime'];
    }

    public function buyer() { return $this->belongsTo(User::class, 'buyer_id'); }
    public function seller() { return $this->belongsTo(User::class, 'seller_id'); }
    public function product() { return $this->belongsTo(Product::class); }

    public function isExpired(): bool { return $this->expires_at->isPast(); }
}
