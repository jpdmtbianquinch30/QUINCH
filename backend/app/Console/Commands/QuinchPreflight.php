<?php

namespace App\Console\Commands;

use App\Support\ProductionPreflight;
use Illuminate\Console\Command;

/**
 * Vérifie la configuration avant démarrage en production.
 * Code de sortie 1 si un problème est détecté (utilisé par l'entrypoint Docker
 * et par la CI).
 */
class QuinchPreflight extends Command
{
    protected $signature = 'quinch:preflight {--as= : Forcer l\'environnement évalué (ex. production)}';

    protected $description = 'Contrôle la configuration de production (SMS, paiements, CORS, Redis...)';

    public function handle(ProductionPreflight $preflight): int
    {
        $env = $this->option('as') ?: (string) app()->environment();
        $errors = $preflight->errors($env);

        if ($errors === []) {
            $this->info($env === 'production'
                ? 'Preflight OK : configuration de production valide.'
                : "Preflight ignoré (environnement « {$env} », contrôle réservé à la production).");

            return self::SUCCESS;
        }

        $this->error('Preflight ÉCHEC — le démarrage est refusé :');
        foreach ($errors as $error) {
            $this->line('  ✗ ' . $error);
        }

        return self::FAILURE;
    }
}
