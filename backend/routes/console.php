<?php

use Illuminate\Foundation\Inspiring;
use Illuminate\Support\Facades\Artisan;
use App\Jobs\ReconcileWavePayments;
use App\Jobs\ReleaseExpiredReservations;
use Illuminate\Support\Facades\Schedule;
use App\Jobs\ExpirePremiumSubscriptions;
use App\Jobs\CleanupAbandonedDraftListings;
use App\Jobs\RecalculateTrustScores;
use App\Jobs\LiftExpiredSuspensions;
use App\Jobs\RunFraudScan;
use App\Jobs\PurgeExpiredAdminData;
use App\Jobs\PurgeAnonymizedAccountData;
use App\Support\HealthChecker;
use Illuminate\Support\Facades\Cache;

Artisan::command('inspire', function () {
    $this->comment(Inspiring::quote());
})->purpose('Display an inspiring quote');

// withoutOverlapping + onOneServer : une seule exécution même avec plusieurs
// conteneurs "scheduler". Nécessite un cache à verrous atomiques (Redis en prod).
Schedule::job(new ReleaseExpiredReservations)->everyMinute()->withoutOverlapping(10)->onOneServer();
// Rattrapage des paiements Wave dont le webhook s'est perdu (voir ReconcileWavePayments).
Schedule::job(new ReconcileWavePayments)->everyFiveMinutes()->withoutOverlapping(10)->onOneServer();
Schedule::job(new ExpirePremiumSubscriptions)->daily()->withoutOverlapping()->onOneServer();
Schedule::job(new CleanupAbandonedDraftListings)->hourly()->withoutOverlapping()->onOneServer();
Schedule::job(new RecalculateTrustScores)->daily()->withoutOverlapping()->onOneServer();

// ─── Admin / modération ───────────────────────────────────────────────────
// Levée automatique des suspensions arrivées à échéance.
Schedule::job(new LiftExpiredSuspensions)->everyFiveMinutes()->withoutOverlapping()->onOneServer();
// Détection de fraude (paiements échoués, multi-comptes, vendeurs signalés).
Schedule::job(new RunFraudScan)->hourly()->withoutOverlapping()->onOneServer();
// Ménage : bans d'IP expirés, vieux journaux techniques.
Schedule::job(new PurgeExpiredAdminData)->daily()->withoutOverlapping()->onOneServer();
// Comptes supprimés : effacement définitif des contenus après le délai légal (30 jours par défaut).
Schedule::job(new PurgeAnonymizedAccountData)->daily()->withoutOverlapping()->onOneServer();

// Badges automatiques (Premium, KYC, ventes, ancienneté, score de confiance).
Schedule::command('quinch:sync-badges')->hourly()->withoutOverlapping()->onOneServer();

// Journal des envois SMS : purge au-delà de 90 jours (voir SmsLog::prunable).
Schedule::command('model:prune', ['--model' => [\App\Models\SmsLog::class]])->daily()->onOneServer();

// Battement du planificateur : GET /api/v1/ops/health signale « degraded » s'il s'arrête
// (scheduler arrêté = paiements non rattrapés, comptes supprimés non effacés...).
Schedule::call(fn () => Cache::put(HealthChecker::SCHEDULER_KEY, now()->timestamp, 900))
    ->everyMinute()
    ->name('health-heartbeat');
