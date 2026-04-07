<?php

namespace App\Models;

use App\Models\Traits\HasUuid;
use Illuminate\Database\Eloquent\Model;

class CartItem extends Model
{
    use HasUuid;
    protected $keyType = 'string';
    public $incrementing = false;

    protected $fillable = ['user_id', 'product_id', 'quantity', 'price_at_add', 'reserved_until'];

    protected function casts(): array
    {
        return ['price_at_add' => 'float', 'reserved_until' => 'datetime'];
    }

    public function user() { return $this->belongsTo(User::class); }
    public function product() { return $this->belongsTo(Product::class); }
}
