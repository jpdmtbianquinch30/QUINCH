<?php

namespace App\Models;

use App\Models\Traits\HasUuid;
use Illuminate\Database\Eloquent\Model;

class UserNotification extends Model
{
    use HasUuid;

    protected $keyType = 'string';
    public $incrementing = false;

    protected $fillable = [
        'user_id', 'type', 'title', 'body', 'icon', 'action_url',
        'data', 'is_read', 'read_at',
        'group_key', 'group_count', 'priority', 'image_url', 'sender_id',
    ];

    protected function casts(): array
    {
        return [
            'data' => 'array',
            'is_read' => 'boolean',
            'read_at' => 'datetime',
            'group_count' => 'integer',
        ];
    }

    public function user()
    {
        return $this->belongsTo(User::class);
    }

    public function sender()
    {
        return $this->belongsTo(User::class, 'sender_id');
    }

    // ─── Scopes ──────────────────────────────────────────
    public function scopeUnread($q)
    {
        return $q->where('is_read', false);
    }

    public function scopeOfType($q, string $type)
    {
        return $q->where('type', $type);
    }

    public function scopeCritical($q)
    {
        return $q->where('priority', 'critical');
    }

    /**
     * Filter by category tab (TikTok-style).
     * all = everything
     * interactions = like, follow, comment, review
     * messages = message
     * system = system, admin, transaction
     */
    public function scopeForTab($q, string $tab)
    {
        return match ($tab) {
            'interactions' => $q->whereIn('type', ['like', 'follow', 'comment', 'review']),
            'messages'     => $q->where('type', 'message'),
            'system'       => $q->whereIn('type', ['system', 'admin', 'transaction', 'welcome']),
            default        => $q, // 'all'
        };
    }
}
