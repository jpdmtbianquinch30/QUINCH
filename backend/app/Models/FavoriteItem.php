<?php

namespace App\Models;

use App\Models\Traits\HasUuid;
use Illuminate\Database\Eloquent\Model;

class FavoriteItem extends Model
{
    use HasUuid;
    protected $keyType = 'string';
    public $incrementing = false;

    protected $fillable = ['user_id', 'product_id', 'collection_id', 'price_at_save'];

    protected function casts(): array { return ['price_at_save' => 'float']; }

    public function user() { return $this->belongsTo(User::class); }
    public function product() { return $this->belongsTo(Product::class); }
    public function collection() { return $this->belongsTo(FavoriteCollection::class, 'collection_id'); }
}
