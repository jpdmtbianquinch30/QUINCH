<?php

namespace App\Console\Commands;

use App\Models\SmsLog;
use Illuminate\Console\Command;

/**
 * Santé des envois SMS : succès / échecs par fournisseur sur une période.
 *   php artisan quinch:sms-stats --hours=24
 */
class QuinchSmsStats extends Command
{
    protected $signature = 'quinch:sms-stats {--hours=24 : Période analysée, en heures}';

    protected $description = 'Statistiques des envois SMS par fournisseur (succès, échecs, durée moyenne)';

    public function handle(): int
    {
        $hours = max(1, (int) $this->option('hours'));

        $rows = SmsLog::query()
            ->where('created_at', '>=', now()->subHours($hours))
            ->selectRaw('provider, status, count(*) as total, round(avg(duration_ms)) as avg_ms')
            ->groupBy('provider', 'status')
            ->orderBy('provider')
            ->orderBy('status')
            ->get();

        if ($rows->isEmpty()) {
            $this->info("Aucun envoi SMS enregistré sur les {$hours} dernière(s) heure(s).");

            return self::SUCCESS;
        }

        $this->table(
            ['Fournisseur', 'Statut', 'Envois', 'Durée moy. (ms)'],
            $rows->map(fn ($r) => [$r->provider, $r->status, $r->total, $r->avg_ms])->all()
        );

        $total = (int) $rows->sum('total');
        $failed = (int) $rows->where('status', 'failed')->sum('total');
        $rate = $total > 0 ? round(100 * ($total - $failed) / $total, 1) : 100;
        $this->line("Tentatives : {$total} — échecs : {$failed} — réussite : {$rate} % (sur {$hours} h)");

        return self::SUCCESS;
    }
}
