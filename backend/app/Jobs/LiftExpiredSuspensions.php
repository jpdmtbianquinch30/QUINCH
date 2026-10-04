<?php

namespace App\Jobs;

use App\Models\User;
use App\Services\Admin\SanctionService;
use Illuminate\Bus\Queueable;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Foundation\Bus\Dispatchable;

/** Lève automatiquement les suspensions arrivées à échéance (suspended_until dépassé). */
class LiftExpiredSuspensions implements ShouldQueue
{
    use Dispatchable, Queueable;

    public function handle(SanctionService $sanctions): void
    {
        User::query()
            ->where('account_status', 'suspended')
            ->whereNotNull('suspended_until')
            ->where('suspended_until', '<=', now())
            ->chunkById(100, function ($users) use ($sanctions) {
                foreach ($users as $user) {
                    $sanctions->lift($user, 'Suspension arrivée à échéance');
                }
            });
    }
}
