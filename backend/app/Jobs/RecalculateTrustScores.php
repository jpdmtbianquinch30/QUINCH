<?php

namespace App\Jobs;

use App\Services\TrustScoring\TrustScoreCalculator;
use Illuminate\Bus\Queueable;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Foundation\Bus\Dispatchable;

/**
 * Filet de sécurité quotidien : le recalcul "temps réel" se fait déjà à la
 * sauvegarde du profil/des politiques, mais certains facteurs évoluent sans
 * action explicite (ancienneté du compte, nouvelles transactions).
 */
class RecalculateTrustScores implements ShouldQueue
{
    use Dispatchable, Queueable;

    public function handle(): void
    {
        (new TrustScoreCalculator())->recalculateAll();
    }
}
