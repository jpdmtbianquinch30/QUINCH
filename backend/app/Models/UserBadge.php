<?php

namespace App\Models;

use App\Models\Traits\HasUuid;
use Illuminate\Database\Eloquent\Model;

class UserBadge extends Model
{
    use HasUuid;
    protected $keyType = 'string';
    public $incrementing = false;

    protected $fillable = ['user_id', 'badge_type', 'badge_level', 'awarded_by', 'reason', 'expires_at'];

    protected function casts(): array
    {
        return ['expires_at' => 'datetime'];
    }

    public function user() { return $this->belongsTo(User::class); }
    public function awardedBy() { return $this->belongsTo(User::class, 'awarded_by'); }

    public static function badgeDefinitions(): array
    {
        return [
            'verified' => ['name' => 'Vérifié', 'icon' => 'verified', 'color' => '#4f6ef7'],
            'top_seller' => ['name' => 'Top Vendeur', 'icon' => 'emoji_events', 'color' => '#f59e0b'],
            'fast_shipper' => ['name' => 'Livraison Express', 'icon' => 'local_shipping', 'color' => '#22c55e'],
            'loyal_customer' => ['name' => 'Client Fidèle', 'icon' => 'favorite', 'color' => '#ef4444'],
            'active_reviewer' => ['name' => 'Reviewer Actif', 'icon' => 'rate_review', 'color' => '#8b5cf6'],
            'first_sale' => ['name' => 'Première Vente', 'icon' => 'celebration', 'color' => '#ec4899'],
            'hundred_sales' => ['name' => '100 Ventes', 'icon' => 'military_tech', 'color' => '#f59e0b'],
            'premium' => ['name' => 'Premium', 'icon' => 'star', 'color' => '#f59e0b'],
            'ambassador' => ['name' => 'Ambassadeur', 'icon' => 'campaign', 'color' => '#3b82f6'],
            'one_year' => ['name' => '1 an sur QUINCH', 'icon' => 'cake', 'color' => '#ec4899'],
        ];
    }

        public static function summaryFor(string $userId): array
    {
        return static::summaryForMany([$userId])[$userId] ?? [];
    }

    public static function summaryForMany(array $userIds): array
    {
        $definitions = static::badgeDefinitions();

        return static::whereIn('user_id', $userIds)
            ->active()
            ->get()
            ->groupBy('user_id')
            ->map(fn ($badges) => $badges->map(fn ($b) => [
                'type' => $b->badge_type,
                'name' => $definitions[$b->badge_type]['name'] ?? $b->badge_type,
                'icon' => $definitions[$b->badge_type]['icon'] ?? 'stars',
                'color' => $definitions[$b->badge_type]['color'] ?? '#666',
                'description' => $definitions[$b->badge_type]['description'] ?? '',
                'awarded_at' => $b->created_at?->toISOString(),
            ])->values()->all())
            ->toArray();
    }

        /**
     * Un badge avec expires_at dans le passé ne doit plus jamais s'afficher
     * ni compter.
     */
    public function scopeActive($query)
    {
        return $query->where(function ($q) {
            $q->whereNull('expires_at')->orWhere('expires_at', '>', now());
        });
    }
}
