<?php

namespace App\Models;

use App\Models\Traits\HasUuid;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Support\Facades\Cache;

/**
 * Définition d'un badge, créée et configurée dans l'admin.
 *
 * LOGIQUE DES BADGES (résumé — détail dans le README, section « Badges ») :
 *  - Une DÉFINITION décrit le badge : nom, icône, couleur, description,
 *    « comment l'obtenir », zones d'affichage, actif ou non.
 *  - Un badge est soit MANUEL (auto_rule = null : attribué à la main par l'équipe,
 *    ou par un vendeur si sellers_can_award), soit AUTOMATIQUE (auto_rule défini :
 *    le système le pose / le retire tout seul, voir App\Services\BadgeService).
 *  - Une ATTRIBUTION est une ligne de `user_badges` (user_id + badge_type = key).
 *  - Les ZONES disent où le badge s'affiche (messages, détail produit, profil vendeur…).
 */
class BadgeDefinition extends Model
{
    use HasUuid;

    public const CACHE_KEY = 'quinch.badge_definitions';

    /** Doit rester identique à BADGE_ZONES dans shared/user-badges/user-badges.component.ts. */
    public const ZONES = [
        'feed' => 'Accueil (grille)',
        'explorer' => 'Explorer',
        'video_feed' => 'Feed vidéo',
        'product_detail' => 'Détail produit',
        'seller_profile' => 'Profil vendeur',
        'messages' => 'Messages',
        'search' => 'Recherche',
        'notifications' => 'Notifications',
        'rankings' => 'Classement',
        'profile' => 'Mon profil',
    ];

    /** Règles automatiques : clé => libellé admin. */
    public const AUTO_RULES = [
        'premium' => 'Abonnement Premium actif',
        'kyc_verified' => 'Identité vérifiée (KYC)',
        'sales_completed' => 'Nombre de ventes finalisées (≥ seuil)',
        'account_age_days' => "Ancienneté du compte en jours (≥ seuil)",
        'trust_score' => 'Score de confiance en % (≥ seuil)',
    ];

    /** Règles qui exigent un seuil numérique. */
    public const RULES_WITH_THRESHOLD = ['sales_completed', 'account_age_days', 'trust_score'];

    protected $keyType = 'string';
    public $incrementing = false;

    protected $fillable = [
        'key', 'name', 'description', 'how_to_get', 'icon', 'color',
        'auto_rule', 'auto_threshold', 'zones', 'is_active', 'is_system',
        'sellers_can_award', 'sort_order', 'created_by',
    ];

    protected function casts(): array
    {
        return [
            'zones' => 'array',
            'is_active' => 'boolean',
            'is_system' => 'boolean',
            'sellers_can_award' => 'boolean',
            'auto_threshold' => 'integer',
            'sort_order' => 'integer',
        ];
    }

    protected static function booted(): void
    {
        static::saved(fn () => static::flushCache());
        static::deleted(fn () => static::flushCache());
    }

    public static function flushCache(): void
    {
        Cache::forget(self::CACHE_KEY);
    }

    /** @return array<string, array> toutes les définitions (actives ou non) indexées par clé. */
    public static function allByKey(): array
    {
        try {
            return Cache::remember(self::CACHE_KEY, 300, function () {
                return static::query()->orderBy('sort_order')->orderBy('name')->get()
                    ->mapWithKeys(fn (self $d) => [$d->key => $d->toPublicArray() + ['is_active' => $d->is_active]])
                    ->all();
            });
        } catch (\Throwable $e) {
            return [];
        }
    }

    /** Forme publique (sans données internes) d'une définition. */
    public function toPublicArray(): array
    {
        return [
            'key' => $this->key,
            'name' => $this->name,
            'description' => $this->description ?? '',
            'how_to_get' => $this->how_to_get ?? '',
            'icon' => $this->icon,
            'color' => $this->color,
            'mode' => $this->auto_rule ? 'auto' : 'manual',
            'auto_rule' => $this->auto_rule,
            'auto_threshold' => $this->auto_threshold,
            'zones' => array_values($this->zones ?? []),
            'sellers_can_award' => $this->sellers_can_award,
        ];
    }

    public function scopeActive($q)
    {
        return $q->where('is_active', true);
    }
}
