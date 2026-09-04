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
        // latestOfMany()/ofMany() ajoutent TOUJOURS une deuxième agrégation
    // interne sur la clé primaire (MAX(id)) pour garantir une seule ligne,
    // même quand on précise déjà la colonne de tri — invisible dans le code
    // appelant. Comme notre clé primaire est un UUID, cette deuxième
    // agrégation échoue sous Postgres pour la même raison que la première.
    // On contourne complètement le mécanisme "of many" avec une sous-requête
    // corrélée manuelle (ORDER BY + LIMIT, jamais de MAX() sur un UUID).
    public function lastMessage()
    {
        return $this->hasOne(Message::class)
            ->whereRaw('"messages"."id" = (select m2."id" from "messages" as m2 where m2."conversation_id" = "messages"."conversation_id" order by m2."created_at" desc limit 1)');
    }
    public function unreadCountFor(string $userId): int
    {
        return $this->messages()->where('sender_id', '!=', $userId)->where('is_read', false)->count();
    }
}
