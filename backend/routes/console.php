<?php

use Illuminate\Foundation\Inspiring;
use Illuminate\Support\Facades\Artisan;
use App\Jobs\ReleaseExpiredReservations;
use Illuminate\Support\Facades\Schedule;
use App\Jobs\ExpirePremiumSubscriptions;
use App\Jobs\CleanupAbandonedDraftListings;
use App\Jobs\RecalculateTrustScores;

Artisan::command('inspire', function () {
    $this->comment(Inspiring::quote());
})->purpose('Display an inspiring quote');

// withoutOverlapping + onOneServer : une seule exécution même avec plusieurs
// conteneurs "scheduler". Nécessite un cache à verrous atomiques (Redis en prod).
Schedule::job(new ReleaseExpiredReservations)->everyMinute()->withoutOverlapping(10)->onOneServer();
Schedule::job(new ExpirePremiumSubscriptions)->daily()->withoutOverlapping()->onOneServer();
Schedule::job(new CleanupAbandonedDraftListings)->hourly()->withoutOverlapping()->onOneServer();
Schedule::job(new RecalculateTrustScores)->daily()->withoutOverlapping()->onOneServer();
