<?php

namespace App\Models;

use App\Models\Traits\HasUuid;
use Illuminate\Database\Eloquent\Model;

class Conversation extends Model
{
    use HasUuid;
    protected $keyType = 'string';
    public $incrementing = false;

    protected $fillable = ['buyer_id', 'seller_id', 'product_id', 'status', 'last_message_at'];

    protected function casts(): array
    {
        return ['last_message_at' => 'datetime'];
    }

    public function buyer() { return $this->belongsTo(User::class, 'buyer_id'); }
    public function seller() { return $this->belongsTo(User::class, 'seller_id'); }
    public function product() { return $this->belongsTo(Product::class); }
    public function messages() { return $this->hasMany(Message::class)->orderBy('created_at'); }
    public function lastMessage() { return $this->hasOne(Message::class)->latestOfMany(); }

    public function unreadCountFor(string $userId): int
    {
        return $this->messages()->where('sender_id', '!=', $userId)->where('is_read', false)->count();
    }
}
