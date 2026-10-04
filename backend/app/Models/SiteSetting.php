<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Support\Facades\Cache;

/**
 * Réglages modifiables depuis l'admin (clé / valeur JSON), mis en cache.
 * Les clés sont de la forme "moderation.strike_threshold", "feed.ticker_text"...
 */
class SiteSetting extends Model
{
    public const CACHE_KEY = 'quinch.site_settings';

    protected $primaryKey = 'key';
    public $incrementing = false;
    protected $keyType = 'string';

    protected $fillable = ['key', 'value', 'updated_by'];

    protected function casts(): array
    {
        return ['value' => 'array'];
    }

    /** @return array<string, mixed> */
    public static function allCached(): array
    {
        try {
            return Cache::remember(self::CACHE_KEY, 300, function () {
                $out = [];
                foreach (static::query()->get() as $row) {
                    $out[$row->key] = $row->value;
                }
                return $out;
            });
        } catch (\Throwable $e) {
            // Table absente (avant migration) ou cache indisponible : valeurs par défaut.
            return [];
        }
    }

    public static function get(string $key, mixed $default = null): mixed
    {
        $all = static::allCached();

        // array_key_exists : les clés contiennent des points, pas de Arr::get().
        return array_key_exists($key, $all) && $all[$key] !== null ? $all[$key] : $default;
    }

    public static function put(string $key, mixed $value, ?string $userId = null): void
    {
        static::updateOrCreate(['key' => $key], ['value' => $value, 'updated_by' => $userId]);
        Cache::forget(self::CACHE_KEY);
    }
}
