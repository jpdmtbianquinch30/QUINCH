<?php

namespace App\Models;

use App\Models\Traits\HasUuid;
use Illuminate\Database\Eloquent\Model;

class FavoriteCollection extends Model
{
    use HasUuid;
    protected $keyType = 'string';
    public $incrementing = false;

    protected $fillable = ['user_id', 'name', 'is_public'];

    protected function casts(): array { return ['is_public' => 'boolean']; }

    public function user() { return $this->belongsTo(User::class); }
    public function items() { return $this->hasMany(FavoriteItem::class, 'collection_id'); }
}
