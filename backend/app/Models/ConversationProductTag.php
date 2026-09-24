<?php

namespace App\Models;

use App\Models\Traits\HasUuid;
use Illuminate\Database\Eloquent\Model;

class ConversationProductTag extends Model
{
    use HasUuid;
    protected $keyType = 'string';
    public $incrementing = false;

        protected $fillable = ['conversation_id', 'product_id', 'tagged_by', 'transaction_id', 'is_blurred', 'published_to_directory'];

    protected function casts(): array
    {
        return [
            'is_blurred' => 'boolean',
            'published_to_directory' => 'boolean',
        ];
    }

    public function conversation() { return $this->belongsTo(Conversation::class); }
    public function product() { return $this->belongsTo(Product::class); }
    public function taggedBy() { return $this->belongsTo(User::class, 'tagged_by'); }
    public function transaction() { return $this->belongsTo(Transaction::class); }
}
