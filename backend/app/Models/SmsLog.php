<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\MassPrunable;
use Illuminate\Database\Eloquent\Model;

/**
 * Journal des tentatives d'envoi SMS (une ligne par fournisseur essayé).
 * Ne contient JAMAIS le texte du SMS ni le code OTP, et le numéro est masqué.
 * Purgé automatiquement après 90 jours (model:prune planifié).
 */
class SmsLog extends Model
{
    use MassPrunable;

    public $timestamps = false;

    protected $fillable = ['provider', 'status', 'to_masked', 'error', 'duration_ms', 'created_at'];

    protected $casts = ['created_at' => 'datetime'];

    public function prunable(): Builder
    {
        return static::where('created_at', '<', now()->subDays(90));
    }
}
