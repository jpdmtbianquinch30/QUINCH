<?php

namespace App\Models;

use App\Models\Traits\HasUuid;
use Illuminate\Database\Eloquent\Model;

class UserBadge extends Model
{
    use HasUuid;
    protected $keyType = 'string';
    public $incrementing = false;

    protected $fillable = ['user_id', 'badge_type', 'badge_level', 'awarded_by', 'reason', 'expires_at', 'source'];

    protected function casts(): array
    {
        return ['expires_at' => 'datetime'];
    }

    public function user() { return $this->belongsTo(User::class); }
    public function awardedBy() { return $this->belongsTo(User::class, 'awarded_by'); }

    /**
     * Définitions des badges ACTIFS (créés dans l'admin), indexées par clé.
     * Source de vérité unique : table badge_definitions (voir BadgeDefinition).
     * Un badge sans définition active n'est jamais affiché.
     */
    public static function badgeDefinitions(): array
    {
        return collect(BadgeDefinition::allByKey())
            ->filter(fn ($d) => $d['is_active'] ?? false)
            ->all();
    }

    /** Forme d'un badge telle que renvoyée aux fronts (nom, icône, couleur, zones…). */
    public static function present(string $type, array $def, ?string $awardedAt = null): array
    {
        return [
            'type' => $type,
            'name' => $def['name'],
            'icon' => $def['icon'],
            'color' => $def['color'],
            'description' => $def['description'] ?? '',
            'zones' => $def['zones'] ?? [],
            'awarded_at' => $awardedAt,
        ];
    }

        public static function summaryFor(string $userId): array
    {
        return static::summaryForMany([$userId])[$userId] ?? [];
    }

    public static function summaryForMany(array $userIds): array
    {
        $definitions = static::badgeDefinitions();
        if (!$definitions || !$userIds) {
            return [];
        }

        return static::whereIn('user_id', $userIds)
            ->whereIn('badge_type', array_keys($definitions))
            ->active()
            ->get()
            ->groupBy('user_id')
            ->map(fn ($badges) => $badges
                // Ordre d'affichage = ordre défini dans l'admin.
                ->sortBy(fn ($b) => array_search($b->badge_type, array_keys($definitions), true))
                ->map(fn ($b) => static::present($b->badge_type, $definitions[$b->badge_type], $b->created_at?->toISOString()))
                ->values()->all())
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
