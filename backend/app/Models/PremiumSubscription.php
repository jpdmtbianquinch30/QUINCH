<?php

namespace App\Models;

use App\Models\Traits\HasUuid;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class PremiumSubscription extends Model
{
    use HasFactory, HasUuid;

    protected $fillable = [
        'user_id',
        'plan',
        'amount',
        'currency',
        'status',
        'payment_method',
        'payment_gateway_id',
        'starts_at',
        'expires_at',
    ];

    protected function casts(): array
    {
        return [
            'amount' => 'float',
            'starts_at' => 'datetime',
            'expires_at' => 'datetime',
        ];
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    public function scopePending($query)
    {
        return $query->where('status', 'pending');
    }

    public function scopeActive($query)
    {
        return $query->where('status', 'active');
    }

    /**
     * Active l'abonnement après confirmation du paiement (webhook) : calcule
     * la date d'expiration selon le plan et met à jour l'utilisateur.
     */
    public function activate(): void
    {
        $startsAt = now();
        $expiresAt = $this->plan === 'annual'
            ? $startsAt->copy()->addYear()
            : $startsAt->copy()->addMonth();

        $this->update([
            'status' => 'active',
            'starts_at' => $startsAt,
            'expires_at' => $expiresAt,
        ]);

        // Champs sensibles, non mass-assignables : forceFill nécessaire.
        $this->user->forceFill([
            'is_premium' => true,
            'premium_plan' => $this->plan,
            'premium_expires_at' => $expiresAt,
        ])->save();
    }
}
