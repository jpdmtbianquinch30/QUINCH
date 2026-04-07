<?php

namespace App\Models;

use App\Models\Traits\HasUuid;
use Illuminate\Database\Eloquent\Model;

class Message extends Model
{
    use HasUuid;
    protected $keyType = 'string';
    public $incrementing = false;

    protected $fillable = ['conversation_id', 'sender_id', 'body', 'type', 'metadata', 'is_read', 'read_at'];

    protected function casts(): array
    {
        return ['metadata' => 'array', 'is_read' => 'boolean', 'read_at' => 'datetime'];
    }

    public function conversation() { return $this->belongsTo(Conversation::class); }
    public function sender() { return $this->belongsTo(User::class, 'sender_id'); }
}
