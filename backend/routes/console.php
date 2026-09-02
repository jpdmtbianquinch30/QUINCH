<?php

use Illuminate\Foundation\Inspiring;
use Illuminate\Support\Facades\Artisan;
use App\Jobs\ReleaseExpiredReservations;
use Illuminate\Support\Facades\Schedule;
use App\Jobs\ExpirePremiumSubscriptions;
use App\Jobs\CleanupAbandonedDraftListings;

Artisan::command('inspire', function () {
    $this->comment(Inspiring::quote());
})->purpose('Display an inspiring quote');
Schedule::job(new ReleaseExpiredReservations)->everyMinute();
Schedule::job(new ExpirePremiumSubscriptions)->daily();
Schedule::job(new CleanupAbandonedDraftListings)->hourly();