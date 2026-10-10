<?php

namespace App\Models;

use App\Models\Traits\HasUuid;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

/** Candidature à l'offre « Premium offert aux N premiers utilisateurs » (bêta). */
class PremiumApplication extends Model
{
    use HasUuid;

    protected $fillable = ['user_id'];

    protected function casts(): array
    {
        return ['decided_at' => 'datetime'];
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    /** Places déjà attribuées sur l'offre. */
    public static function grantedCount(): int
    {
        return static::where('status', 'granted')->count();
    }

    public static function slotsLeft(): int
    {
        return max(0, (int) config('quinch.premium.offer.slots', 100) - static::grantedCount());
    }
}
