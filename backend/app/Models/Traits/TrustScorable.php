<?php

namespace App\Models\Traits;

trait TrustScorable
{
    public function getTrustLevelAttribute(): string
    {
        if ($this->trust_score >= 0.8) return 'excellent';
        if ($this->trust_score >= 0.6) return 'good';
        if ($this->trust_score >= 0.4) return 'average';
        if ($this->trust_score >= 0.2) return 'low';
        return 'very_low';
    }

    public function getTrustBadgeAttribute(): string
    {
        return match ($this->trust_level) {
            'excellent' => '⭐ Vendeur de confiance',
            'good' => '✅ Vérifié',
            'average' => '🔵 Standard',
            'low' => '⚠️ Nouveau',
            'very_low' => '❌ Non vérifié',
        };
    }

    public function incrementTrustScore(float $amount): void
    {
        $this->trust_score = min(1.0, $this->trust_score + $amount);
        $this->save();
    }

    public function decrementTrustScore(float $amount): void
    {
        $this->trust_score = max(0.0, $this->trust_score - $amount);
        $this->save();
    }
}
