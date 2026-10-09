<?php

namespace App\Console\Commands;

use App\Support\HealthChecker;
use Illuminate\Console\Command;

/**
 * Affiche l'état de santé depuis le serveur (même contrôles que GET /api/v1/ops/health).
 *   php artisan quinch:health          rapide
 *   php artisan quinch:health --deep   teste aussi l'écriture sur le stockage des médias
 * Code de sortie 1 si la base de données est en panne (utilisable dans un script ou un cron).
 */
class QuinchHealth extends Command
{
    protected $signature = 'quinch:health {--deep : Teste aussi le stockage des médias}';

    protected $description = 'Affiche l\'état de santé de l\'application';

    public function handle(HealthChecker $checker): int
    {
        $report = $checker->run((bool) $this->option('deep'));

        foreach ($report['checks'] as $name => $check) {
            $details = collect($check)->except('status')->map(fn ($v, $k) => $k . '=' . (is_array($v) ? json_encode($v) : $v))->implode(' ');
            $line = sprintf('%-10s %-9s %s', $name, $check['status'], $details);

            match ($check['status']) {
                'ok'    => $this->info($line),
                'down'  => $this->error($line),
                default => $this->warn($line),
            };
        }

        $this->line('Statut global : ' . $report['status']);

        return $report['critical'] ? self::FAILURE : self::SUCCESS;
    }
}
